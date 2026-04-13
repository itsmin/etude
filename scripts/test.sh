#!/usr/bin/env bash
# etude — smoke test.
#
# Runs a layered check of the install. Can be run directly by the user, or
# invoked by install.sh Phase 5 as the final verification step.
#
# Levels (runs in order, stops at first failure):
#   1  binaries present   — ollama and opencode on PATH, versions meet minimums
#   2  ollama daemon      — http://localhost:11434 is reachable
#   3  models present     — every model in the sidecar appears in `ollama list`
#   4  model inference    — daily model replies to a minimal prompt
#   5  full stack         — opencode one-shot (STUB until verified on real hardware)
#
# Exit codes:
#   0  all levels passed (or skipped with a warning)
#   1..5  the level at which we failed
#
# Usage:
#   ./scripts/test.sh             # run all levels against whatever is installed
#   ./scripts/test.sh --verbose   # show raw command output for each level
#   ./scripts/test.sh --level N   # run only up through level N

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/tiers.sh
source "$SCRIPT_DIR/lib/tiers.sh"

SIDECAR="${ETUDE_SIDECAR:-$HOME/.config/etude/install.sh}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
OLLAMA_MIN_VERSION="0.20.2"

VERBOSE=0
MAX_LEVEL=5

while [ $# -gt 0 ]; do
  case "$1" in
    --verbose|-v) VERBOSE=1 ;;
    --level) MAX_LEVEL="$2"; shift ;;
    -h|--help)
      sed -n '2,25p' "$0"
      exit 0
      ;;
    *) echo "etude test: unknown flag '$1'" >&2; exit 2 ;;
  esac
  shift
done

# ----------------------------------------------------------------------------
# Output helpers
# ----------------------------------------------------------------------------

pass()  { printf '  \033[32mok\033[0m    %s\n'   "$1"; }
fail()  { printf '  \033[31mFAIL\033[0m  %s\n'   "$1"; }
skip()  { printf '  \033[33mskip\033[0m  %s\n'   "$1"; }
note()  { printf '        %s\n' "$1"; }
vnote() { [ "$VERBOSE" = "1" ] && printf '        %s\n' "$1"; return 0; }

# Semver-ish compare: returns 0 if $1 >= $2.
version_ge() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# ----------------------------------------------------------------------------
# Sidecar
# ----------------------------------------------------------------------------

ETUDE_TIER=""
ETUDE_MODELS=()
ETUDE_MODE=""
ETUDE_OPENCODE_CONFIG_PATH=""

load_sidecar() {
  if [ ! -f "$SIDECAR" ]; then
    return 1
  fi
  # shellcheck source=/dev/null
  source "$SIDECAR"
  return 0
}

# Extract the tag (first colon-separated field) from an ETUDE_MODELS entry.
# Entries are formatted as "tag:role", e.g. "qwen3:4b:daily".
# The tag itself may contain a colon, so we strip only the trailing :role.
model_tag() {
  echo "$1" | sed 's/:[^:]*$//'
}

model_role() {
  echo "$1" | awk -F: '{print $NF}'
}

daily_model_tag() {
  for entry in "${ETUDE_MODELS[@]}"; do
    if [ "$(model_role "$entry")" = "daily" ]; then
      model_tag "$entry"
      return 0
    fi
  done
  return 1
}

# ----------------------------------------------------------------------------
# Levels
# ----------------------------------------------------------------------------

level1_binaries() {
  echo "Level 1 — binaries"

  if ! command -v ollama >/dev/null 2>&1; then
    fail "ollama not found on PATH"
    note "install with: brew install --cask ollama  (or download Ollama.app from ollama.com)"
    return 1
  fi

  # Detect the install problems install.sh Phase 1 also catches. test.sh
  # can be run standalone, so the detection has to live here too.
  local raw
  raw=$(ollama --version 2>&1)
  if echo "$raw" | grep -qi "warning: client version"; then
    fail "ollama client/server version mismatch"
    note "raw: $(echo "$raw" | tr '\n' ' ')"
    note "fix: brew uninstall ollama (removes stale formula), then re-run"
    return 1
  fi

  local ollama_ver
  ollama_ver=$(echo "$raw" | awk '/^ollama version/ {print $NF; exit}')
  if [ -z "$ollama_ver" ]; then
    fail "could not parse ollama version"
    note "raw: $raw"
    return 1
  fi
  if ! version_ge "$ollama_ver" "$OLLAMA_MIN_VERSION"; then
    fail "ollama $ollama_ver is below minimum $OLLAMA_MIN_VERSION"
    note "upgrade Ollama.app from its menu bar, or: brew install --cask ollama"
    return 1
  fi
  if ! ollama launch --help >/dev/null 2>&1; then
    fail "ollama $ollama_ver has no 'launch' subcommand (required for bare mode)"
    note "upgrade Ollama.app from its menu bar, or: brew install --cask ollama"
    return 1
  fi
  pass "ollama $ollama_ver (>= $OLLAMA_MIN_VERSION, supports launch)"

  if ! command -v opencode >/dev/null 2>&1; then
    fail "opencode not found on PATH"
    note "install with: curl -fsSL https://opencode.ai/install | bash"
    note "then ensure ~/.opencode/bin is on PATH"
    return 1
  fi
  local opencode_ver
  opencode_ver=$(opencode --version 2>&1 | head -n1)
  pass "opencode $opencode_ver"

  return 0
}

level2_daemon() {
  echo "Level 2 — ollama daemon"

  if ! command -v curl >/dev/null 2>&1; then
    skip "curl not found, falling back to 'ollama list'"
    if ollama list >/dev/null 2>&1; then
      pass "ollama list responds"
      return 0
    fi
    fail "ollama list failed — daemon not running?"
    note "start it with: ollama serve  (or launch the Ollama.app)"
    return 1
  fi

  if curl -fsS "$OLLAMA_HOST/api/tags" >/dev/null 2>&1; then
    pass "daemon reachable at $OLLAMA_HOST"
    return 0
  fi
  fail "daemon not reachable at $OLLAMA_HOST"
  note "start it with: ollama serve  (or launch the Ollama.app)"
  return 1
}

level3_models() {
  echo "Level 3 — models from sidecar"

  if ! load_sidecar; then
    skip "no sidecar at $SIDECAR — has install.sh been run?"
    return 0
  fi

  if [ -z "${ETUDE_MODELS+x}" ] || [ "${#ETUDE_MODELS[@]}" -eq 0 ]; then
    skip "sidecar has no models recorded"
    return 0
  fi

  local installed
  installed=$(ollama list 2>/dev/null | awk 'NR>1 {print $1}')
  local missing=0
  for entry in "${ETUDE_MODELS[@]}"; do
    local tag
    tag=$(model_tag "$entry")
    if echo "$installed" | grep -qx "$tag"; then
      pass "$tag present"
    else
      fail "$tag missing from ollama list"
      missing=$((missing + 1))
    fi
  done

  if [ "$missing" -gt 0 ]; then
    note "re-pull with: ollama pull <tag>  (or re-run ./install.sh)"
    return 1
  fi
  return 0
}

level4_inference() {
  echo "Level 4 — inference"

  local tag
  if ! load_sidecar || ! tag=$(daily_model_tag); then
    skip "no daily model in sidecar, nothing to run inference against"
    return 0
  fi

  note "running: ollama run $tag \"reply with exactly: OK\""
  local out
  out=$(printf 'Reply with exactly: OK\n' | ollama run "$tag" 2>&1)
  vnote "model said: $out"

  if echo "$out" | grep -q "OK"; then
    pass "$tag responded"
    return 0
  fi
  fail "$tag did not produce expected response"
  note "raw output: $out"
  return 1
}

level5_stack() {
  echo "Level 5 — full stack via opencode"
  # TODO(session-03): wire this up once opencode's non-interactive CLI is
  # confirmed on the M3 Air. Target test: send a one-shot prompt that writes
  # a file to /tmp/etude-test-$$ and verify the file exists, then clean up.
  # Until then, the best we can do is verify opencode loads its config.
  skip "stubbed until session #03 real-hardware run confirms opencode one-shot syntax"
  note "TODO: write /tmp/etude-test file via opencode one-shot and verify"
  return 0
}

# ----------------------------------------------------------------------------
# Runner
# ----------------------------------------------------------------------------

main() {
  echo "etude — smoke test"
  echo "=================="
  echo

  local rc=0

  [ "$MAX_LEVEL" -ge 1 ] && { level1_binaries   || { rc=1; exit 1; }; echo; }
  [ "$MAX_LEVEL" -ge 2 ] && { level2_daemon     || { rc=2; exit 2; }; echo; }
  [ "$MAX_LEVEL" -ge 3 ] && { level3_models     || { rc=3; exit 3; }; echo; }
  [ "$MAX_LEVEL" -ge 4 ] && { level4_inference  || { rc=4; exit 4; }; echo; }
  [ "$MAX_LEVEL" -ge 5 ] && { level5_stack      || { rc=5; exit 5; }; echo; }

  echo "-----"
  if [ "$rc" = "0" ]; then
    echo "passed levels 1..$MAX_LEVEL"
  fi
  return $rc
}

main
