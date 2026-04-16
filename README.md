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
