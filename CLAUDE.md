# etude — operating document

Project: **etude** — an install kit and docs for running a Claude Code-like coding agent on open-weight models. Three tiers: local, LAN peer, Ollama Cloud.

**Status**: Harness verified end-to-end on the M3 Air, **including agentic tool calling**. Session #04 closed out the session-#03 qwen-doesn't-tool-call finding — root cause was ollama's `num_ctx` defaulting to 4096 regardless of what the model supports, which silently truncated opencode's tool-schema prompt so the model confabulated tool names from training memory. Fix: etude now creates a local variant (e.g. `qwen3:8b-32k`) via `ollama create` with `PARAMETER num_ctx <N>` baked in, and all templates/sidecar/smoke tests reference the variant instead of the base tag. Both `qwen3:8b-32k` and `qwen3-coder:30b-32k` tool-call cleanly via opencode with the same prompts that failed in session #03. Mac-air-24gb is the first fully-verified tier (install + Level 5 smoke + tool-calling). Next up — second-machine verification on the M1 Air 16GB (mac-light tier, `qwen3:8b-16k` variant, fresh cask install). Other tiers use the same variant pattern but remain untested.

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

- **Local variant tags (`-<N>k`) are not optional.** etude does not reference upstream ollama tags directly in templates, sidecars, or smoke tests — it references local variants created in Phase 4 via `ollama create` with `PARAMETER num_ctx <N>` baked in. The reason: ollama loads every model with `num_ctx = 4096` regardless of max context, and opencode's `limit.context` config is send-side only, so at the default ollama context the tool-schema prompt gets truncated before the model ever sees the tool list. Session #03's "qwen can't tool-call" finding was this bug; session #04 verified the variant fix resolves it. Never swap a template or sidecar to a base tag — always the variant. `scripts/lib/tiers.tsv`'s `context` column is the source of truth for per-tier `num_ctx`. Naming convention: `<base>-<context/1024>k`. See `docs/models.md` § "Local variant tags" for the full recipe.
- **Agentic use is verified on mac-air-24gb only.** `qwen3:8b-32k` and `qwen3-coder:30b-32k` tool-call cleanly via opencode on the M3 Air (session #04, 2026-04-13). Every other tier uses the same variant pattern but is still untested on real hardware — same "other tiers unverified" caveat as before, narrower scope.
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

Added in session #04:
- **Agentic tool calling verified on mac-air-24gb.** `qwen3:8b-32k` (daily) and `qwen3-coder:30b-32k` (heavy) both tool-call cleanly via opencode with the session-#03 README→SUMMARY prompt. Full `scripts/test.sh` passes Levels 1–5 against the variant tag.
- **Variant tag pattern plumbed through the harness.** tiers.sh helpers, install.sh Phase 4 variant creation, sidecar writing the variant, all 9 config templates referencing the variant. Dry-run verified on mac-air-24gb.

Still unverified:
- **Fresh `brew install --cask ollama` branch of Phase 4.** Session #03 couldn't exercise it — Ollama.app was already on the M3 Air (downloaded directly, not via cask). First machine without Ollama.app is the target.
- **Daemon auto-start after a fresh cask install.** Currently `open -a Ollama` with `sleep 2` retry, untested against a cold machine.
- **All tiers other than mac-air-24gb.** `mac-light`, `mac-pro-32gb`, `mac-heavy-64gb`, `mac-max`, and every `gpu-*` tier are registry entries + config templates + (now) variant recipes without a real run. The variant pattern is model-agnostic, so the risk is memory/fit (e.g. `qwen3-coder-next:80b-128k` on mac-max), not tool-calling reliability.
- **`install-windows.md`** — entire Windows path, entirely unverified.
- **LAN-serve flow** (Air → desktop Ollama, or vice versa). LAN templates now reference variant tags too; the peer machine would need to have run `install.sh` (or manually `ollama create` the variant) for cross-machine calls to resolve.
- **Ollama Cloud auth / `:cloud` model pull** — see open threads.
- **`install-macos.md` prose** — deferred from session #03, needs a full rewrite to match the harness (currently documents the old brew-formula path and has no mention of the variant tag pattern).

---

## Work queue

### P1 (active)

**Session #05 — M1 Air 16GB first install (mac-light tier).** Now unblocked. Session #04 confirmed the variant tag pattern works end-to-end on the M3 Air, and `config/opencode/mac-light.json` already references `qwen3:4b-16k` + `qwen3:8b-16k`. Session #05 is the first test of the harness against genuinely fresh hardware (no Ollama.app pre-installed), the `brew install --cask ollama` branch of Phase 4, and the `qwen3:8b-16k` variant that mac-light uses for the heavy role on 16GB unified memory — a harder memory constraint than mac-air-24gb saw. Primary question: does `qwen3:8b-16k` tool-call as cleanly as the `-32k` variant did, and does 16GB hold it with a browser open?

### P2 (next up)

- **Session #06: RTX 5080 PC first install** (gpu-16gb tier, Windows). Now also unblocked. Will exercise the `gpu-16gb` templates (`qwen3-coder:30b-32k` daily, `qwen3:8b-32k` speed) and the unverified `install-windows.md` prose. Ordering-wise: do M1 Air first to shake out any num_ctx-pattern edge cases before taking on a new OS surface.
- **Rewrite `docs/install-macos.md`** — deferred from session #03 and still correct to defer. The prose is 133 lines of outdated brew-formula speculation *and* doesn't mention the variant tag pattern. Best rewritten after session #05 so it reflects both verified tiers and the final num_ctx story.
- **Build `scripts/status.sh`** — read-only audit tool. Reads sidecar + TSV + `ollama list` + `ollama show`, reports drift between intended and actual state. Session #04 also surfaced a new audit surface: does every variant tag the sidecar records still exist locally (in case a user manually `ollama rm`ed one)? And does `tiers_context_for $tier $base` still match what `ollama show <variant>` reports? A `--check-updates` variant should also resolve every base tag against ollama's registry — that's the session-#03 class of bug.
- **Build `install.sh --refresh` mode** — detect existing sidecar at startup, compare to current TSV, offer to pull delta, rebuild variants at the current `context` column, and rewrite config. This becomes a more interesting feature now that variants exist: a TSV bump from `context=32768` to `context=65536` should trigger a variant rebuild, not just a re-pull.
- Flesh out `docs/usage.md` — day-to-day patterns, mode switching, real examples. Should also mention the `-<N>k` suffix so users don't get confused when `ollama list` shows names they didn't pull.
- Capture real latency numbers for the LAN-serve flow (Air → desktop). Variant tags on LAN peers need either install.sh on the peer, or a manual `ollama create` — worth a dedicated usage note once the first LAN test happens.
- Rewrite `install-windows.md` alongside the PC session.
- Watch the Gemma 4 E4B tool-calling bug; flip its `reliability` from `watching` to `good` in `tiers.tsv` once fixed upstream. Once flipped, verify it also survives the variant tag pattern (Gemma's bug was a parser-level thing, unrelated to num_ctx, so the variant shouldn't matter — but check).

### Upcoming sessions

**Session #05 — M1 Air 16GB first install (mac-light tier)**

Sequence mirrors session #03's M3 Air path, with two new things to actually exercise:

1. **Fresh `brew install --cask ollama`** — the M3 Air already had Ollama.app from a direct download, so session #03 never ran this branch of Phase 4. The M1 Air is genuinely clean (or will be after `brew uninstall ollama` if the old formula is still lurking). Verify: cask install completes, `open -a Ollama` or equivalent brings the daemon up, `sleep 2` retry is adequate for a cold machine (if not, bump it).
2. **The variant tag pattern at a harder memory budget.** mac-light registers `qwen3:4b-16k` (daily) and `qwen3:8b-16k` (heavy), both at `num_ctx=16384`. The 8B-16k variant is untested — verify: (a) it actually tool-calls cleanly through opencode with the README→SUMMARY prompt, (b) it fits in 16GB unified memory with a browser open, (c) Level 4 + Level 5 smoke tests pass. If 8B-16k is too tight under real use, the mac-light `context` column in `tiers.tsv` might need to drop to 12288 or reroute the heavy pick to a different model.

Plan:
1. Prep: `brew uninstall ollama` if the stale formula is on the machine. Confirm no Ollama.app already installed (or note if there is — that branches behavior).
2. `cd` into this repo on the M1 Air (sync or git clone), run `./install.sh`. Should detect `mac-light`. Accept defaults in configured mode, pick both daily + heavy to exercise both variant creations.
3. Watch Phase 4: variant creation for `qwen3:4b-16k` and `qwen3:8b-16k`, sidecar write.
4. Run `./scripts/test.sh` — expect Levels 1–5 green.
5. Manual tool-calling verification: `opencode run -m ollama-local/qwen3:8b-16k "Read README.md and write a one-sentence summary of this project to SUMMARY.md..."` in `/tmp/etude-smoke-m1`. Confirm the file actually gets written.
6. Note any memory pressure (Activity Monitor, or `sudo memory_pressure`) while the 8B variant is loaded. If it thrashes with a browser open, record and consider the mac-light `context` budget.
7. Commit any harness fixes that fall out. Close the "fresh cask install" and "daemon auto-start on cold machine" pending-verification items.

Out of scope for #05: PC/Windows, install-macos.md rewrite, status.sh, LAN flow, Ollama Cloud auth.

**Conditional branches**:
- **Everything works** → session #05 closes cleanly, mac-light is now a second verified tier, session #06 (PC) becomes P1.
- **`qwen3:8b-16k` tool-calls but OOMs with a browser open** → drop mac-light heavy to `qwen3:4b-16k` only (8B becomes a "close everything" opt-in), or lower `num_ctx` for the heavy pick. Document the tradeoff in `docs/models.md`.
- **Fresh cask install path has a bug** → fix install.sh Phase 4, commit, re-run. This is exactly the kind of real-hardware find session #05 is for.
- **Variant creation fails on a clean machine** → the Modelfile-via-stdin approach in Phase 4 is the suspect (some ollama versions may not like `/dev/stdin`). Fallback: write the Modelfile to a temp file. Fix and re-run.

### Parking lot (out of scope for now)

- **Dedicated watchlist file** separate from the TSV's `reliability=watching` column. The column handles v1 fine; a separate file only earns its place once there are more than 1–2 tracked entries and we want richer metadata per entry (source URL, trigger condition, last-checked date). Revisit when that happens.
- Linux-native install guide (generalizable from Windows section but not verified)
- vLLM path for the PC (faster throughput, more setup)
- Custom per-project opencode modes or system prompts
- "Sync models across machines" helper
- Fine-tuning workflow

### Open threads (carry forward)

- **~~qwen3:8b + opencode: not viable for agentic use~~ — RESOLVED in session #04.** The session-#03 finding was a config bug, not a capability bug. Root cause: ollama's `num_ctx` default of 4096 silently truncated opencode's tool-schema prompt below where the model ever saw the tool list, leading to confabulated tool names from training memory. Fix: create a local model variant (`qwen3:8b-32k`) via `ollama create` with `PARAMETER num_ctx <N>`, reference the variant in templates and sidecars. Both `qwen3:8b-32k` and `qwen3-coder:30b-32k` now tool-call cleanly through opencode on the M3 Air with the exact prompt that failed in session #03. See `docs/models.md` § "Local variant tags" and the Critical reminders block above.
- **Ollama Cloud auth / pricing mechanics.** Still not explored. Sign-up flow, key storage, current `:cloud` model catalogue all still unknown. Parked until a session needs it.
- **Windows install doc ordering.** The doc currently defaults to fully-native Windows with WSL2 as the advanced path. Since the PC doubles as a LAN inference server, WSL2-for-opencode + native-Ollama may be the better anchor. Revisit when verifying `install-windows.md`.
- **Registry tag validation.** Session #03 caught `qwen3-coder:30b-a3b` in `tiers.tsv` as a tag that doesn't exist on ollama.com — the real tag is `qwen3-coder:30b`. Only caught because we did a real pull. `status.sh --check-updates` (P2) should do a "does every registered base tag still resolve against the ollama registry?" sanity check; `install.sh` Phase 1 could do the same on the tags it's about to pull. Session #04's variant tag layer does not help here — we still `ollama pull <base>` upstream, then derive the variant locally, so a bogus base tag still fails at pull time.
- **Variant rebuild on context bumps.** If `tiers.tsv` bumps a row's `context` column (e.g. 32768 → 65536), install.sh's current Phase 4 will happily `ollama create qwen3:8b-64k` on the next run, but a user who installed at 32k and doesn't re-run install.sh keeps an opencode.json referencing `qwen3:8b-32k` that no longer matches the template. This is the exact use case for the P2 `install.sh --refresh` mode. Noted so it doesn't quietly rot.

### Deferred (in scope, bumped)

*(none yet)*

### Complete (recent)

### Session #04 — num_ctx fix + variant tag pattern (2026-04-13)
- **num_ctx theory confirmed on M3 Air.** Created `qwen3:8b-32k` and `qwen3-coder:30b-32k` via `ollama create` with `PARAMETER num_ctx <N>`. Both tool-called cleanly through opencode on the session-#03 README→SUMMARY prompt — the exact prompt that spent 4m41s in circular "no Read function" confabulation last session. qwen3:8b-32k: `→ Read → Write → success`, file on disk. qwen3-coder:30b-32k: same, 7m51s (30B is slow on M3 Air but correct). Root cause is ollama's `num_ctx=4096` default silently truncating opencode's tool-schema prompt below where the model ever sees the tool list.
- **Variant tag convention.** `<base>-<ctx/1024>k`, with `<ctx>` sourced from `tiers.tsv`'s existing `context` column (no schema change). Templates, sidecar, and smoke tests reference the variant; base tag is only used at `ollama pull` time.
- **Harness propagation.** `scripts/lib/tiers.sh` gained `tiers_context_for` and `variant_tag_for` helpers. `install.sh` Phase 4 creates the variant via Modelfile-on-stdin after each pull, records the variant tag in the sidecar, and displays both base and variant in the Plan output and Done message. All 9 `config/opencode/*.json` templates updated (15 tag renames total; cloud tags and display names untouched).
- **End-to-end verified on M3 Air.** Patched live `~/.config/opencode/opencode.json` to `qwen3:8b-32k` and `qwen3-coder:30b-32k`, updated the live sidecar, ran `./scripts/test.sh` — all 5 levels green against the variant tag. install.sh `--dry-run --tier mac-air-24gb --mode configured` emits correct Plan (shows `variants: qwen3:8b-32k`) and Phase 4 output (shows the `ollama create` step).
- **Docs updated.** `docs/models.md` gained a new "Local variant tags (`-<N>k`) and why they exist" section with the failure mode, the fix, the recipe, and the naming convention. The Qwen3 8B / Qwen3-Coder 30B entries now reference variant tags with a pointer to that section. "How to swap a model" grew a mandatory variant-creation step between pull and test. `Last reviewed` bumped.
- **Operating doc cleanup.** Critical reminder in this file rewritten from "tiers.tsv unverified for agentic use" to "local variant tags are not optional" + narrower "mac-air-24gb only" scope. Session #03's "qwen3:8b tool-calling not viable" open thread marked RESOLVED with the root cause. Status line updated. Session #05 promoted to P1 (M1 Air is now unblocked).
- **Unverified / deferred.** Other tiers still untested on real hardware — the variant pattern is model-agnostic, so the remaining risk is memory fit, not tool calling. Dangling `qwen3:8b-16k` test variant left in `ollama list` (created for the first test at 16K before deciding 32K matched opencode's `limit.context`). Harmless; a future `status.sh` could clean up such orphans. `install-macos.md` rewrite still deferred — now also needs to document the variant pattern.

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
