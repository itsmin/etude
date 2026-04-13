#!/usr/bin/env bash
# etude — registry operations.
#
# Source this file, don't execute it. Provides functions that read
# scripts/lib/tiers.tsv and expose it to the rest of etude.
#
# The rest of etude (detect-tier.sh, install.sh, test.sh) MUST go through
# these functions, not parse the TSV directly. That's how we keep one source
# of truth and catch drift.

# Resolve the repo root. BASH_SOURCE points at this file regardless of how
# it was sourced.
ETUDE_ROOT="${ETUDE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ETUDE_TIERS_TSV="$ETUDE_ROOT/scripts/lib/tiers.tsv"
ETUDE_CONFIG_DIR="$ETUDE_ROOT/config/opencode"

# ----------------------------------------------------------------------------
# Low-level parsing
# ----------------------------------------------------------------------------

# Strip comments and blank lines, trim whitespace around pipe separators.
# Emits normalized rows: "tier|model|size_gb|context|reliability|role|note"
tiers_read() {
  if [ ! -f "$ETUDE_TIERS_TSV" ]; then
    echo "etude: tier registry not found at $ETUDE_TIERS_TSV" >&2
    return 1
  fi
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    {
      # split on "|" and trim each field
      n = split($0, f, "|")
      out = ""
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", f[i])
        out = (i == 1 ? f[i] : out "|" f[i])
      }
      print out
    }
  ' "$ETUDE_TIERS_TSV"
}

# Extract one field from a registry row.
# Usage: echo "$row" | tiers_field <n>   (1-indexed)
tiers_field() {
  awk -F'|' -v n="$1" '{print $n}'
}

# ----------------------------------------------------------------------------
# Queries
# ----------------------------------------------------------------------------

# All unique tier names in the registry.
tiers_all_names() {
  tiers_read | awk -F'|' '{print $1}' | awk '!seen[$0]++'
}

# Does a tier exist in the registry? (returns 0/1)
tiers_has() {
  local tier="$1"
  tiers_all_names | grep -qx "$tier"
}

# All rows for a tier, unfiltered.
tiers_rows_for() {
  local tier="$1"
  tiers_read | awk -F'|' -v t="$tier" '$1 == t'
}

# Rows for a tier, visible to the default picker (reliability != broken and != watching).
tiers_rows_visible() {
  local tier="$1"
  tiers_rows_for "$tier" | awk -F'|' '$5 == "good"'
}

# Rows for a tier filtered by role.
tiers_rows_by_role() {
  local tier="$1" role="$2"
  tiers_rows_visible "$tier" | awk -F'|' -v r="$role" '$6 == r'
}

# Watchlist rows for a tier (reliability=watching). These are the "not ready
# yet, track for promotion" models — Gemma 4 E4B today, whatever drops next.
tiers_watchlist_for() {
  local tier="$1"
  tiers_rows_for "$tier" | awk -F'|' '$5 == "watching"'
}

# The "Last reviewed" date from the registry header, or "unknown".
tiers_last_reviewed() {
  awk '/^# Last reviewed:/ { print $4; exit }' "$ETUDE_TIERS_TSV" 2>/dev/null || echo "unknown"
}

# ----------------------------------------------------------------------------
# Consistency checks
# ----------------------------------------------------------------------------

# Every tier in the registry must have a corresponding config template at
# config/opencode/<tier>.json. This is a hard error — repo is broken.
#
# A tier with no good-reliability daily model is a soft warning — the tier
# exists and is documented, but install.sh will refuse to install into it
# because no model is verified yet. This is legitimate for frontier tiers.
#
# Returns 0 if no hard errors, 1 otherwise. Always prints warnings to stderr.
tiers_check_consistency() {
  local rc=0
  local tier
  while read -r tier; do
    [ -z "$tier" ] && continue

    local cfg="$ETUDE_CONFIG_DIR/${tier}.json"
    if [ ! -f "$cfg" ]; then
      printf 'etude: ERROR tier "%s" has no config template at %s\n' "$tier" "$cfg" >&2
      rc=1
    fi

    local daily_count
    daily_count=$(tiers_rows_by_role "$tier" daily | wc -l | tr -d ' ')
    if [ "$daily_count" = "0" ]; then
      printf 'etude: warn  tier "%s" has no good-reliability daily model (install will refuse this tier)\n' "$tier" >&2
    fi
  done < <(tiers_all_names)
  return $rc
}

# Is this tier installable right now? A tier is installable if it has a
# config template AND at least one good-reliability row (any role).
# Returns 0 if installable, 1 if not.
tiers_is_installable() {
  local tier="$1"
  [ -f "$ETUDE_CONFIG_DIR/${tier}.json" ] || return 1
  local visible_count
  visible_count=$(tiers_rows_visible "$tier" | wc -l | tr -d ' ')
  [ "$visible_count" -gt 0 ]
}

# Human-readable summary of a tier for the picker / detection output.
# Usage: tiers_describe <tier>
tiers_describe() {
  local tier="$1"
  if ! tiers_has "$tier"; then
    echo "etude: unknown tier '$tier'" >&2
    return 1
  fi
  printf 'Tier: %s\n' "$tier"
  printf '\nRecommended models:\n'
  local row model size ctx rel role note
  while IFS='|' read -r _ model size ctx rel role note; do
    [ -z "$model" ] && continue
    printf '  [%s]  %-22s  %sGB  %sK ctx\n' "$role" "$model" "$size" "$((ctx / 1024))"
    if [ -n "$note" ]; then
      printf '          %s\n' "$note"
    fi
  done < <(tiers_rows_visible "$tier")

  local watch_count
  watch_count=$(tiers_watchlist_for "$tier" | wc -l | tr -d ' ')
  if [ "$watch_count" -gt 0 ]; then
    printf '\nWatchlist (tracked, not yet recommended):\n'
    while IFS='|' read -r _ model _ _ _ _ note; do
      [ -z "$model" ] && continue
      printf '  %-22s  %s\n' "$model" "$note"
    done < <(tiers_watchlist_for "$tier")
  fi
}
