# Model registry

*Last reviewed: 2026-04-12*

Current picks, why they're picked, and how to swap them. Open-weight models move monthly — when this file is more than a few weeks stale, something in it is probably wrong.

## Current picks

### Agentic coding (tool calling) — primary

**Qwen3 8B** (`qwen3:8b`)
- ~5.2GB at Q4, 30–50 tok/s on Apple Silicon
- Apache 2.0
- Tool calling through Ollama + opencode: **reliable**
- Use for: opencode daily driver on 16–24GB Macs

**Qwen3-Coder 30B** (`qwen3-coder:30b`)
- ~19GB at Q4. MoE: 30B total, ~3.3B active per token. 6+ tok/s even under partial offload.
- Note: session #01 registered this as `qwen3-coder:30b-a3b` based on the Qwen naming convention; ollama's library uses `qwen3-coder:30b` as the canonical tag and the `-a3b` variant doesn't exist as a separately published tag. Caught and fixed in session #03 by a real `ollama pull` failure.
- Apache 2.0
- Tool calling: **reliable**
- Use for: heavy mode on 24GB Macs, daily driver on 32GB+ Macs or 16GB+ VRAM GPUs
- Benchmarks ahead of dense 32B while being faster

### Interactive chat / code generation — non-agentic

**Gemma 4 E4B** (`gemma4:e4b`)
- ~5.6GB at Q4, ~57 tok/s
- Apache 2.0
- Released April 2, 2026
- Tool calling through Ollama + opencode: **broken as of April 2026** — known bug in Ollama 0.20.0's tool parser. Fix in progress upstream.
- Use for: `ollama run gemma4:e4b` interactive chat, `continue.dev` inline assistance, REST API scripting
- **Swap-in candidate** for the primary agentic slot once the tool-calling bug is fixed — benchmarks above models much larger than itself

### Hosted (Ollama Cloud, `:cloud` suffix)

These run through your local or LAN Ollama instance but proxy to ollama.com. Use them when local isn't enough.

- `qwen3-coder:cloud` — larger Qwen3-Coder variants. Check ollama.com for current sizes.
- `glm-5:cloud` — GLM-5. Top of LiveBench Agentic Coding for open source as of early 2026 (~55 on Agentic, 73.6 on Coding Average).
- `kimi-k2.5:cloud` — Kimi K2.5. 76.8% SWE-bench Verified, 99% HumanEval.
- `deepseek-v3.2:cloud` — DeepSeek V3.2. Thinking integrated with tool use.

Check [ollama.com/cloud](https://ollama.com/cloud) for the current hosted catalog — it changes.

## How to swap a model

When a better one drops:

1. `ollama pull <new-model>`
2. **Bare test.** `ollama run <new-model>`. Ask it to output JSON or describe a tool call. See if it's sane before anything fancier.
3. **opencode test.** Add to your `opencode.json` provider block (or use `ollama launch opencode --model <new-model>`). Select with `/models`. Run a real task — not a benchmark, something from an actual weekend project.
4. If it works, update this file and bump `Last reviewed`.
5. If it's meaningfully better for its tier, update `docs/hardware-tiers.md` too.

## How to evaluate a candidate

- **Does it do tool calling through Ollama?** Not all models do — and some that claim to have parser bugs in specific Ollama versions. Test this first, not last.
- **Does it fit your tier?** Check the memory math in `docs/hardware-tiers.md`.
- **Permissive license?** Apache 2.0, MIT, or similar. Avoid anything with commercial-use restrictions if you're planning to ship games or share with others.
- **Is it actually better than what's here?** Benchmarks lie. Your actual use case is the only real test. Run a real task.

## Deprecated / tried and dropped

*(none yet — add a one-liner on why when something gets replaced)*
