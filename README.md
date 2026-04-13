# etude

A setup kit for running a Claude Code-like coding agent on open-weight models — locally, on a LAN peer, or through Ollama Cloud. Built for weekend projects, offline sessions, and hacking that shouldn't run up an API bill.

Not a replacement for Claude Code or frontier-grade coding assistants. An étude is a practice piece — what you work on between performances, alone, because you want to.

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

Early. Scaffold + harness exist. The install script, registry, and smoke test all run end-to-end in dry mode on the author's M3 Air. First real-hardware pass (actual install, actual model pull, actual opencode invocation) is the next session's job. Other machine profiles have configs and registry entries but none are yet verified.

## License

MIT
