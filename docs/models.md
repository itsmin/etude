# Model registry

*Last reviewed: 2026-04-13*

Current picks, why they're picked, and how to swap them. Open-weight models move monthly — when this file is more than a few weeks stale, something in it is probably wrong.

## Local variant tags (`-<N>k`) and why they exist

etude does not use upstream ollama tags directly. `install.sh` pulls the base (e.g. `qwen3:8b`) and then immediately creates a local variant (e.g. `qwen3:8b-32k`) with a baked-in `num_ctx` parameter. Templates, sidecars, and smoke tests all reference the variant, not the base.

The reason: ollama loads every model with `num_ctx = 4096` by default, regardless of what the model's maximum context supports. opencode's `provider.models.X.limit.context` config is send-side only — it caps how much opencode is willing to send, but doesn't override ollama's receive-side window. At 4K, opencode's tool-definition prompts (agent system prompt + full tool schema + user message) get truncated before the model ever sees the tool list. The model then confabulates plausible-but-wrong tool names from training memory, which is exactly the failure mode session #03 observed with both `qwen3:8b` and `qwen3-coder:30b`.

The fix is a local model variant with `PARAMETER num_ctx <N>` set at create time. The variant loads at the intended context on every call.

The recipe (what `install.sh` runs for you):

```sh
printf 'FROM qwen3:8b\nPARAMETER num_ctx 32768\n' \
  | ollama create qwen3:8b-32k -f /dev/stdin
```

Naming convention: `<base>-<ctx/1024>k`, e.g. `qwen3:8b-32k`, `qwen3-coder:30b-64k`, `qwen3-coder-next:80b-128k`. Per-tier context values live in `scripts/lib/tiers.tsv`.

Session #04 (2026-04-13) verified this fix end-to-end against `qwen3:8b-32k` and `qwen3-coder:30b-32k` on the M3 Air: both models tool-call cleanly through opencode at the variant tag, with the same prompts that failed through the base tag in session #03.

## Current picks

### Agentic coding (tool calling) — primary

**Qwen3 8B** — base tag `qwen3:8b`, variant `qwen3:8b-16k` (mac-light) or `qwen3:8b-32k` (everywhere else)
- ~5.2GB at Q4, 30–50 tok/s on Apple Silicon
- Apache 2.0
- Tool calling through Ollama + opencode: **reliable** through the variant tag. Fails through the base tag — see the num_ctx section above.
- Use for: opencode daily driver on 16–24GB Macs

**Qwen3-Coder 30B** — base tag `qwen3-coder:30b`, variant `qwen3-coder:30b-32k` or `qwen3-coder:30b-64k` (per tier)
- ~19GB at Q4. MoE: 30B total, ~3.3B active per token. 6+ tok/s even under partial offload.
- Note: session #01 registered this as `qwen3-coder:30b-a3b` based on the Qwen naming convention; ollama's library uses `qwen3-coder:30b` as the canonical tag and the `-a3b` variant doesn't exist as a separately published tag. Caught and fixed in session #03 by a real `ollama pull` failure.
- Apache 2.0
- Tool calling: **reliable** through the variant tag (same num_ctx story as qwen3:8b).
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
2. **Create the variant.** `printf 'FROM <new-model>\nPARAMETER num_ctx <N>\n' | ollama create <new-model>-<N/1024>k -f /dev/stdin` — pick `<N>` to match your tier's context budget in `tiers.tsv`. Skip this and you will hit the session-#03 confabulation bug.
3. **Bare test.** `ollama run <new-model>-<N/1024>k`. Ask it to output JSON or describe a tool call. See if it's sane before anything fancier.
4. **opencode test.** Add to your `opencode.json` provider block (use the variant tag, not the base). Select with `/models`. Run a real task — not a benchmark, something from an actual weekend project. Verify it actually invokes tools, doesn't just describe them.
5. If it works, update this file and `scripts/lib/tiers.tsv` and bump `Last reviewed`.
6. If it's meaningfully better for its tier, update `docs/hardware-tiers.md` too.

## How to evaluate a candidate

- **Does it do tool calling through Ollama?** Not all models do — and some that claim to have parser bugs in specific Ollama versions. Test this first, not last.
- **Does it fit your tier?** Check the memory math in `docs/hardware-tiers.md`.
- **Permissive license?** Apache 2.0, MIT, or similar. Avoid anything with commercial-use restrictions if you're planning to ship games or share with others.
- **Is it actually better than what's here?** Benchmarks lie. Your actual use case is the only real test. Run a real task.

## Deprecated / tried and dropped

*(none yet — add a one-liner on why when something gets replaced)*
