# etude — operating document

Project: **etude** — an install kit and docs for running a Claude Code-like coding agent on open-weight models. Three tiers: local, LAN peer, Ollama Cloud.

**Status**: Scaffold + install harness. `install.sh` runs end-to-end in dry mode on the author's M3 Air. Nothing has been installed against real hardware yet — session #03 is the first real run. Two machine profiles are the author's primary targets — MacBook Air M3 (24GB) and a desktop with Ryzen 7 5800X + RTX 5080 16GB. Other tiers have registry entries and config templates but are all unverified.

---

## Collaboration guidelines

- **Partnership, not implementation.** Push back on architecture, model picks, UX choices, and naming. The best ideas come from tension — don't just execute.
- **Voice.** Direct, matter-of-fact. Em dashes over parentheses. Short sentences for punch. No thought-leader framing, no performative enthusiasm. Honest about gaps — "this doesn't work yet" beats "further investigation is recommended."
- **Impact radius.** When modifying any of: tier tables, the model registry (`docs/models.md`), install scripts, or opencode config templates — check: (a) does the change still hold for all documented tiers, not just the two verified machines; (b) is it backward-compatible for users who already ran an install; (c) does the `Last reviewed` date in the touched file need bumping.
- **Source of truth hierarchy.** Scripts and config files > `docs/` > `README.md` > this operating doc. When they disagree, code wins.
- **Model picks are tiered opinions, not dogma.** Easy to re-point: edit the tables, don't rewrite the prose.
- **Don't chase polish.** This is a weekend tool. Quick-and-honest beats engineered-and-speculative.
- **Verify claims before recommending them.** The open-weight landscape moves fast — a model or flag that worked last month may not work this month. When documenting something new, cite where you verified it.

---

## Critical reminders

*(none yet)*

---

## Session workflow

- **Start**: `/session-start` — reads this doc, health-checks `ollama` + `opencode` if present, surfaces the Next pointer.
- **End**: `/session-end` — drafts session entry from context, verifies features by evidence, updates the work queue. Always gets confirmation before writing the Next pointer.
- **Session entries**: max 8 lines, condensed format. No prose summaries.

---

## Pending verifications

Session #02 shifted from "verify prose" to "build harness." The harness (`install.sh`, `scripts/lib/tiers.*`, `scripts/test.sh`) replaces the prose as the thing to verify, and it's been exercised in dry mode on the M3 Air but has not yet installed anything.

Partial (verified in-session on the M3 Air in dry mode):
- `scripts/detect-tier.sh` — all three modes (`--tier-only`, `--json`, human) return correct output for this machine
- `scripts/lib/tiers.sh` — registry parsing, consistency check, installable check all work
- `install.sh` Phase 1 preflight — correctly validates registry, deps, homebrew, write perms, network
- `install.sh` Phase 2 detection + Phase 3 picker + plan + disk check — full path works, non-interactive mode clean
- `install.sh` Phase 4 execute + Phase 5 smoke test — dry-run path works, side-effecting commands NOT executed
- `scripts/test.sh` Levels 1–2 — partial real verification: ollama 0.20.5 detected, version check passes, daemon check ready

Still fully unverified (needs real-hardware session #03):
- Actual `brew install ollama` + daemon start on a machine that doesn't already have it
- Actual `curl -fsSL https://opencode.ai/install | bash` — does opencode land on PATH?
- Actual `ollama pull` against the picked models
- Actual opencode startup with a written config
- `ollama launch opencode --model X` — the "bare mode" happy path
- `test.sh` Levels 3–5 (sidecar read, inference check, opencode one-shot stub)
- All tiers other than `mac-air-24gb` — everything else is registry entry + config template without a real run
- `install-windows.md` — entire Windows path
- LAN-serve flow (Air → desktop Ollama)

The install-doc prose (`install-macos.md`, `install-windows.md`) is now **behind** the install script. Session #03 will rewrite the prose to match what actually happens during the real run, not what session #01 speculated.

---

## Work queue

### P1 (active)

**Session #03 — first real-hardware run (M3 Air).** The harness exists and passes dry-mode checks. Now actually run it against this M3 Air with nothing pre-installed — or with opencode pre-installed to test that path. Walk through the flow, note every moment the script got something wrong, fix the script. End with opencode running a real task against a locally-pulled qwen3:8b. Full plan below.

### P2 (next up)

- Session #04: first real-hardware run on the M1 Air 16GB (second machine, mac-light tier, validates that the architecture generalizes across machines)
- Session #05: first real-hardware run on the RTX 5080 PC (gpu-16gb tier, Windows install path)
- Wire up `test.sh` Level 5 (opencode one-shot) after the M3 run confirms opencode's non-interactive CLI
- Build `scripts/status.sh` — read-only audit tool. Reads sidecar + TSV + `ollama list` + `ollama show`, reports drift between intended and actual state. Complements `test.sh` (test is functional, status is inventory). Depends on session #03 having written a real sidecar.
- Build `install.sh --refresh` mode — detect existing sidecar at startup, compare to current TSV, offer to pull delta and rewrite config. Same entry point, different mode. Depends on session #03 having produced the first real sidecar.
- `status.sh --check-updates` — single network call to fetch origin `tiers.tsv` and diff against local. Opt-in, not in `install.sh`. Build alongside `status.sh`.
- Flesh out `docs/usage.md` — day-to-day patterns, mode switching, real examples
- Capture real latency numbers for the LAN-serve flow (Air → desktop)
- Rewrite `install-macos.md` and `install-windows.md` to match what the harness actually does; add source-of-truth pointers in `hardware-tiers.md` and `models.md` that direct readers to `scripts/lib/tiers.tsv`
- Watch the Gemma 4 E4B tool-calling bug; flip its `reliability` from `watching` to `good` in `tiers.tsv` once fixed upstream

### Upcoming sessions

**Session #03 — first real-hardware run on the M3 Air**:

1. **Decide starting state.** Either uninstall opencode first for a "truly fresh" test, or run `./install.sh` against the current state (ollama 0.20.5 present, opencode missing) and accept that the "fresh ollama install" branch stays unverified for now. Lean toward the second — faster, still exercises the interesting parts.
2. **Run `./install.sh --plan`** and walk through it interactively. Every prompt, every default. Note anything confusing.
3. **Run `./install.sh` for real** in bare mode, picking qwen3:8b only (skip heavy to keep it fast). Watch every step. First real test of: `brew install ollama` (already installed, so skip check), `curl | bash` for opencode + PATH handling, `ollama pull qwen3:8b`, sidecar write.
4. **Run `./scripts/test.sh`** against the fresh install. Levels 1–4 should all pass. Note anything that surprises you.
5. **Run the actual happy path.** `cd` into some real project, `ollama launch opencode --model qwen3:8b`, give it a real task (e.g. "write a debounce hook with tests"). Observe: does it work? Does tool calling reliably land? What's the latency? Capture anything worth noting.
6. **Wire up `test.sh` Level 5.** Based on what you learned about opencode's CLI, implement the one-shot file-write test. Run the full test suite end-to-end.
7. **Rewrite `install-macos.md`** to match what actually happened. The old prose is now stale — replace with "run `./install.sh`, here's what to expect, here are the moments to watch for."
8. **Commit in logical chunks** as you go. Don't batch everything into one commit.

Out of scope for #03: M1 Air run, Windows, LAN flow, `status.sh`, Ollama Cloud auth. Keep session scoped to "one machine, one run, fix what's wrong."

**Conditional branches**:
- If `ollama launch opencode` doesn't work as researched, `bare` mode is broken and we fall back to `configured` mode as the sole happy path. That's a real architectural change — update the installer.
- If opencode's curl-bash doesn't land it on PATH cleanly, Phase 4 needs a post-install PATH check and a shell-rc edit (or instruction).
- If `test.sh` Level 4 inference is slower than ~15s, bump the timeout expectation or use a smaller test prompt.

### Parking lot (out of scope for now)

- **Dedicated watchlist file** separate from the TSV's `reliability=watching` column. The column handles v1 fine; a separate file only earns its place once there are more than 1–2 tracked entries and we want richer metadata per entry (source URL, trigger condition, last-checked date). Revisit when that happens.
- Linux-native install guide (generalizable from Windows section but not verified)
- vLLM path for the PC (faster throughput, more setup)
- Custom per-project opencode modes or system prompts
- "Sync models across machines" helper
- Fine-tuning workflow

### Open threads (carry forward)

- **Ollama Cloud auth / pricing mechanics.** Not yet explored — sign up flow, key storage, which `:cloud` models are currently hosted. Decide whether to resolve in a real session (actually pull a `:cloud` model) or park until needed.
- **Windows install doc ordering.** The doc currently defaults to fully-native Windows with WSL2 as the advanced path. Since the PC doubles as a LAN inference server, WSL2-for-opencode + native-Ollama may be the better anchor. Revisit when verifying `install-windows.md`.

### Deferred (in scope, bumped)

*(none yet)*

### Complete (recent)

### Session #02 — Install harness (2026-04-12)
- Architectural pivot: etude was "recipe book + detection script," now it's "guided installer with a single source of truth." Driven by end-user walkthrough — there was no install mechanism, just prose.
- Built `scripts/lib/tiers.tsv` (pipe-delimited registry, one row per tier/model) + `scripts/lib/tiers.sh` (parse, filter, consistency check, installable check). Tier facts now live in exactly one place.
- Refactored `detect-tier.sh` to read from the registry; added `--tier-only` and `--json` output modes for scripting.
- Wrote `install.sh` — five-phase guided installer (preflight → detect → plan → execute → smoke test). Phases 1–3 are side-effect-free; Phase 3 ends with a plan-confirm gate before any writes. Flags: `--dry-run`, `--plan`, `--tier`, `--mode`, `--non-interactive`.
- Wrote `scripts/test.sh` — layered smoke test, five levels, exit code = failing level. Levels 1–4 real, Level 5 stubbed pending real-hardware opencode CLI verification.
- Added config templates for all registered tiers (mac-light, mac-pro-32gb, mac-heavy-64gb, mac-max, gpu-light, gpu-24gb, gpu-heavy); renamed `gpu-rtx5080-16gb.json → gpu-16gb.json` to match tier naming.
- git init + commits; fixed the `~/Desktop/gemma4-setup.md` path leak in `usage.md`; updated README to make `./install.sh` the entry point.
- **Partial verification on the M3 Air in-session**: detect-tier (all 3 modes), registry consistency, install.sh dry-run end-to-end for mac-air-24gb and mac-light, test.sh Levels 1–2 against real ollama 0.20.5. **No actual brew install / pull / opencode invocation** — that's session #03.
- **Caught live**: disk-tight case on the 24GB Air — 25GB free vs 22.2GB pull = correct warning + abort. The preflight architecture does its job.

### Session #01 — Scaffold (2026-04-12)
- Designed etude: portable setup kit for open-weight coding agents, offline-first with LAN + Ollama Cloud escape hatches. Anchored on opencode + Ollama after research.
- Verified April 2026 landscape: `anomalyco/opencode`, `ollama launch` subcommand, Anthropic opencode block (Jan 9), Ollama Cloud `:cloud` proxy architecture, Gemma 4 E4B tool-calling still broken in 0.20.x
- Renamed `encode → etude` — Tom Christie's `encode` org collides the namespace
- Scaffolded 13 files: README, CLAUDE.md, 5 docs, 2 opencode configs, `detect-tier.sh`, 2 session commands
- **Unverified**: nothing tested on real hardware — entire scaffold is pending
- **Blocked at end**: Bash/Grep broke when directory was renamed mid-session (harness CWD pinned to old path); `git init` + `chmod` deferred to #02

---

## Hardware profiles the author uses

| Machine | Profile | Daily driver | Heavy mode |
|---|---|---|---|
| MacBook Air M3, 24GB unified | `mac-air-24gb` | Qwen3 8B Q4 | Qwen3-Coder 30B-A3B Q4 (focused sessions, close the browser) |
| Desktop: Ryzen 7 5800X, 32GB, RTX 5080 16GB VRAM | `gpu-16gb` | Qwen3-Coder 30B-A3B Q4 (partial offload) | Qwen3 8B Q8 (speed mode, full VRAM) |

Both machines also serve as Ollama endpoints for each other when on the home LAN.

---

<!--
## Optional sections — uncomment as the project grows

## Metrics
Tracked when there's something to track: stars, verified tiers, install reports.

## Development workflow
How to verify a config change, how to test on both machines, how releases work (if ever).

## Documentation reference
Map of `docs/` and which file is authoritative for which topic.

## Privacy boundaries
None currently. Declare here if any surface handles PII.

## Session archives
Size management: GREEN <30k characters, YELLOW 30–35k, RED >35k. Archive to `sessions/` when RED.
-->
