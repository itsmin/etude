# etude — operating document

Project: **etude** — an install kit and docs for running a Claude Code-like coding agent on open-weight models. Three tiers: local, LAN peer, Ollama Cloud.

**Status**: Harness verified end-to-end on the M3 Air. First real install complete in configured mode (qwen3:8b pulled, opencode 1.4.3 installed), all 5 smoke-test levels pass including Level 5 (opencode → ollama-local/qwen3:8b). Session #03 produced an architectural pivot: macOS install now routes through the Ollama.app cask (not the brew formula) and defaults to configured mode (not bare). Next up — second-machine verification on the M1 Air 16GB (mac-light tier, fresh cask install). Other tiers still unverified.

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

- **macOS install path is Ollama.app cask, not brew formula.** The brew formula (`brew install ollama`) lags the Ollama.app and may ship without the `launch` subcommand; on a machine with both installed, the formula's old client typically intercepts calls to the newer server. `install.sh` Phase 1 refuses to proceed if it detects either condition (multi-binary PATH conflict, client/server mismatch warning, or missing `launch`). The fix is always `brew uninstall ollama`; Ollama.app survives.
- **Bare vs configured is interactive-vs-scriptable, not light-vs-full.** Bare mode relies on `ollama launch opencode` which needs a TTY. Configured mode writes `opencode.json` with an `ollama-local` provider (via `@ai-sdk/openai-compatible` → `localhost:11434/v1`) and works both in the opencode TUI and in `opencode run` headless mode. Configured is the default; bare is an opt-in for users who really don't want a config file.

---

## Session workflow

- **Start**: `/session-start` (Overture skill) — reads this doc, then runs the project-specific checks below.
- **End**: `/session-end` (Overture skill) — drafts session entry from context, verifies features by evidence, updates the work queue. Always gets confirmation before writing the Next pointer.
- **Session entries**: max 8 lines, condensed format. No prose summaries.

### Project health checks (session-start, Step 2)

Run these and report — don't auto-fix. Present as "found these, here's what it means."

- `ollama --version` — is it 0.20.2+?
- `ollama list` — are the expected models pulled (qwen3:8b, qwen3-coder:30b)?
- `opencode --version` — is the harness available?

### Documentation sync checklist (session-end, Step 5)

If this session touched any of these, the matching follow-up applies:

- `docs/hardware-tiers.md` or `docs/models.md` → does the `Last reviewed` date need bumping?
- `config/opencode/*.json` → do all documented tiers still have a matching template?
- `scripts/detect-tier.sh` or `scripts/lib/tiers.*` → does it still handle all registered tiers?
- `scripts/install.sh` or `scripts/test.sh` → has the change been exercised at least in dry mode?
- `README.md` → is the quick start still accurate?
- `docs/install-*.md` → have the steps actually been verified on a real machine, or is the prose drifting ahead of the harness again?

---

## Pending verifications

Session #03 verified the full harness end-to-end on the M3 Air. Most session-#02 items are now real.

Verified in session #03 (M3 Air, real run):
- `install.sh` Phase 1 sanity detection — fires correctly on a broken state (brew formula 0.12.0 + Ollama.app 0.20.5 coexisting), passes cleanly after `brew uninstall ollama`.
- `install.sh` Phase 3 dep detection — reports "Ollama.app <ver> (already installed)" based on the Phase-1-validated binary.
- `install.sh` Phase 4 opencode install — `curl | bash` via `opencode.ai/install` lands the binary at `~/.opencode/bin/opencode` and appends PATH to `~/.zshrc`. Phase 4 now propagates PATH into the current process so Phase 5 sees opencode.
- `install.sh` Phase 4 `ollama pull qwen3:8b` — works, idempotent (second run re-verifies manifest, no re-download).
- `install.sh` Phase 4 configured-mode opencode.json write — handles existing-file case (default backup+write; leaves `opencode.json.bak.<timestamp>` behind).
- `install.sh` Phase 4 sidecar write — new build layout doesn't leave a blank line inside `ETUDE_MODELS` when heavy is empty.
- `install.sh` Phase 5 → `test.sh` — all 5 levels pass end-to-end in configured mode.
- `test.sh` Level 5 — `opencode run` against `ollama-local/qwen3:8b` with a marker prompt; qwen3:8b returns the marker in the completion text.
- Real artifacts on disk: `~/.opencode/bin/opencode` (1.4.3), `~/.config/opencode/opencode.json` (from `config/opencode/mac-air-24gb.json`), `~/.config/etude/install.sh` (sidecar, mode=configured).

Still unverified:
- **Fresh `brew install --cask ollama` branch of Phase 4.** Session #03 couldn't exercise it — Ollama.app was already on the M3 Air (downloaded directly, not via cask). First machine without Ollama.app is the target.
- **Daemon auto-start after a fresh cask install.** Currently `open -a Ollama` with `sleep 2` retry, untested against a cold machine.
- **All tiers other than mac-air-24gb.** `mac-light`, `mac-pro-32gb`, `mac-heavy-64gb`, `mac-max`, and every `gpu-*` tier are still registry entries + config templates without a real run.
- **`install-windows.md`** — entire Windows path, entirely unverified.
- **LAN-serve flow** (Air → desktop Ollama, or vice versa).
- **Ollama Cloud auth / `:cloud` model pull** — see open threads.
- **`install-macos.md` prose** — deferred from session #03, needs a full rewrite to match the harness (currently documents the old brew-formula path).

New in-session-#03 finding that's still open:
- **qwen3:8b tool-calling is not usable via opencode.** Level 5 smoke test (text generation) passes cleanly. Everything else fails. Evidence from three tests:
  - Headless `opencode run` with "write a debounce.ts file" — 1m45s wall, no file written, no visible response.
  - Interactive TUI with "use the write tool to create ./hello.txt" (README didn't exist at this point) — called `read` with `filePath: undefined`, got the schema error back, then produced a long "Thinking:" monologue telling *the user* how to format a tool call in JSON. Role-confused, never retried.
  - Interactive TUI with a real README in place — 4m41s of circular "Wait, let me check the tools again... the functions available are Edit, Write, Search, Todo, Skill... there's no Read function..." monologue. Enumerated the tool list from confabulation, missed the actual `Read` tool opencode provided (Big Pickle called it correctly in 8 seconds in the same opencode, same agent). Never invoked any tool. 6,100+ tokens of internal debate, no progress.
- Big Pickle (OpenCode Zen cloud) was the control: correct tool invocation, multi-step recovery, 8 seconds. The bug is the model, not opencode's Build agent or the tool schema.
- qwen3-coder:30b is the natural next comparison. If it works, the mac-air-24gb tier's *daily* pick is wrong (should be heavy-as-daily) and the *heavy* pick is fine. If it also fails, the entire mac-air-24gb tier needs a model pivot or etude pivots toward a configured-mode cloud-first story for that tier.

---

## Work queue

### P1 (active)

**Session #04 — M1 Air 16GB first install.** First session against a genuinely fresh machine — Ollama.app not installed, opencode not installed, brew present. Exercises the `brew install --cask ollama` branch of Phase 4 that session #03 couldn't test (M3 Air already had Ollama.app). Tests the `mac-light` tier for the first time. Validates the harness generalizes across Mac variants. Full plan below.

### P2 (next up)

- Session #05: first real-hardware run on the RTX 5080 PC (gpu-16gb tier, Windows install path)
- Rewrite `docs/install-macos.md` to match the harness — delete the speculative brew-formula prose, replace with "run `./install.sh`, here's what it does, here's what to watch for." Deferred from session #03. Should happen after session #04 confirms the harness across two Macs.
- Build `scripts/status.sh` — read-only audit tool. Reads sidecar + TSV + `ollama list` + `ollama show`, reports drift between intended and actual state. Complements `test.sh` (test is functional, status is inventory). Session #03 produced the first real sidecar, so this is now buildable.
- Build `install.sh --refresh` mode — detect existing sidecar at startup, compare to current TSV, offer to pull delta and rewrite config. Same entry point, different mode.
- `status.sh --check-updates` — single network call to fetch origin `tiers.tsv` and diff against local. Opt-in, not in `install.sh`. Build alongside `status.sh`.
- **Tool-calling comparison across models.** Session #03's finding: qwen3:8b can't reliably invoke tools via opencode at all. First test: called `read` with `filePath: undefined`. Retest with a file that actually existed: 4+ minutes of "Wait... let me check the tools again..." monologue, model claimed the `read` function didn't exist in its toolset (it does), never invoked any tool. qwen3-coder:30b is the natural next comparison — heavier model, coder-tuned, might parse the tool schema correctly. Queue for session #04 opening if session #03 didn't get to it.
- Flesh out `docs/usage.md` — day-to-day patterns, mode switching, real examples
- Capture real latency numbers for the LAN-serve flow (Air → desktop)
- Rewrite `install-windows.md` alongside the PC session
- Watch the Gemma 4 E4B tool-calling bug; flip its `reliability` from `watching` to `good` in `tiers.tsv` once fixed upstream

### Upcoming sessions

**Session #04 — M1 Air 16GB first install**

1. **Verify starting state.** Confirm M1 Air has: no Ollama.app, no opencode, brew present, disk has ≥10GB free. Run the project-specific health check (Project health checks subsection above). Document baseline.
2. **Run `./install.sh --plan`** interactively. Walk every prompt. Tier should auto-detect as `mac-light`. Mode default should be `configured`. Note anything confusing — the M1 Air user is a fresh reader of the new harness, not someone who's been hacking on it for a session.
3. **Run `./install.sh`** for real. This is the first session that exercises the full "install Ollama.app from nothing" branch — `brew install --cask ollama` will actually run. Watch for: whether brew prompts for sudo on /Applications writes, how Phase 4's `open -a Ollama` behaves on a cold install (macOS may show the "are you sure you want to open this app from the internet" dialog on first launch), and whether daemon auto-start works or needs human intervention.
4. **Run `./scripts/test.sh`** — Levels 1–5 should pass. If any fail, fix before moving on.
5. **Tool-calling spot-check.** Repeat the session #03 "write a file" test with `mac-light`'s daily model (first check `scripts/lib/tiers.tsv` for what that is — may be `qwen3:4b`). Compare to the session #03 qwen3:8b observation. A smaller model failing is expected and informative; a smaller model succeeding is surprising and informative.
6. **Commit in logical chunks** as you go.

Out of scope for #04: PC/Windows, install-macos.md rewrite, status.sh, Ollama Cloud, LAN flow.

**Conditional branches**:
- If `brew install --cask ollama` requires sudo interactively → document, consider whether `install.sh` can detect and warn upfront.
- If the M1 Air thrashes during qwen3:4b inference → mac-light's daily pick may be wrong; adjust `tiers.tsv`.
- If Level 5 fails against mac-light's daily → that tier may be unviable for headless use; note in registry and adjust expectations, don't chase the model.
- If everything works cleanly on the first run → great signal that the session #03 architectural changes generalize; accelerate session #05 planning.

### Parking lot (out of scope for now)

- **Dedicated watchlist file** separate from the TSV's `reliability=watching` column. The column handles v1 fine; a separate file only earns its place once there are more than 1–2 tracked entries and we want richer metadata per entry (source URL, trigger condition, last-checked date). Revisit when that happens.
- Linux-native install guide (generalizable from Windows section but not verified)
- vLLM path for the PC (faster throughput, more setup)
- Custom per-project opencode modes or system prompts
- "Sync models across machines" helper
- Fine-tuning workflow

### Open threads (carry forward)

- **qwen3:8b + opencode: not viable for agentic use, confirmed.** Session #03 observation (see Pending verifications above for the full three-test trace). Plumbing works; the model either can't parse opencode's tool schema, confabulates a different schema from memory, or gets stuck in circular "Wait..." loops trying to figure out whether a tool exists. Big Pickle control test in the same opencode install worked in 8 seconds. The bug is the model. Implication for `tiers.tsv`: if qwen3-coder:30b also fails when session #04 tests it, the `mac-air-24gb` daily pick is fundamentally wrong and needs to change — potentially no local-only option exists for the tier. Worth inspecting whether ollama's OpenAI-compatible tool-call translation might be the real culprit (vs. the model itself) as part of the investigation.
- **Ollama Cloud auth / pricing mechanics.** Still not explored. Sign-up flow, key storage, current `:cloud` model catalogue all still unknown. Parked until a session needs it.
- **Windows install doc ordering.** The doc currently defaults to fully-native Windows with WSL2 as the advanced path. Since the PC doubles as a LAN inference server, WSL2-for-opencode + native-Ollama may be the better anchor. Revisit when verifying `install-windows.md`.
- **Registry tag validation.** Session #03 caught `qwen3-coder:30b-a3b` in `tiers.tsv` as a tag that doesn't exist on ollama.com — the real tag is `qwen3-coder:30b`. Only caught because we did a real pull. `status.sh --check-updates` (P2) should probably also do a "does every registered tag still resolve?" sanity check; `install.sh` Phase 1 could do the same on the tags it's about to pull, before committing to a plan.

### Deferred (in scope, bumped)

*(none yet)*

### Complete (recent)

### Session #03 — First real install + architectural pivot (2026-04-13)
- **Architectural pivot: macOS install path from brew formula to Ollama.app cask.** Real hardware surfaced three failure modes the dry-run harness never saw: multi-binary PATH conflict (brew formula 0.12.0 + Ollama.app 0.20.5 coexisting on the same machine), silent false-positive version parser (server version extracted from a client/server mismatch warning), and brew formula lacks the `launch` subcommand required for bare mode. Phase 1 now refuses to proceed on any of these with specific remediation. Phase 4 uses `brew install --cask ollama` when needed.
- **Architectural pivot: mode default from bare to configured.** Session #03 established that bare mode only works interactively — `ollama launch opencode` needs a TTY, and `opencode run` (headless) requires a provider in `opencode.json` that bare mode doesn't write. Configured is now the default; bare stays available as an opt-in for users who really don't want a config file. Implication recorded in Critical reminders.
- **Wired test.sh Level 5.** `opencode run` against `ollama-local/<daily-tag>` with a unique marker prompt; passes if the response contains the marker. Skips with explanation in bare mode. Verified passing on M3 Air with qwen3:8b.
- **Smaller fixes:** picker default for optional roles is now "skip" not "pick first" (makes `--non-interactive` usable for minimal installs); sidecar build no longer leaves a blank line inside `ETUDE_MODELS`; Phase 4 propagates `~/.opencode/bin` into the current process PATH so Phase 5's test.sh sees opencode.
- **Verified end-to-end** on M3 Air: install.sh full path, all 5 smoke test levels pass, `opencode run → ollama-local/qwen3:8b → text response` confirmed.
- **Finding (confirmed, not just "unreliable"):** qwen3:8b via opencode is **not usable for agentic work.** Three tests, each worse than the last: (1) headless `opencode run "write a debounce file"` — 1m45s wall, no file written, no visible response. (2) Interactive TUI with "use the write tool to create ./hello.txt" — model called `read` with `filePath: undefined`, got the schema error, then wrote a long monologue telling *the user* how to format tool calls in JSON (role flip, no retry). (3) Interactive TUI with a real README in place — 4m41s of circular "Wait, let me check the tools again..." monologue. The model enumerated the tool list from confabulation ("Edit, Write, Search, Todo, Skill") and concluded `Read` didn't exist, while Big Pickle in the same opencode install called `Read` correctly in 8 seconds as a control. The bug is the model, not opencode or the tool schema.
- **Registry bug caught by dogfooding.** `tiers.tsv` registered `qwen3-coder:30b-a3b` as the heavy tag for 5 tiers, but ollama's library only publishes `qwen3-coder:30b`. Session #01's naming-convention guess was wrong; nobody noticed until the first real pull. Fixed across `tiers.tsv`, 6 `config/opencode/*.json` templates, `docs/models.md`, `docs/install-macos.md`, `docs/install-windows.md`, and this doc. Also corrected the size: it's ~19GB, not ~17GB. Caught explicit "verify claims before recommending" collab rule doing its job. Added as an open thread — registry tag validation belongs in `status.sh --check-updates` and possibly `install.sh` Phase 1.
- **Disk cleanup:** removed `gpt-oss:20b` (13GB, unused for 7 months) to make room for the heavy-model pull. Resolved the "stale model" open thread.
- **Deferred from #03:** `docs/install-macos.md` rewrite. The prose is 133 lines of outdated brew-formula speculation and needs a careful rework, not rushed. Only the tag references were patched this session; structural rewrite is P2.
- **Not tested:** the fresh `brew install --cask ollama` branch of Phase 4 — M3 Air already had Ollama.app from a direct download. First genuinely-fresh-machine session is the target for that.
- **Heavy model (qwen3-coder:30b) comparison:** pull was running against the fixed tag as session #03 wound down. Whether it closed the tool-calling gap or reproduced the same failure is the decisive question for the mac-air-24gb tier's viability; resolved in session #04 opener.

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
