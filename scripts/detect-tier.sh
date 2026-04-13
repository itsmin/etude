#!/usr/bin/env bash
# etude — detect the machine's hardware tier and print recommendations.
#
# Hardware → tier-name mapping lives here (the "physics" part).
# Tier-name → model recommendations lives in scripts/lib/tiers.tsv.
#
# Usage:
#   ./scripts/detect-tier.sh              # human-readable summary
#   ./scripts/detect-tier.sh --tier-only  # prints just the tier name (for scripts)
#   ./scripts/detect-tier.sh --json       # prints detection facts as json-ish kv

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/tiers.sh
source "$SCRIPT_DIR/lib/tiers.sh"

MODE="human"
case "${1:-}" in
  --tier-only) MODE="tier-only" ;;
  --json)      MODE="json"      ;;
  "")          MODE="human"     ;;
  -h|--help)
    echo "Usage: $0 [--tier-only|--json]"
    exit 0
    ;;
  *)
    echo "etude: unknown flag '$1'" >&2
    exit 2
    ;;
esac

# ----------------------------------------------------------------------------
# Hardware detection — produces: PLATFORM, TIER, RAM_GB, CHIP_OR_GPU
# ----------------------------------------------------------------------------

PLATFORM=""
TIER=""
RAM_GB=0
DESCRIBE=""   # short one-line "M1 Air, 16GB" for UX

detect_mac() {
  PLATFORM="macOS (Apple Silicon)"
  local ram_bytes
  ram_bytes=$(sysctl -n hw.memsize)
  RAM_GB=$((ram_bytes / 1024 / 1024 / 1024))
  local chip
  chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || sysctl -n hw.model)
  DESCRIBE="$chip, ${RAM_GB}GB unified"

  if [ "$RAM_GB" -le 16 ]; then
    TIER="mac-light"
  elif [ "$RAM_GB" -le 24 ]; then
    TIER="mac-air-24gb"
  elif [ "$RAM_GB" -le 48 ]; then
    TIER="mac-pro-32gb"
  elif [ "$RAM_GB" -le 96 ]; then
    TIER="mac-heavy-64gb"
  else
    TIER="mac-max"
  fi
}

detect_linux() {
  PLATFORM="Linux"
  local ram_kb
  ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  RAM_GB=$((ram_kb / 1024 / 1024))

  if command -v nvidia-smi >/dev/null 2>&1; then
    local vram_mib vram_gb gpu_name
    vram_mib=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
    vram_gb=$((vram_mib / 1024))
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
    DESCRIBE="$gpu_name, ${vram_gb}GB VRAM (${RAM_GB}GB system RAM)"

    if [ "$vram_gb" -le 12 ]; then
      TIER="gpu-light"
    elif [ "$vram_gb" -le 16 ]; then
      TIER="gpu-16gb"
    elif [ "$vram_gb" -le 24 ]; then
      TIER="gpu-24gb"
    else
      TIER="gpu-heavy"
    fi
  else
    DESCRIBE="No NVIDIA GPU, ${RAM_GB}GB system RAM"
    TIER=""   # unsupported — installer must handle this case explicitly
  fi
}

case "$(uname -s)" in
  Darwin) detect_mac ;;
  Linux)  detect_linux ;;
  *)
    echo "etude: unsupported platform '$(uname -s)'" >&2
    echo "On Windows, run inside WSL2." >&2
    exit 1
    ;;
esac

# ----------------------------------------------------------------------------
# Output
# ----------------------------------------------------------------------------

case "$MODE" in
  tier-only)
    echo "$TIER"
    ;;

  json)
    printf '{"platform":"%s","tier":"%s","ram_gb":%s,"describe":"%s"}\n' \
      "$PLATFORM" "$TIER" "$RAM_GB" "$DESCRIBE"
    ;;

  human)
    echo
    echo "etude — tier detection"
    echo "----------------------"
    printf "Platform:  %s\n" "$PLATFORM"
    printf "Machine:   %s\n" "$DESCRIBE"
    echo

    if [ -z "$TIER" ]; then
      echo "Tier:      (unsupported)"
      echo
      echo "This hardware isn't a tier etude supports out of the box."
      echo "You can still try install.sh — it will ask you to pick a tier"
      echo "manually, or refuse if no tier is a good fit."
      exit 3
    fi

    if ! tiers_has "$TIER"; then
      echo "Tier:      $TIER  (not in registry)"
      echo
      echo "etude: detected tier '$TIER' is not in scripts/lib/tiers.tsv." >&2
      echo "       fix the registry or the detection logic." >&2
      exit 4
    fi

    tiers_describe "$TIER"
    echo
    echo "Next step: ./install.sh"
    echo "Registry last reviewed: $(tiers_last_reviewed)"
    ;;
esac
