# Hardware tiers

*Last reviewed: 2026-04-12*

Pick a row based on the machine in front of you. Each row has a daily-driver model (fast, reliable tool calling) and an optional heavy mode (slower, smarter, close the browser first).

Two independent axes:
- **Apple Silicon Macs** are bounded by **unified memory**. All RAM is available to the model.
- **Linux/Windows PCs with a discrete GPU** are bounded by **VRAM**, with system RAM as partial-offload fallback.

## Mac tiers (Apple Silicon)

| Tier | Unified RAM | Daily driver | Heavy mode | Notes |
|---|---|---|---|---|
| `mac-light` | 8–16GB | Qwen3 4B Q4 (~2.4GB) | Qwen3 8B Q4 (~5.2GB) | Tool calling works but degrades. Close other apps before heavy mode. |
| `mac-air-24gb` | 24GB | Qwen3 8B Q4 (~5.2GB) | Qwen3-Coder 30B-A3B Q4 (~17GB) | Below Ollama's MLX backend threshold (32GB). Heavy mode is thermal-bound on a fanless Air — fine for short focused sessions. |
| `mac-pro-32gb` | 32–48GB | Qwen3-Coder 30B-A3B Q4 | — | MLX backend activates (Ollama 0.19+), ~93% decode bump. Headroom for larger context. |
| `mac-heavy-64gb` | 64–96GB | Qwen3-Coder 30B-A3B Q4 | Qwen3-Coder-Next 80B MoE Q4 (~46GB) | Near-frontier local. Studio/Ultra territory. |
| `mac-max` | 128GB+ | Qwen3-Coder-Next 80B MoE Q4 | Dense 70B-class or 2-bit larger MoE | Top of what "local-only" means. |

## GPU tiers (discrete CUDA/ROCm)

| Tier | VRAM | Daily driver | Heavy mode | Notes |
|---|---|---|---|---|
| `gpu-light` | 8–12GB | Qwen3 8B Q4 | — | Fits comfortably. Tight on context above 16K. |
| `gpu-16gb` | 16GB | Qwen3-Coder 30B-A3B Q4 (partial offload to system RAM) | Qwen3 8B Q8 (speed mode, full VRAM) | MoE makes partial offload tolerable — only 3B params are active per token. |
| `gpu-24gb` | 24GB | Qwen3-Coder 30B-A3B Q4 (full VRAM) or dense 32B Q4 | — | Comfortable. Room for larger contexts. |
| `gpu-heavy` | 48GB+ | Dense 32B or larger MoE | — | Workstation/server territory. |

## CPU-only

Viable for very small models (Qwen3 1.5B or 4B). Tool calling will be unreliable. Treat as emergency fallback, not a primary setup.

## Why the split

Apple Silicon's unified memory means the model and the OS share one pool — weights fit anywhere up to ~60% of total RAM, leaving the rest for the OS, KV cache, and the harness. No VRAM partition to manage.

On a discrete GPU, weights want to live in VRAM. When they don't fit, Ollama offloads layers to system RAM — works but hurts latency. Mixture-of-Experts models (Qwen3-Coder 30B-A3B, Qwen3-Coder-Next 80B) suffer less from offload because only a small fraction of parameters is active per token.

## Memory budgeting rule

Leave ~40% of your pool (unified RAM or VRAM) free for:
- OS and other apps
- KV cache (grows with context length)
- The agent harness itself (opencode plus indexing)

A 16GB machine running a 10GB model will work for brief sessions and grind for long ones.

## Context window

- **16K** — minimum for agentic use. Below this, the system prompt alone eats too much room.
- **32K** — recommended default for 24GB+ machines.
- **64K+** — only if you're working across many files in one session and have the RAM to hold the KV cache.

## Which tier am I?

Run `./scripts/detect-tier.sh`. It reads your machine and prints a recommendation.

## When to update this file

- A better model drops — update `docs/models.md` first, then revisit the tier tables
- A machine profile gets actually verified by someone who uses it
- A claim in this file turns out to be wrong

Bump the `Last reviewed` date at the top when you touch the tables.
