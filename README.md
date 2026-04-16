# etude

Run an AI coding assistant on your own computer. No cloud, no API keys, no subscription — your code stays on your machine.

etude is a setup kit. It detects your hardware, picks models that fit, installs everything, and verifies it works. What you get is a local alternative to tools like Claude Code or GitHub Copilot — not as powerful, but free, private, and yours to run offline.

Not a replacement for frontier-grade tools. An étude is a practice piece — what you work on between performances, alone, because you want to.

## What's in the box

- **opencode** as the agent shell — MIT-licensed, TUI, tool-using
- **Ollama** as the model runtime — local, LAN-served from a beefier machine, or proxying to Ollama Cloud via the `:cloud` suffix
- A guided, five-phase install script that detects your hardware, picks sensible defaults, and shows you everything before touching anything
- A tier registry (`scripts/lib/tiers.tsv`) that's the single source of truth for model recommendations per hardware profile
- Config templates for each supported tier
- A layered smoke test you can rerun any time

## Quick start

```bash
./install.sh
```

Five phases: preflight → detect → plan → execute → smoke test. Phases 1–3 have zero side effects, so you can bail anytime up to "proceed with plan? [Y/n]". Worth a dry run first if you're curious:

```bash
./install.sh --dry-run
```

Useful flags: `--plan` (stop after Phase 3), `--tier NAME` (override detection), `--non-interactive` (accept all defaults), `--mode bare|configured` (skip the mode prompt).

Just poking at the detection logic? `./scripts/detect-tier.sh` runs it standalone.

**Prerequisites** (`install.sh` checks these in Phase 1):
- Homebrew — [brew.sh](https://brew.sh)
- `git` and Xcode Command Line Tools — `xcode-select --install` on a fresh Mac

Hardware-specific notes:
- macOS → [docs/install-macos.md](docs/install-macos.md)
- Windows → [docs/install-windows.md](docs/install-windows.md)

## Using it

After install, `cd` into any project directory and run:

```bash
opencode
```

That opens the TUI — a terminal interface where you type prompts and the agent responds. It can read and write files, run shell commands, and navigate your project. Same interaction model as Claude Code or Cursor, just running on a local model.

### Models

The installer configured opencode with your tier's recommended models. You'll see them listed when you open the TUI — pick one to start.

- **Daily** — your default. Fast enough for most work, fits comfortably in memory alongside other apps.
- **Heavy** — smarter, slower. Use it for complex tasks. On memory-constrained machines, close your browser first.

Switch models mid-session from the TUI's model picker. No restart needed.

### The `-Nk` suffix

You'll notice model names like `qwen3:8b-32k` in your config and in `ollama list`. The `-32k` suffix is a local variant that etude creates — it bakes in the right context window size so the model actually sees the full tool schema. The upstream tag (`qwen3:8b`) is still pulled too; the variant is derived from it. Don't delete the variant or swap it for the base tag in your config — tool calling will break. See [docs/models.md](docs/models.md) for why this matters.

### Headless mode

For scripting or quick one-off tasks:

```bash
opencode run "describe what this project does" -m ollama-local/qwen3:8b-32k
```

Runs the prompt, prints the response, exits. No TUI. Works in scripts, cron jobs, or piped into other commands.

### Checking health

After install, or any time something feels off:

```bash
./scripts/status.sh
```

Compares what's installed against what the registry says should be installed. Catches missing models, wrong context windows, orphan variants, stale configs.

Add `--check-updates` to also verify your base tags still exist in the ollama registry. Add `--verbose` to see raw values behind each check.

### Re-running the smoke test

```bash
./scripts/test.sh
```

Five levels: binaries → daemon → models → inference → full stack. If it passed during install and fails now, something changed on your machine.

### What to expect

These models are good, not great. They handle:

- Reading and navigating your codebase
- Writing straightforward functions and tests
- Explaining code, suggesting refactors
- File operations and shell commands via tool calling

They struggle with:

- Complex multi-step reasoning across large codebases
- Subtle bugs that need deep context to diagnose
- Tasks that frontier models handle in one shot but local models need several attempts at

When a task is clearly over the local model's head, switch to a `:cloud` model in the TUI or reach for a frontier tool. etude doesn't lock you in — same config, different model name.

## Who this is for

- You have a reasonably capable Mac or Windows PC and want a coding agent without cloud dependency
- "Smart enough for most weekend code" is fine — you're not trying to match Claude, GPT-5, or Gemini
- You want to flip to hosted models when a task needs horsepower, without rewriting your config

## Who it isn't for

- Production work where reliability matters more than cost
- Machines under 16GB RAM with no GPU — it'll run, but agentic tool calling gets unreliable fast
- Anyone who needs the polish of Claude Code

## How the three tiers stack

1. **Local** — models running on the machine you're on. Offline mood.
2. **LAN** — opencode on your laptop, Ollama on a beefier desktop on your home network. Horsepower without paying for it.
3. **Ollama Cloud** — same Ollama API, `:cloud` suffix on the model name. For the things local won't handle. Pay only when you use it.

You don't switch providers to switch tiers. Same provider block, different models. Details in [docs/hardware-tiers.md](docs/hardware-tiers.md).

## Current picks

See [docs/models.md](docs/models.md). The file is timestamped. When it's more than a few weeks stale, something in it is probably wrong — update it.

## Status

The install script, tier registry, smoke test, and agentic tool calling all work end-to-end on verified hardware. One Mac tier is fully verified — other tiers have config templates and registry entries but haven't been tested on real machines yet. Windows and LAN-serve paths are documented but unverified.

If you hit a bug, it's probably a real bug. File an issue.

## License

MIT
