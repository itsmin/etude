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

- **`tiers.tsv` is unverified for agentic use as of session #03 close.** All Qwen rows are registered `reliability = good` but session #03 observed qwen3:8b and qwen3-coder:30b both fail to tool-call via opencode. **Post-session research (same night) surfaced a likely root cause: ollama's `num_ctx` defaults to 4096 regardless of what `opencode.json` sets as the context limit**, because opencode's `provider.models.X.limit.context` controls the send-side prompt size, not the model's receive-side context window. A 4K context gets the agent system prompt + tool schemas truncated, leaving Qwen to confabulate a tool list from training memory — exactly the observed failure pattern (qwen3:8b "no Read function," qwen3-coder inventing `Skill "read_file"`). This is a **configuration bug, not a model capability bug.** Session #04 P1 tests the theory before pivoting to alternative models. Until session #04 validates the fix: install.sh still installs, Level 5 smoke test still passes, but agentic use in the opencode Build agent is unreliable.
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

**Session #04 — Registry reliability audit + working-model hunt.** Session #03 closed with a decisive finding: both Qwen models we tested (qwen3:8b, qwen3-coder:30b) fail to tool-call via opencode through ollama, in distinct-but-equivalently-broken ways (neither reads opencode's actual tool schema; both confabulate). Big Pickle cloud worked cleanly in the same install. **Every `reliability = good` Qwen row in `tiers.tsv` is now known-aspirational, not known-working**, and etude's entire "local-first agentic coding" premise needs either a working model family or a working upstream fix before the next hardware rollout is meaningful.

Session #04 cannot be the M1 Air test — the M1 Air will hit the exact same bug on whatever Qwen daily pick is registered for `mac-light`, so installing it would just reproduce the known failure. Session #04 has to come first. Full plan below.

### P2 (next up)

- **Session #05 (was #04): M1 Air 16GB first install.** Only meaningful once session #04 finds a working model; otherwise we're installing a known-broken path on a second machine. Still valuable for the `brew install --cask ollama` fresh-install branch that session #03 couldn't exercise.
- **Session #06 (was #05): RTX 5080 PC first install** (gpu-16gb tier, Windows). Same ordering constraint — need a working model first.
- **Rewrite `docs/install-macos.md`** — deferred from session #03. The prose is 133 lines of outdated brew-formula speculation. Should happen after session #04's model pivot lands so the doc describes the actual working path.
- **Build `scripts/status.sh`** — read-only audit tool. Reads sidecar + TSV + `ollama list` + `ollama show`, reports drift between intended and actual state. Session #03 produced the first real sidecar, so this is now buildable. A `status.sh --check-updates` variant should probably also resolve every registered tag against ollama's registry as a "does this exist" sanity check — that's the class of bug that hit us in session #03.
- **Build `install.sh --refresh` mode** — detect existing sidecar at startup, compare to current TSV, offer to pull delta and rewrite config.
- Flesh out `docs/usage.md` — day-to-day patterns, mode switching, real examples.
- Capture real latency numbers for the LAN-serve flow (Air → desktop).
- Rewrite `install-windows.md` alongside the PC session.
- Watch the Gemma 4 E4B tool-calling bug; flip its `reliability` from `watching` to `good` in `tiers.tsv` once fixed upstream.
- File upstream bug(s) for the qwen + ollama OpenAI-compat + opencode tool-schema issue once we have a minimal repro.

### Upcoming sessions

**Session #04 — Test the num_ctx theory, then audit + hunt as fallback**

Post-session-#03 research strongly suggests the observed Qwen + opencode tool-calling failures are caused by ollama's `num_ctx` defaulting to 4096, which truncates opencode's tool-definition prompts below the point where the model ever sees the tool schema. If that's right, the fix is a config tweak, not a model pivot. Session #04 tests the theory first; only falls back to the alternative-model hunt if it doesn't hold.

1. **Test the num_ctx theory (FIRST, highest priority).** Total time budget: 20 minutes.
   1. Create a variant: `ollama run qwen3:8b` → `/set parameter num_ctx 16384` → `/save qwen3:8b-16k` → `/bye`
   2. Patch `~/.config/opencode/opencode.json` to reference `qwen3:8b-16k` instead of `qwen3:8b` under the `ollama-local` provider. Keep the display name.
   3. Relaunch opencode from `/tmp/etude-smoke` (where `README.md` still exists from session #03).
   4. `/models` → Qwen3 8B (daily), confirm it now resolves to the `-16k` tag.
   5. Send the session #03 prompt: `Read README.md and write a one-sentence summary of this project to SUMMARY.md. Do not include any markdown formatting in SUMMARY.md — just the plain sentence.`
   6. **Expected (if theory holds)**: opencode shows a `Read` tool call with `filePath: "README.md"`, then a `Write` tool call with `SUMMARY.md`, and the file actually gets written. Check with `cat /tmp/etude-smoke/SUMMARY.md`.
   7. If qwen3:8b-16k works, repeat the recipe for qwen3-coder:30b (pick a larger num_ctx — 32768 or 65536 — since the model supports it and the heavy pick deserves the headroom).
2. **If the num_ctx fix works:** propagate the learning into the harness.
   1. **Update `scripts/lib/tiers.tsv`** — no reliability changes needed. Optionally add a column or note indicating the required min `num_ctx` per row, or just document it in the row note.
   2. **Update `config/opencode/*.json` templates** — change each model key from `qwen3:8b` to `qwen3:8b-16k` (and similar for qwen3-coder). Keep the display names intact; only the tag changes.
   3. **Update `install.sh` Phase 4** — after `ollama pull <tag>`, run a follow-up `ollama run <tag>` with `/set parameter num_ctx <N>` and `/save <tag>-<N>k` to create the high-context variant. Capture `<N>` from a new `num_ctx` column in `tiers.tsv`. The sidecar should record the `-Nk` variant tag, not the base tag.
   4. **Update `docs/models.md`** with the `num_ctx` finding + the recipe. This is important information; future readers will hit the same wall otherwise.
   5. **Remove / soften the Critical reminder** about `tiers.tsv` being unverified for agentic use — it's now verified (and the fix ships with the new install.sh).
   6. Commit each step as its own chunk.
3. **If the num_ctx fix does NOT work:** the theory is wrong, and the original session-#04 plan applies — audit the registry (demote Qwen rows to `watching`) and hunt for alternatives. Candidates ranked from session-#03 research:
   - **Devstral** (`devstral:latest`) — agentic SWE-bench leader, software-engineering-tuned, reported stable tool calling. Strongest candidate.
   - **Gemma 4 26B** — native function calling, different family entirely. Check whether the 4B tool-calling bug (known from session #01) still applies to the 26B variant.
   - **GLM-4.7** via Ollama Cloud (`glm-4.7:cloud`) — requires Ollama Cloud auth (blocks on the existing open thread). Likely works because the OpenCode Zen cloud control worked in session #03.
   - **DeepSeek-Coder-V2** — strong reasoning + tool use per community reports, large download.
   - **Qwen3-Coder-Next 80B** (MoE, ~3B active) — currently `watching`; probably too large for M3 Air's 24GB but worth noting for the 32GB+ tiers.
4. **Test the winner** (whichever path): interactive TUI + `opencode run` headless + the README prompt. All three should produce `SUMMARY.md`. Time each.
5. **File upstream minimal repro** (if time) on the num_ctx or tool-schema issue — whichever the root cause turns out to be. Belongs on the ollama repo with opencode cross-reference.
6. **Commit in logical chunks.**

Out of scope for #04: M1 Air test, PC/Windows, install-macos.md rewrite, status.sh, LAN flow, Ollama Cloud auth setup (unless step 3 requires it).

**Conditional branches**:
- **num_ctx theory holds** → this is the best outcome. Most of session #04 becomes mechanical cleanup. M1 Air rollout can proceed to session #05 as originally planned (just with the new `-Nk` tags).
- **num_ctx theory partially holds** (e.g., fixes qwen3:8b but not qwen3-coder:30b) → we have a daily driver for mac-air-24gb and a gap for the heavy pick. Note both and continue hunt for a heavy alternative.
- **num_ctx theory doesn't hold** → fall back to the alternative-model hunt in step 3. M1 Air stays queued for session #05+ with whatever the winning model is.
- **Nothing works locally** → cloud-first positioning, Ollama Cloud auth becomes P1 for session #05. Session #04 ends by filing the upstream bug and documenting what was tried.

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
- **Heavy model (qwen3-coder:30b) comparison — resolved, negative result.** Same prompt, 55 seconds, 4.2K tokens, one tool call attempted then abandoned. The model called a non-existent `Skill "read_file"` (opencode has no `Skill` family; the actual tool is `Read` with a `filePath` param), got `Skill 'read_file' not found`, apologized, and asked the user to clarify the task. **Different hallucination, same underlying failure as qwen3:8b**: neither Qwen model is reading opencode's actual tool schema. Big Pickle (cloud control) worked correctly in the same install in 8 seconds. The bug is in the ollama → opencode → Qwen tool-schema translation layer, not the model size.
- **Implication: most of `tiers.tsv`'s agentic recommendations are factually unverified.** Every Qwen row registered as `reliability = good` failed the tool-calling test. Text generation still works — Level 5 smoke test still passes, `opencode run "reply with X"` still works — but agentic use (tool calling) does not. The registry audit is session #04's P1.
- **Post-session research (2026-04-13 late) found the likely root cause: `num_ctx` default of 4096.** A community guide (`p-lemonish/ollama-x-opencode`) and the opencode docs both call this out: ollama loads every model with a 4K context window by default regardless of what the model's max supports, and opencode's `limit.context` config is send-side only — it doesn't override ollama's receive-side `num_ctx`. Tool-definition prompts are large (agent system prompt + tool schemas + user message often >>4K), and when truncated to 4K the tool schema is the first thing to get chopped. The model then sees a prompt that doesn't mention tools at all, so it fills in plausible-sounding tool names from training memory. The fix is to bake a larger `num_ctx` into a model variant (`ollama run qwen3:8b` → `/set parameter num_ctx 16384` → `/save qwen3:8b-16k`) and reference the variant tag in `opencode.json`. Session #04 P1 tests this theory first, which — if it holds — collapses the "registry reliability audit + working-model hunt" into a ~10-minute config fix instead of a model-family pivot. If the theory doesn't hold, fall back to alternative models (Devstral, GLM-4.7, Gemma 4 26B, qwen3-coder-next:80b) found in the same research pass.

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
