#!/usr/bin/env bash
# etude — guided install.
#
# Five phases, only phase 4 has side effects:
#   1  Preflight   — validate the repo and the host, no writes
#   2  Detect      — read hardware, map to tier, confirm with user
#   3  Plan        — check existing state, model picker, build + confirm full plan
#   4  Execute     — install deps, pull models, write config + sidecar
#   5  Smoke test  — scripts/test.sh against the fresh install
#
# Flags:
#   --dry-run         print what each phase would do, no side effects anywhere
#   --plan            stop at end of phase 3 (don't execute)
#   --tier NAME       override hardware detection
#   --mode MODE       bare | configured (skip the mode prompt)
#   --non-interactive accept all defaults, no prompts
#
# Homebrew is a prerequisite — this script does not install it.
# On a fresh Mac, run `xcode-select --install` first to get git + cli tools.

set -uo pipefail

ETUDE_ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib/tiers.sh
source "$ETUDE_ROOT/scripts/lib/tiers.sh"

# ----------------------------------------------------------------------------
# Flags / state
# ----------------------------------------------------------------------------

DRY_RUN=0
PLAN_ONLY=0
NON_INTERACTIVE=0
TIER_OVERRIDE=""
MODE_OVERRIDE=""

DETECTED_TIER=""
DETECTED_DESCRIBE=""
CHOSEN_TIER=""
CHOSEN_DAILY=""            # base tag (what `ollama pull` accepts), e.g. "qwen3:8b"
CHOSEN_HEAVY=""            # base tag or empty
CHOSEN_DAILY_VARIANT=""    # local variant with baked num_ctx, e.g. "qwen3:8b-32k"
CHOSEN_HEAVY_VARIANT=""    # local variant or empty
CHOSEN_MODE=""             # "bare" or "configured"

# Things Phase 3 writes, Phase 4 reads
DEPS_MISSING=()    # e.g. ("ollama" "opencode")
MODELS_TO_PULL=()  # e.g. ("qwen3:4b" "qwen3:8b")
TOTAL_PULL_GB="0"

SIDECAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/etude"
SIDECAR_PATH="$SIDECAR_DIR/install.sh"
OPENCODE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
OPENCODE_CONFIG_PATH="$OPENCODE_CONFIG_DIR/opencode.json"
OLLAMA_MIN_VERSION="0.20.2"

# ----------------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)          DRY_RUN=1 ;;
    --plan)             PLAN_ONLY=1 ;;
    --non-interactive)  NON_INTERACTIVE=1 ;;
    --tier)             TIER_OVERRIDE="$2"; shift ;;
    --mode)             MODE_OVERRIDE="$2"; shift ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "etude: unknown flag '$1' (try --help)" >&2
      exit 2
      ;;
  esac
  shift
done

# ----------------------------------------------------------------------------
# Output helpers
# ----------------------------------------------------------------------------

phase()  { printf '\n\033[1m%s\033[0m\n' "$1"; printf '%s\n' "$(printf '%.0s-' $(seq 1 ${#1}))"; }
ok()     { printf '  \033[32m✓\033[0m %s\n' "$1"; }
x()      { printf '  \033[31m✗\033[0m %s\n' "$1"; }
warn()   { printf '  \033[33m!\033[0m %s\n' "$1"; }
info()   { printf '  %s\n' "$1"; }
die()    { printf '\n\033[31metude: %s\033[0m\n' "$1" >&2; exit 1; }

# In dry-run, show the command instead of executing it. In real mode, run it.
run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '  \033[90m[dry-run]\033[0m %s\n' "$*"
    return 0
  fi
  "$@"
}

ask() {
  # Prompts go to stderr so $(ask ...) only captures the value.
  local prompt="$1" default="$2"
  if [ "$NON_INTERACTIVE" = "1" ]; then
    printf '  %s [%s]\n' "$prompt" "$default" >&2
    echo "$default"
    return 0
  fi
  local reply
  read -r -p "  $prompt [$default]: " reply </dev/tty >&2
  echo "${reply:-$default}"
}

confirm() {
  local prompt="$1" default="${2:-Y}"
  local hint
  [ "$default" = "Y" ] && hint="[Y/n]" || hint="[y/N]"
  if [ "$NON_INTERACTIVE" = "1" ]; then
    printf '  %s %s\n' "$prompt" "$hint"
    [ "$default" = "Y" ]
    return
  fi
  while true; do
    local reply
    read -r -p "  $prompt $hint " reply
    reply="${reply:-$default}"
    case "$reply" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
    esac
  done
}

version_ge() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# ----------------------------------------------------------------------------
# Phase 1 — Preflight
# ----------------------------------------------------------------------------

phase1_preflight() {
  phase "Phase 1/5 — Preflight"

  # Registry ↔ config consistency
  if tiers_check_consistency; then
    ok "tier registry consistent with config templates"
  else
    die "tier registry is inconsistent with config templates — fix tiers.tsv or config/opencode/"
  fi

  # Required base tools
  for cmd in uname awk sed grep curl; do
    if command -v "$cmd" >/dev/null 2>&1; then
      ok "$cmd present"
    else
      x "$cmd missing"
      die "missing required command: $cmd"
    fi
  done

  # Homebrew is a prerequisite, not an install target
  if command -v brew >/dev/null 2>&1; then
    ok "homebrew present ($(brew --version | head -n1))"
  else
    x "homebrew missing"
    info "install homebrew first, then re-run this script:"
    info ""
    info "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    info ""
    info "after install, make sure /opt/homebrew/bin is on your PATH"
    die "homebrew is a prerequisite"
  fi

  # Write perms to ~/.config
  if mkdir -p "$SIDECAR_DIR" 2>/dev/null && [ -w "$SIDECAR_DIR" ]; then
    ok "can write to $SIDECAR_DIR"
  else
    die "cannot write to $SIDECAR_DIR"
  fi

  # Network sanity — optional (skippable if offline-mode), but warn if down
  if curl -fsSI --max-time 5 https://ollama.com >/dev/null 2>&1; then
    ok "network reachable (ollama.com)"
  else
    warn "ollama.com unreachable — model pulls will fail"
    if ! confirm "continue anyway?" N; then die "aborted at preflight"; fi
  fi

  # Ollama install sanity — if present, must be a single, modern Ollama.app
  # binary with the 'launch' subcommand. Phase 4 will install via cask if
  # missing. Surfaces three real failure modes from the M3 Air session:
  #   1. Multiple ollama binaries on PATH (brew formula + Ollama.app)
  #   2. Client/server version mismatch (stale client intercepts newer server)
  #   3. Ollama too old to have 'launch' (required for bare mode)
  if command -v ollama >/dev/null 2>&1; then
    local ollama_paths path_count
    ollama_paths=$(which -a ollama 2>/dev/null | awk 'NF')
    path_count=$(printf '%s\n' "$ollama_paths" | awk 'NF' | wc -l | tr -d ' ')
    if [ "$path_count" -gt 1 ]; then
      x "multiple ollama binaries on PATH:"
      printf '%s\n' "$ollama_paths" | awk '{print "      " $0}'
      info ""
      info "etude expects a single ollama install (the Ollama.app)."
      info "the brew formula and .app coexist badly — the formula's old client"
      info "intercepts calls meant for the .app's newer server."
      info ""
      info "fix:"
      info "  brew uninstall ollama     # removes the stale brew formula"
      info "  # then re-run this script; Ollama.app stays intact"
      die "ollama install is ambiguous"
    fi

    local ollama_raw
    ollama_raw=$(ollama --version 2>&1)
    if printf '%s\n' "$ollama_raw" | grep -qi "warning: client version"; then
      x "ollama client/server version mismatch:"
      printf '%s\n' "$ollama_raw" | awk '{print "      " $0}'
      info ""
      info "a stale ollama client is intercepting calls meant for a newer server."
      info "fix: brew uninstall ollama, then re-run this script"
      die "ollama version mismatch"
    fi

    if ! ollama launch --help >/dev/null 2>&1; then
      x "ollama lacks the 'launch' subcommand (required for bare mode)"
      info ""
      info "the installed ollama is too old. upgrade:"
      info "  brew uninstall ollama           # if installed via brew formula"
      info "  brew install --cask ollama      # install the Ollama.app cask"
      info "  # or update Ollama.app from its menu bar"
      die "ollama too old — no 'launch' subcommand"
    fi

    local ollama_ver
    ollama_ver=$(printf '%s\n' "$ollama_raw" | awk '/^ollama version/ {print $NF; exit}')
    ok "ollama ${ollama_ver:-unknown} (present, supports 'launch')"
  else
    info "ollama not installed — will install Ollama.app via brew cask in Phase 4"
  fi
}

# ----------------------------------------------------------------------------
# Phase 2 — Detect
# ----------------------------------------------------------------------------

phase2_detect() {
  phase "Phase 2/5 — Detect"

  if [ -n "$TIER_OVERRIDE" ]; then
    DETECTED_TIER="$TIER_OVERRIDE"
    DETECTED_DESCRIBE="(override)"
    info "tier forced to '$DETECTED_TIER' via --tier"
  else
    DETECTED_TIER=$("$ETUDE_ROOT/scripts/detect-tier.sh" --tier-only 2>/dev/null) || true
    local detect_json
    detect_json=$("$ETUDE_ROOT/scripts/detect-tier.sh" --json 2>/dev/null) || true
    DETECTED_DESCRIBE=$(echo "$detect_json" | sed 's/.*"describe":"\([^"]*\)".*/\1/')
  fi

  if [ -z "$DETECTED_TIER" ]; then
    x "hardware did not map to a known tier"
    info "this machine's profile isn't in the registry."
    info "you can pass --tier <name> to force one, or stop and add a tier to scripts/lib/tiers.tsv"
    info "available tiers:"
    tiers_all_names | sed 's/^/    /'
    die "no tier detected"
  fi

  info "machine: $DETECTED_DESCRIBE"
  info "tier:    $DETECTED_TIER"

  if ! tiers_has "$DETECTED_TIER"; then
    die "detected tier '$DETECTED_TIER' is not in the registry"
  fi

  if ! tiers_is_installable "$DETECTED_TIER"; then
    warn "tier '$DETECTED_TIER' has no verified models yet (only watchlist entries)"
    info "nothing to install for this tier. see docs/models.md."
    die "tier not installable"
  fi

  echo
  if ! confirm "use tier '$DETECTED_TIER'?" Y; then
    die "aborted at detection"
  fi
  CHOSEN_TIER="$DETECTED_TIER"
}

# ----------------------------------------------------------------------------
# Phase 3 — Plan
# ----------------------------------------------------------------------------

# Picker: given a tier and a role, present rows and let the user pick one.
# Prints the chosen model tag on stdout. Empty if the user picks "none" for optional roles.
pick_model() {
  local tier="$1" role="$2" required="$3"

  local -a tags=()
  local -a sizes=()
  local -a notes=()
  while IFS='|' read -r _ model size _ _ _ note; do
    [ -z "$model" ] && continue
    tags+=("$model")
    sizes+=("$size")
    notes+=("$note")
  done < <(tiers_rows_by_role "$tier" "$role")

  if [ "${#tags[@]}" -eq 0 ]; then
    if [ "$required" = "required" ]; then
      die "no '$role' models for tier '$tier'"
    fi
    echo ""
    return 0
  fi

  printf '\n  %s models:\n' "$role" >&2
  local i
  for i in "${!tags[@]}"; do
    printf '    [%d] %-22s %sGB   %s\n' "$((i + 1))" "${tags[$i]}" "${sizes[$i]}" "${notes[$i]}" >&2
  done
  if [ "$required" != "required" ]; then
    printf '    [n] none (skip %s)\n' "$role" >&2
  fi

  # For optional roles, default to skip. This biases install toward
  # "minimal working install" instead of "silently pull the heaviest
  # model on the list" — which matters for --non-interactive mode and
  # makes interactive Enter-key presses safer too.
  local default="1"
  [ "$required" != "required" ] && default="n"
  while true; do
    local choice
    choice=$(ask "pick $role" "$default")
    case "$choice" in
      n|N|none)
        [ "$required" = "required" ] && { warn "$role is required"; continue; }
        echo ""
        return 0
        ;;
      [0-9]*)
        if [ "$choice" -ge 1 ] && [ "$choice" -le "${#tags[@]}" ]; then
          echo "${tags[$((choice - 1))]}"
          return 0
        fi
        warn "pick a number between 1 and ${#tags[@]}"
        ;;
      *)
        warn "unrecognized input"
        ;;
    esac
  done
}

phase3_plan() {
  phase "Phase 3/5 — Plan"

  # Inventory deps. Phase 1 already validated ollama if present (single
  # binary, no version mismatch, supports 'launch'). Here we only detect
  # presence/absence and extract a version string for display.
  DEPS_MISSING=()
  if command -v ollama >/dev/null 2>&1; then
    local v
    v=$(ollama --version 2>&1 | awk '/^ollama version/ {print $NF; exit}')
    ok "Ollama.app ${v:-present} (already installed)"
  else
    info "Ollama.app missing — will install via brew cask"
    DEPS_MISSING+=("ollama")
  fi

  if command -v opencode >/dev/null 2>&1; then
    ok "opencode present"
  else
    info "opencode missing — will install via opencode.ai/install"
    DEPS_MISSING+=("opencode")
  fi

  # Pick models
  echo
  info "picking models for tier '$CHOSEN_TIER'"
  CHOSEN_DAILY=$(pick_model "$CHOSEN_TIER" "daily" "required")
  CHOSEN_HEAVY=$(pick_model "$CHOSEN_TIER" "heavy" "optional")

  MODELS_TO_PULL=()
  [ -n "$CHOSEN_DAILY" ] && MODELS_TO_PULL+=("$CHOSEN_DAILY")
  [ -n "$CHOSEN_HEAVY" ] && MODELS_TO_PULL+=("$CHOSEN_HEAVY")

  # Derive the local variant tag for each chosen pick. The variant is
  # `<base>-<ctx/1024>k`, created in Phase 4 via `ollama create` with a
  # PARAMETER num_ctx <ctx> line. Opencode's templates and the sidecar
  # both reference the variant, not the base — see variant_tag_for in
  # scripts/lib/tiers.sh for the why.
  CHOSEN_DAILY_VARIANT=""
  CHOSEN_HEAVY_VARIANT=""
  if [ -n "$CHOSEN_DAILY" ]; then
    local daily_ctx
    daily_ctx=$(tiers_context_for "$CHOSEN_TIER" "$CHOSEN_DAILY")
    CHOSEN_DAILY_VARIANT=$(variant_tag_for "$CHOSEN_DAILY" "$daily_ctx")
  fi
  if [ -n "$CHOSEN_HEAVY" ]; then
    local heavy_ctx
    heavy_ctx=$(tiers_context_for "$CHOSEN_TIER" "$CHOSEN_HEAVY")
    CHOSEN_HEAVY_VARIANT=$(variant_tag_for "$CHOSEN_HEAVY" "$heavy_ctx")
  fi

  # Compute total pull size by summing TSV size_gb for the chosen models
  TOTAL_PULL_GB=0
  local m row size_gb
  for m in "${MODELS_TO_PULL[@]}"; do
    row=$(tiers_rows_for "$CHOSEN_TIER" | awk -F'|' -v t="$m" '$2 == t {print; exit}')
    size_gb=$(echo "$row" | awk -F'|' '{print $3}')
    TOTAL_PULL_GB=$(awk -v a="$TOTAL_PULL_GB" -v b="$size_gb" 'BEGIN {print a + b}')
  done

  # Pick mode: configured (opencode.json + works headless) vs bare
  # (interactive only). Session #03 established that bare mode can't be
  # verified by test.sh because `opencode run` needs a provider in
  # opencode.json — the 'ollama launch opencode' wrapper that bare mode
  # relies on only sets up the provider at TTY-launch time. So configured
  # is the capable default; bare is the quick-start for users who really
  # don't want a config file.
  echo
  info "two finish modes:"
  info "  configured  — write opencode.json with an 'ollama-local' provider."
  info "                works both interactively (opencode) and headlessly"
  info "                (opencode run ... -m ollama-local/<tag>)."
  info "                /models flips between picks mid-session. recommended."
  info "  bare        — leave opencode stock. launch via 'ollama launch"
  info "                opencode --model <tag>' interactively only —"
  info "                headless 'opencode run' won't work without config."
  if [ -n "$MODE_OVERRIDE" ]; then
    CHOSEN_MODE="$MODE_OVERRIDE"
  else
    local answer
    answer=$(ask "mode" "configured")
    case "$answer" in
      bare|b) CHOSEN_MODE="bare" ;;
      configured|c) CHOSEN_MODE="configured" ;;
      *) warn "unrecognized mode, defaulting to configured"; CHOSEN_MODE="configured" ;;
    esac
  fi

  # Disk space check now that we know the pull size
  local free_gb
  free_gb=$(df -g "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
  if [ -n "$free_gb" ]; then
    if awk -v f="$free_gb" -v need="$TOTAL_PULL_GB" 'BEGIN {exit !(f > need * 1.2)}'; then
      ok "disk: ${free_gb}GB free, need ~${TOTAL_PULL_GB}GB for model pulls"
    else
      warn "disk: ${free_gb}GB free, need ~${TOTAL_PULL_GB}GB — tight"
      if ! confirm "continue anyway?" N; then die "aborted at plan"; fi
    fi
  fi

  # The plan
  echo
  phase "Plan"
  info "tier:      $CHOSEN_TIER"
  info "mode:      $CHOSEN_MODE"
  if [ "${#DEPS_MISSING[@]}" -gt 0 ]; then
    info "install:   ${DEPS_MISSING[*]}"
  else
    info "install:   (none — all deps present)"
  fi
  info "pull:      ${MODELS_TO_PULL[*]}"
  info "pull size: ~${TOTAL_PULL_GB}GB"
  local variant_display=""
  [ -n "$CHOSEN_DAILY_VARIANT" ] && variant_display="$CHOSEN_DAILY_VARIANT"
  [ -n "$CHOSEN_HEAVY_VARIANT" ] && variant_display="${variant_display:+$variant_display }$CHOSEN_HEAVY_VARIANT"
  info "variants:  $variant_display  (local, baked num_ctx)"
  if [ "$CHOSEN_MODE" = "configured" ]; then
    info "config:    $OPENCODE_CONFIG_PATH  (from config/opencode/${CHOSEN_TIER}.json)"
  fi
  info "sidecar:   $SIDECAR_PATH"
  echo

  if ! confirm "proceed with plan?" Y; then
    die "aborted at plan"
  fi
}

# ----------------------------------------------------------------------------
# Phase 4 — Execute
# ----------------------------------------------------------------------------

phase4_execute() {
  phase "Phase 4/5 — Execute"

  # Install deps
  for dep in "${DEPS_MISSING[@]}"; do
    case "$dep" in
      ollama)
        info "installing Ollama.app via brew cask"
        run brew install --cask ollama
        ;;
      opencode)
        info "installing opencode via opencode.ai/install"
        if [ "$DRY_RUN" = "1" ]; then
          run curl -fsSL https://opencode.ai/install '|' bash
        else
          curl -fsSL https://opencode.ai/install | bash
          # opencode's installer drops the binary at ~/.opencode/bin and
          # appends a PATH edit to the shell rc file. That edit doesn't
          # apply to the current process, so Phase 5 (test.sh) and the
          # Done message would fail to find opencode. Prepend it here.
          export PATH="$HOME/.opencode/bin:$PATH"
          ok "opencode on PATH for this session"
        fi
        ;;
    esac
  done

  # Verify Ollama daemon is up
  info "checking ollama daemon"
  local daemon_ok=0
  if [ "$DRY_RUN" = "1" ]; then
    info "  [dry-run] would curl http://localhost:11434/api/tags"
    daemon_ok=1
  elif curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
    ok "daemon reachable"
    daemon_ok=1
  else
    warn "daemon not reachable — attempting to start"
    # Ollama.app doesn't auto-start on install; opening it brings up the
    # background 'ollama serve' daemon. This is the only install path we
    # support on macOS (the brew formula is rejected in Phase 1).
    if command -v open >/dev/null 2>&1; then
      run open -a Ollama 2>/dev/null || true
    fi
    sleep 2
    if curl -fsS http://localhost:11434/api/tags >/dev/null 2>&1; then
      ok "daemon started"
      daemon_ok=1
    else
      warn "could not start ollama daemon automatically"
      info "open the Ollama.app from Applications, then re-run this script"
      if ! confirm "continue without daemon (pulls will fail)?" N; then
        die "aborted: ollama daemon not running"
      fi
    fi
  fi

  # Pull models, then create a local variant with num_ctx baked in.
  #
  # ollama's num_ctx defaults to 4096 regardless of what the model
  # supports, and opencode's limit.context config is send-side only —
  # it doesn't override ollama's receive-side window. At 4K, opencode's
  # tool-definition prompts get truncated before the model sees the
  # tool schema, and the model confabulates tool names from training.
  # Baking num_ctx into a named variant is the fix: the variant loads
  # at the intended context on every call. Session #04 confirmed this
  # holds for qwen3:8b and qwen3-coder:30b — the entire "Qwen can't
  # tool-call" finding from session #03 was this config bug, not a
  # model capability bug.
  for m in "${MODELS_TO_PULL[@]}"; do
    info "pulling $m"
    run ollama pull "$m"
    local ctx variant
    ctx=$(tiers_context_for "$CHOSEN_TIER" "$m")
    variant=$(variant_tag_for "$m" "$ctx")
    info "creating variant $variant (num_ctx=$ctx)"
    if [ "$DRY_RUN" = "1" ]; then
      printf '  \033[90m[dry-run]\033[0m %s\n' "printf 'FROM $m\\nPARAMETER num_ctx $ctx\\n' | ollama create $variant -f /dev/stdin"
    else
      if printf 'FROM %s\nPARAMETER num_ctx %d\n' "$m" "$ctx" \
          | ollama create "$variant" -f /dev/stdin >/dev/null 2>&1; then
        ok "variant $variant ready"
      else
        x "failed to create variant $variant"
        die "ollama create failed for $variant — check 'ollama list'"
      fi
    fi
  done

  # Configured mode: write the opencode config
  if [ "$CHOSEN_MODE" = "configured" ]; then
    run mkdir -p "$OPENCODE_CONFIG_DIR"
    local tpl="$ETUDE_ROOT/config/opencode/${CHOSEN_TIER}.json"
    if [ -f "$OPENCODE_CONFIG_PATH" ]; then
      warn "$OPENCODE_CONFIG_PATH exists"
      local action
      action=$(ask "[d]iff, [b]ackup+write, [o]verwrite, [s]kip" "b")
      case "$action" in
        d|diff)
          run diff -u "$OPENCODE_CONFIG_PATH" "$tpl" || true
          if confirm "now overwrite?" N; then
            run cp "$tpl" "$OPENCODE_CONFIG_PATH"
          fi
          ;;
        b|backup)
          local bak="${OPENCODE_CONFIG_PATH}.bak.$(date +%Y%m%d%H%M%S)"
          run cp "$OPENCODE_CONFIG_PATH" "$bak"
          ok "backed up to $bak"
          run cp "$tpl" "$OPENCODE_CONFIG_PATH"
          ;;
        o|overwrite)
          run cp "$tpl" "$OPENCODE_CONFIG_PATH"
          ;;
        s|skip)
          info "skipping config write"
          ;;
      esac
    else
      run cp "$tpl" "$OPENCODE_CONFIG_PATH"
      [ "$DRY_RUN" = "0" ] && ok "wrote $OPENCODE_CONFIG_PATH"
    fi
  fi

  # Sidecar — always written
  write_sidecar
}

write_sidecar() {
  info "writing sidecar at $SIDECAR_PATH"
  if [ "$DRY_RUN" = "1" ]; then
    info "  [dry-run] would write:"
    build_sidecar_contents | sed 's/^/    /'
    return 0
  fi
  mkdir -p "$SIDECAR_DIR"
  build_sidecar_contents > "$SIDECAR_PATH"
  ok "sidecar written"
}

build_sidecar_contents() {
  # Sidecar records the local variant tags (with baked num_ctx), not
  # the upstream base tags. test.sh reads this and runs its inference
  # and opencode-run checks against the variant — that's what the
  # templates reference too, so every layer stays in sync.
  local models_list=""
  if [ -n "$CHOSEN_DAILY_VARIANT" ]; then
    models_list="  \"$CHOSEN_DAILY_VARIANT:daily\""
  fi
  if [ -n "$CHOSEN_HEAVY_VARIANT" ]; then
    [ -n "$models_list" ] && models_list+=$'\n'
    models_list+="  \"$CHOSEN_HEAVY_VARIANT:heavy\""
  fi
  local cfg_path=""
  [ "$CHOSEN_MODE" = "configured" ] && cfg_path="$OPENCODE_CONFIG_PATH"
  cat <<EOF
# etude — install sidecar (bash-sourceable)
# Written by install.sh. Safe to read, edit only if you know what you're doing.
ETUDE_TIER="$CHOSEN_TIER"
ETUDE_TSV_LAST_REVIEWED="$(tiers_last_reviewed)"
ETUDE_INSTALLED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ETUDE_MODE="$CHOSEN_MODE"
ETUDE_OPENCODE_CONFIG_PATH="$cfg_path"
ETUDE_MODELS=(
$models_list
)
EOF
}

# ----------------------------------------------------------------------------
# Phase 5 — Smoke test
# ----------------------------------------------------------------------------

phase5_smoke() {
  phase "Phase 5/5 — Smoke test"
  if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] would run ./scripts/test.sh"
    return 0
  fi
  "$ETUDE_ROOT/scripts/test.sh" || {
    local rc=$?
    warn "smoke test failed at level $rc"
    info "re-run directly: ./scripts/test.sh --verbose"
    return $rc
  }
}

# ----------------------------------------------------------------------------
# Done
# ----------------------------------------------------------------------------

print_done() {
  phase "Done"
  info "tier:          $CHOSEN_TIER"
  info "mode:          $CHOSEN_MODE"
  info "daily driver:  ${CHOSEN_DAILY_VARIANT:-—}${CHOSEN_DAILY:+  (from $CHOSEN_DAILY)}"
  info "heavy mode:    ${CHOSEN_HEAVY_VARIANT:-—}${CHOSEN_HEAVY:+  (from $CHOSEN_HEAVY)}"
  echo
  if [ "$CHOSEN_MODE" = "bare" ]; then
    info "try it:"
    info "  cd your-project"
    info "  ollama launch opencode --model $CHOSEN_DAILY_VARIANT"
  else
    info "try it:"
    info "  cd your-project && opencode"
    info "  (use /models to switch between picks)"
  fi
  echo
  info "to verify the install later: ./scripts/test.sh"
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

main() {
  echo
  echo "etude — guided install"
  [ "$DRY_RUN" = "1" ] && echo "(dry run — no side effects)"
  [ "$NON_INTERACTIVE" = "1" ] && echo "(non-interactive — defaults used)"

  phase1_preflight
  phase2_detect
  phase3_plan

  if [ "$PLAN_ONLY" = "1" ]; then
    echo
    info "--plan: stopping after phase 3"
    exit 0
  fi

  phase4_execute
  phase5_smoke
  print_done
}

main
