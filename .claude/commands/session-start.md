# /session-start

Load project context and present the current state of **etude**.

## Steps

1. **Clean state check.** Run `git status` — flag anything uncommitted. Flag anything left over from a prior session that wasn't wrapped up.

2. **Read the operating document.** Open `CLAUDE.md`. Pay attention to:
   - Critical reminders
   - P1 / P2 / Upcoming sessions
   - Deferred work (anything flagged >5 sessions old is stale)
   - Complete (Recent) — last ~10 entries

3. **Health check.** For etude specifically:
   - `ollama --version` — is it 0.20.2+?
   - `ollama list` — are the expected models pulled (qwen3:8b, qwen3-coder:30b-a3b)?
   - `opencode --version` — is the harness available?
   - If any of those fail, note them — don't auto-fix. Present as "found these, here's what it means."

4. **Surface the work.** Print the current P1 and the specific Next pointer from Upcoming Sessions. If the Next pointer is vague ("continue P1 work"), flag it — Next is supposed to be specific.

5. **Hygiene signal.** If 3+ sessions have passed without an operating doc hygiene review (stale deferred items, outdated complete table), raise it.

6. **Report and stop.** Print a short state summary. Wait for the user's direction — don't start implementing anything yet.

## Notes

- This command is self-contained. It works without the Overture plugin installed.
- Voice: direct, no preamble. Report what is, not what you plan to do about it.
- End with the Next pointer as the suggested first move.
