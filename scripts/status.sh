#!/usr/bin/env bash
# etude — status audit.
#
# Read-only diagnostic. Compares intended state (registry + sidecar) against
# actual state (ollama list, ollama show, config on disk) and reports drift.
#
# Checks:
#   1  sidecar      — does the sidecar exist and parse?
#   2  models       — does every sidecar model exist in `ollama list`?
#   3  variants     — does every variant's num_ctx match the registry?
#   4  config       — does the opencode config file exist and look right?
#   5  registry     — is the sidecar's TSV date current with the repo?
#
# Flags:
#   --check-updates   also resolve every base tag against the ollama registry
#                     (requires network; slow)
#   --json            machine-readable output
#   --verbose / -v    show raw values behind each check
#
# Exit codes:
#   0  no issues found
#   1  at least one issue found (drift, missing model, etc.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/tiers.sh
source "$SCRIPT_DIR/lib/tiers.sh"

SIDECAR="${ETUDE_SIDECAR:-$HOME/.config/etude/install.sh}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"

VERBOSE=0
CHECK_UPDATES=0
JSON_MODE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --verbose|-v)      VERBOSE=1 ;;
    --check-updates)   CHECK_UPDATES=1 ;;
    --json)            JSON_MODE=1 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *) echo "etude status: unknown flag '$1'" >&2; exit 2 ;;
  esac
  shift
done

# ----------------------------------------------------------------------------
# Output helpers
# ----------------------------------------------------------------------------

ISSUES=0

ok()    { printf '  \033[32mok\033[0m    %s\n'   "$1"; }
warn()  { printf '  \033[33mwarn\033[0m  %s\n'   "$1"; ISSUES=$((ISSUES + 1)); }
err()   { printf '  \033[31merr\033[0m   %s\n'   "$1"; ISSUES=$((ISSUES + 1)); }
info()  { printf '        %s\n' "$1"; }
vinfo() { [ "$VERBOSE" = "1" ] && printf '        %s\n' "$1"; return 0; }

# JSON accumulator — each finding is appended as a JSON object.
JSON_FINDINGS=()

json_add() {
  local section="$1" severity="$2" message="$3" detail="${4:-}"
  JSON_FINDINGS+=("$(printf '{"section":"%s","severity":"%s","message":"%s","detail":"%s"}' \
    "$section" "$severity" "$message" "$detail")")
}

json_emit() {
  printf '{"issues":%d,"findings":[' "$ISSUES"
  local first=1
  for f in "${JSON_FINDINGS[@]}"; do
    [ "$first" = "0" ] && printf ','
    printf '%s' "$f"
    first=0
  done
  printf ']}\n'
}

# ----------------------------------------------------------------------------
# Sidecar loading
# ----------------------------------------------------------------------------

ETUDE_TIER=""
ETUDE_MODELS=()
ETUDE_MODE=""
ETUDE_OPENCODE_CONFIG_PATH=""
ETUDE_TSV_LAST_REVIEWED=""
ETUDE_INSTALLED_AT=""

load_sidecar() {
  if [ ! -f "$SIDECAR" ]; then
    return 1
  fi
  # shellcheck source=/dev/null
  source "$SIDECAR"
  return 0
}

# Extract tag and role from an ETUDE_MODELS entry ("tag:role").
# The tag itself may contain a colon (e.g. "qwen3:8b-32k"), so strip only
# the trailing :role.
model_tag()  { echo "$1" | sed 's/:[^:]*$//'; }
model_role() { echo "$1" | awk -F: '{print $NF}'; }

# ----------------------------------------------------------------------------
# Section 1: Sidecar
# ----------------------------------------------------------------------------

check_sidecar() {
  echo "Sidecar"

  if ! load_sidecar; then
    err "sidecar not found at $SIDECAR"
    info "run ./install.sh to create it"
    [ "$JSON_MODE" = "1" ] && json_add "sidecar" "error" "sidecar not found" "$SIDECAR"
    return 1
  fi

  ok "sidecar: $SIDECAR"
  vinfo "tier=$ETUDE_TIER  mode=$ETUDE_MODE  installed=$ETUDE_INSTALLED_AT"

  if [ -z "$ETUDE_TIER" ]; then
    err "sidecar missing ETUDE_TIER"
    [ "$JSON_MODE" = "1" ] && json_add "sidecar" "error" "missing ETUDE_TIER" ""
    return 1
  fi

  if ! tiers_has "$ETUDE_TIER"; then
    err "sidecar tier '$ETUDE_TIER' not in registry"
    [ "$JSON_MODE" = "1" ] && json_add "sidecar" "error" "tier not in registry" "$ETUDE_TIER"
    return 1
  fi

  ok "tier: $ETUDE_TIER (in registry)"

  if [ "${#ETUDE_MODELS[@]}" -eq 0 ]; then
    warn "sidecar has no models recorded"
    [ "$JSON_MODE" = "1" ] && json_add "sidecar" "warn" "no models in sidecar" ""
  else
    ok "${#ETUDE_MODELS[@]} model(s) in sidecar"
  fi

  [ "$JSON_MODE" = "1" ] && json_add "sidecar" "ok" "sidecar loaded" "tier=$ETUDE_TIER"
  return 0
}

# ----------------------------------------------------------------------------
# Section 2: Models — does every sidecar model exist in `ollama list`?
# ----------------------------------------------------------------------------

check_models() {
  echo "Models"

  if [ "${#ETUDE_MODELS[@]}" -eq 0 ]; then
    info "(no models to check)"
    return 0
  fi

  local installed
  installed=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}') || {
    err "ollama list failed — is the daemon running?"
    [ "$JSON_MODE" = "1" ] && json_add "models" "error" "ollama list failed" ""
    return 1
  }

  local tag role
  for entry in "${ETUDE_MODELS[@]}"; do
    tag=$(model_tag "$entry")
    role=$(model_role "$entry")
    if echo "$installed" | grep -qxF -- "$tag"; then
      ok "$tag ($role) — present"
      [ "$JSON_MODE" = "1" ] && json_add "models" "ok" "present" "$tag"
    else
      err "$tag ($role) — missing from ollama list"
      info "fix: ollama pull <base-tag>, then ollama create $tag"
      [ "$JSON_MODE" = "1" ] && json_add "models" "error" "missing" "$tag"
    fi
  done
}

# ----------------------------------------------------------------------------
# Section 3: Variants — does each variant's num_ctx match the registry?
# ----------------------------------------------------------------------------

check_variants() {
  echo "Variants"

  if [ "${#ETUDE_MODELS[@]}" -eq 0 ]; then
    info "(no models to check)"
    return 0
  fi

  local tag role
  for entry in "${ETUDE_MODELS[@]}"; do
    tag=$(model_tag "$entry")
    role=$(model_role "$entry")

    # Skip non-variant tags (cloud models, base tags without the -Nk suffix).
    if ! echo "$tag" | grep -qE -- '-[0-9]+k$'; then
      vinfo "$tag — not a variant tag, skipping num_ctx check"
      continue
    fi

    # Derive what the registry says the context should be.
    # We need the base tag to look up the registry row. The variant convention
    # is "<base>-<ctx/1024>k", so strip the trailing "-<N>k" to get the base.
    local base ctx_expected variant_expected
    base=$(echo "$tag" | sed 's/-[0-9]*k$//')
    ctx_expected=$(tiers_context_for "$ETUDE_TIER" "$base")

    if [ -z "$ctx_expected" ]; then
      warn "$tag — base '$base' not in registry for tier '$ETUDE_TIER'"
      info "the sidecar references a model the registry doesn't know about"
      [ "$JSON_MODE" = "1" ] && json_add "variants" "warn" "base not in registry" "$tag (base=$base)"
      continue
    fi

    # Check that the variant tag name matches what the registry would generate.
    variant_expected=$(variant_tag_for "$base" "$ctx_expected")
    if [ "$tag" != "$variant_expected" ]; then
      warn "$tag — registry expects variant '$variant_expected' (context=$ctx_expected)"
      info "the sidecar's variant name doesn't match the current registry context"
      info "fix: re-run ./install.sh or ./install.sh --refresh to rebuild variants"
      [ "$JSON_MODE" = "1" ] && json_add "variants" "warn" "variant name mismatch" "have=$tag want=$variant_expected"
      continue
    fi

    # Check actual num_ctx via `ollama show`.
    local show_out actual_ctx
    show_out=$(ollama show "$tag" 2>&1) || {
      err "$tag — ollama show failed (variant deleted?)"
      info "fix: re-run ./install.sh to recreate the variant"
      [ "$JSON_MODE" = "1" ] && json_add "variants" "error" "ollama show failed" "$tag"
      continue
    }

    actual_ctx=$(echo "$show_out" | awk '/num_ctx/ {print $2; exit}')
    if [ -z "$actual_ctx" ]; then
      warn "$tag — num_ctx not found in ollama show output"
      vinfo "ollama show output (first 10 lines):"
      [ "$VERBOSE" = "1" ] && echo "$show_out" | head -10 | while read -r line; do vinfo "  $line"; done
      [ "$JSON_MODE" = "1" ] && json_add "variants" "warn" "num_ctx not in show output" "$tag"
      continue
    fi

    if [ "$actual_ctx" = "$ctx_expected" ]; then
      ok "$tag — num_ctx=$actual_ctx (matches registry)"
      [ "$JSON_MODE" = "1" ] && json_add "variants" "ok" "num_ctx matches" "$tag ctx=$actual_ctx"
    else
      warn "$tag — num_ctx=$actual_ctx but registry says $ctx_expected"
      info "fix: re-run ./install.sh to rebuild the variant with the correct num_ctx"
      [ "$JSON_MODE" = "1" ] && json_add "variants" "warn" "num_ctx mismatch" "have=$actual_ctx want=$ctx_expected"
    fi
  done
}

# ----------------------------------------------------------------------------
# Section 4: Config — does the opencode config exist and reference the
#            sidecar's models?
# ----------------------------------------------------------------------------

check_config() {
  echo "Config"

  if [ "$ETUDE_MODE" != "configured" ]; then
    info "mode=$ETUDE_MODE — skipping config check (bare mode has no opencode.json)"
    return 0
  fi

  local cfg="${ETUDE_OPENCODE_CONFIG_PATH:-$HOME/.config/opencode/opencode.json}"
  if [ ! -f "$cfg" ]; then
    err "opencode config not found at $cfg"
    info "fix: re-run ./install.sh --mode configured"
    [ "$JSON_MODE" = "1" ] && json_add "config" "error" "config file missing" "$cfg"
    return 1
  fi

  ok "config: $cfg"

  # Check that each sidecar model tag appears in the config file.
  local tag role
  for entry in "${ETUDE_MODELS[@]}"; do
    tag=$(model_tag "$entry")
    role=$(model_role "$entry")

    # Skip cloud models — they're in the template but not in the sidecar
    # (sidecar only records locally-installed models).
    if echo "$tag" | grep -q ':cloud$'; then
      continue
    fi

    if grep -q "\"$tag\"" "$cfg" 2>/dev/null; then
      ok "$tag ($role) — referenced in config"
      [ "$JSON_MODE" = "1" ] && json_add "config" "ok" "model in config" "$tag"
    else
      warn "$tag ($role) — not found in config"
      info "the model is installed but opencode doesn't know about it"
      info "fix: re-run ./install.sh or manually add it to $cfg"
      [ "$JSON_MODE" = "1" ] && json_add "config" "warn" "model not in config" "$tag"
    fi
  done
}

# ----------------------------------------------------------------------------
# Section 5: Registry freshness — is the sidecar's TSV date current?
# ----------------------------------------------------------------------------

check_registry() {
  echo "Registry"

  local repo_date sidecar_date
  repo_date=$(tiers_last_reviewed)
  sidecar_date="${ETUDE_TSV_LAST_REVIEWED:-unknown}"

  if [ "$sidecar_date" = "unknown" ] || [ -z "$sidecar_date" ]; then
    warn "sidecar doesn't record TSV date — can't check for registry drift"
    [ "$JSON_MODE" = "1" ] && json_add "registry" "warn" "no TSV date in sidecar" ""
  elif [ "$sidecar_date" != "$repo_date" ]; then
    warn "registry updated since install (sidecar=$sidecar_date, repo=$repo_date)"
    info "model recommendations or context windows may have changed"
    info "fix: re-run ./install.sh (or future: ./install.sh --refresh)"
    [ "$JSON_MODE" = "1" ] && json_add "registry" "warn" "registry date mismatch" "sidecar=$sidecar_date repo=$repo_date"
  else
    ok "registry date: $repo_date (sidecar matches)"
    [ "$JSON_MODE" = "1" ] && json_add "registry" "ok" "dates match" "$repo_date"
  fi

  # Check for orphan variants — variants in ollama list that don't appear
  # in the sidecar. These aren't errors, just clutter.
  local installed
  installed=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}') || return 0

  local sidecar_tags=""
  for entry in "${ETUDE_MODELS[@]}"; do
    sidecar_tags="$sidecar_tags $(model_tag "$entry")"
  done

  local orphans=""
  while read -r model_name; do
    [ -z "$model_name" ] && continue
    # Only flag etude-style variants (tags with -Nk suffix).
    if ! echo "$model_name" | grep -qE -- '-[0-9]+k$'; then
      continue
    fi
    if ! echo "$sidecar_tags" | grep -qF -- "$model_name"; then
      orphans="$orphans $model_name"
    fi
  done <<< "$installed"

  if [ -n "$orphans" ]; then
    warn "orphan variant(s) in ollama list (not in sidecar):$orphans"
    info "these may be leftover from testing — safe to remove with: ollama rm <tag>"
    [ "$JSON_MODE" = "1" ] && json_add "registry" "warn" "orphan variants" "${orphans# }"
  fi
}

# ----------------------------------------------------------------------------
# Section 6 (optional): Check upstream tags
# ----------------------------------------------------------------------------

check_updates() {
  echo "Upstream tags"

  # Collect unique base tags with their reliability from the tier's registry rows.
  local rows
  rows=$(tiers_rows_for "$ETUDE_TIER" | awk -F'|' '!seen[$2]++ {print $2 "|" $5}')

  if [ -z "$rows" ]; then
    info "(no base tags to check)"
    return 0
  fi

  while IFS='|' read -r base reliability; do
    [ -z "$base" ] && continue
    info "checking: $base"
    local manifest_out
    manifest_out=$(ollama show "$base" --modelfile 2>&1)
    local rc=$?
    if [ $rc -eq 0 ]; then
      ok "$base — resolves locally"
      [ "$JSON_MODE" = "1" ] && json_add "updates" "ok" "tag resolves" "$base"
    else
      # Try the ollama.com tags page to check if the tag exists upstream.
      # No public API exists, so we scrape the HTML for "model:tag" strings.
      local model_name="${base%%:*}"
      local page_out known_tags
      page_out=$(curl -fsS "https://ollama.com/library/${model_name}/tags" 2>&1)
      known_tags=$(echo "$page_out" | grep -o "${model_name}:[^\"<[:space:]]*" | sort -u)
      if echo "$known_tags" | grep -qxF -- "$base"; then
        if [ "$reliability" = "watching" ] || [ "$reliability" = "broken" ]; then
          # Not-yet-recommended models that aren't pulled locally — expected, not a warning.
          ok "$base — exists upstream (not pulled, reliability=$reliability)"
          [ "$JSON_MODE" = "1" ] && json_add "updates" "ok" "exists upstream (not pulled)" "$base"
        else
          warn "$base — exists in ollama registry but not pulled locally"
          [ "$JSON_MODE" = "1" ] && json_add "updates" "warn" "not pulled" "$base"
        fi
      else
        err "$base — tag not found in ollama registry"
        info "this base tag may have been renamed or removed upstream"
        [ "$JSON_MODE" = "1" ] && json_add "updates" "error" "tag not found" "$base"
      fi
    fi
  done <<< "$rows"
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

main() {
  echo "etude — status"
  echo "=============="
  echo

  check_sidecar
  echo
  # If sidecar failed to load, the remaining checks are meaningless.
  if [ "${#ETUDE_MODELS[@]}" -eq 0 ] && [ -z "$ETUDE_TIER" ]; then
    echo "-----"
    echo "Cannot continue without a sidecar. Run ./install.sh first."
    exit 1
  fi

  check_models
  echo

  check_variants
  echo

  check_config
  echo

  check_registry
  echo

  if [ "$CHECK_UPDATES" = "1" ]; then
    check_updates
    echo
  fi

  echo "-----"
  if [ "$ISSUES" -eq 0 ]; then
    echo "no issues found"
  else
    printf '%d issue(s) found\n' "$ISSUES"
  fi

  if [ "$JSON_MODE" = "1" ]; then
    json_emit
  fi

  [ "$ISSUES" -eq 0 ]
}

main
