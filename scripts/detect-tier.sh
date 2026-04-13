#!/usr/bin/env bash
# etude — detect the machine's tier and print a recommended model config.
# Works on macOS and Linux. On Windows, run inside WSL or see docs/install-windows.md.

set -e

platform="$(uname -s)"

print_header() {
  echo
  echo "etude — tier detection"
  echo "----------------------"
}

detect_mac() {
  ram_bytes=$(sysctl -n hw.memsize)
  ram_gb=$((ram_bytes / 1024 / 1024 / 1024))
  chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || sysctl -n hw.model)

  echo "Platform:    macOS (Apple Silicon)"
  echo "Chip:        $chip"
  echo "Unified RAM: ${ram_gb}GB"
  echo

  if [ "$ram_gb" -le 16 ]; then
    echo "Tier:          mac-light"
    echo "Daily driver:  qwen3:4b (Q4, ~2.4GB)"
    echo "Heavy mode:    qwen3:8b (Q4, ~5.2GB) — close other apps first"
    echo "Context:       16K"
  elif [ "$ram_gb" -le 24 ]; then
    echo "Tier:          mac-air-24gb"
    echo "Daily driver:  qwen3:8b (Q4, ~5.2GB)"
    echo "Heavy mode:    qwen3-coder:30b-a3b (Q4, ~17GB — close the browser)"
    echo "Context:       32K"
    echo
    echo "Note: below the Ollama MLX backend threshold (32GB+)."
    echo "Falls back to llama.cpp backend — still good, just no MLX decode bump."
  elif [ "$ram_gb" -le 48 ]; then
    echo "Tier:          mac-pro-32gb"
    echo "Daily driver:  qwen3-coder:30b-a3b (Q4, ~17GB, MLX backend active)"
    echo "Context:       32K–64K"
  elif [ "$ram_gb" -le 96 ]; then
    echo "Tier:          mac-heavy-64gb"
    echo "Daily driver:  qwen3-coder:30b-a3b (Q4)"
    echo "Heavy mode:    qwen3-coder-next:80b (Q4, ~46GB)"
    echo "Context:       64K"
  else
    echo "Tier:          mac-max"
    echo "Daily driver:  qwen3-coder-next:80b (Q4)"
    echo "Heavy mode:    experiment freely"
    echo "Context:       128K"
  fi

  echo
  echo "Next step:     cat docs/install-macos.md"
  echo "Config:        config/opencode/mac-air-24gb.json (adapt to your tier)"
}

detect_linux() {
  ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  ram_gb=$((ram_kb / 1024 / 1024))

  echo "Platform:    Linux"
  echo "System RAM:  ${ram_gb}GB"
  echo

  if command -v nvidia-smi >/dev/null 2>&1; then
    vram_mib=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
    vram_gb=$((vram_mib / 1024))
    gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)

    echo "GPU:         $gpu_name"
    echo "VRAM:        ${vram_gb}GB"
    echo

    if [ "$vram_gb" -le 12 ]; then
      echo "Tier:          gpu-light"
      echo "Daily driver:  qwen3:8b (Q4)"
      echo "Context:       16K–32K"
    elif [ "$vram_gb" -le 16 ]; then
      echo "Tier:          gpu-16gb"
      echo "Daily driver:  qwen3-coder:30b-a3b (Q4, ~17GB, partial offload)"
      echo "Speed mode:    qwen3:8b (Q8, full VRAM)"
      echo "Context:       32K"
    elif [ "$vram_gb" -le 24 ]; then
      echo "Tier:          gpu-24gb"
      echo "Daily driver:  qwen3-coder:30b-a3b (Q4, full VRAM)"
      echo "Alt:           dense qwen3:32b (Q4)"
      echo "Context:       32K–64K"
    else
      echo "Tier:          gpu-heavy"
      echo "Daily driver:  dense qwen3:32b or larger MoE"
      echo "Context:       64K+"
    fi

    echo
    echo "Next step:     cat docs/install-windows.md (Windows/WSL) or adapt steps for Linux"
    echo "Config:        config/opencode/gpu-rtx5080-16gb.json (adapt to your VRAM tier)"
  else
    echo "No NVIDIA GPU detected. CPU-only inference is viable only for very small models."
    echo "Tier:          cpu-only"
    echo "Daily driver:  qwen3:4b (expect unreliable tool calling)"
    echo "Context:       16K"
  fi
}

print_header

case "$platform" in
  Darwin) detect_mac ;;
  Linux)  detect_linux ;;
  *)
    echo "Unsupported platform: $platform"
    echo "On Windows, run this script inside WSL2 or follow docs/install-windows.md directly."
    exit 1
    ;;
esac

echo
