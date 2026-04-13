# etude — operating document

Project: **etude** — an install kit and docs for running a Claude Code-like coding agent on open-weight models. Three tiers: local, LAN peer, Ollama Cloud.

**Status**: Early scaffold. Two machine profiles are verified by the author — MacBook Air M3 (24GB) and a desktop with Ryzen 7 5800X + RTX 5080 16GB. Other tiers are documented but unverified.

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

Nothing in the session #01 scaffold has been tested on real hardware. The following all need end-to-end verification before they can be treated as known-working:

- `install-macos.md` — full install path on the M3 Air
- `install-windows.md` — full install path on the RTX 5080 PC
- `scripts/detect-tier.sh` — actually runs and returns sane output on Mac and Linux/WSL
- `config/opencode/mac-air-24gb.json` — loads without errors, `/models` shows all entries
- `config/opencode/gpu-rtx5080-16gb.json` — same
- **LAN-serve flow** (Air → desktop Ollama) — most speculative piece of the architecture
- `ollama launch opencode --model X` — verified in research, not on real hardware

Session #02 attacks items 1, 3, 4 first (see Upcoming sessions).

---

## Work queue

### P1 (active)

**Session #02 — first verification pass.** The scaffold is entirely unverified. Next session runs it end-to-end on real hardware, starting with shell hygiene and ending with a real task through opencode on the Air. Full plan in Upcoming sessions.

### P2 (next up)

- Verify `install-windows.md` end-to-end on the 5800X / RTX 5080 box: native Ollama first, then LAN-serve mode to the Air
- Flesh out `docs/usage.md` — day-to-day patterns, mode switching, real examples (replaces the stub)
- Capture real latency numbers for the LAN-serve flow (Air → desktop)
- Write a Windows-native detection script (PowerShell) or document running the bash version under WSL
- Watch the Gemma 4 E4B tool-calling bug (Ollama 0.20.x); swap it into the chat-mode slot once fixed

### Upcoming sessions

**Session #02 — first verification pass** (confirmed at session #01 end):

1. **Shell hygiene + git init.** `chmod +x scripts/detect-tier.sh`, `git init`, first commit of the scaffold. Unblocks everything — confirms Bash tools work again after the session #01 harness CWD break.
2. **Run `detect-tier.sh` on both machines.** Mac Air should report `mac-air-24gb` with Qwen3 recommendations. PC should report `gpu-16gb` with Qwen3-Coder 30B-A3B. Fix the script if either output is wrong before moving on.
3. **Verify `install-macos.md` end-to-end on the Air.** Fresh path: confirm Ollama ≥0.20.2, `ollama pull qwen3:8b`, `ollama launch opencode --model qwen3:8b` in a real project dir, run one actual task (e.g., "write a debounce hook"). Note what breaks, note what the doc got wrong, fix the doc before ending the session.
4. **Fix the `docs/usage.md` path reference.** Remove or genericize the `~/Desktop/gemma4-setup.md` mention before any public push. Small hygiene item, easy to forget.
5. **Conditional**: if Air verification surfaces architectural issues (e.g., `ollama launch` doesn't work the way research suggested), that jumps to P1 and items #4 + Windows pass slide.

Out of scope for #02: Windows verification, writing `docs/usage.md` properly, LAN flow, Gemma 4 watch. Windows is its own session.

### Parking lot (out of scope for now)

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
