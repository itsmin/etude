# /session-end

Wrap up the session with a clean handoff to the next one.

## Steps

1. **Draft first.** You were present for the session. Draft the session entry from context — don't ask the user to recount what happened. Present the draft for review.

2. **Evidence-based feature verification.** For anything claimed as "working" or "complete" this session, state the evidence. "I tested this with [specific command/data] and saw [specific result]" — not "the code looks correct." If you can't verify, say so explicitly.

3. **Impact radius check.** If this session touched any of:
   - `docs/hardware-tiers.md` or `docs/models.md` → does the `Last reviewed` date need bumping?
   - `config/opencode/*.json` → do all documented tiers still have a matching template?
   - `scripts/detect-tier.sh` → does it still handle all platforms it used to?
   - `README.md` → is the quick start still accurate?
   - `docs/install-*.md` → have the steps actually been verified on a real machine?

4. **Deferred work capture.** Anything bumped for a bug or higher priority: add to the Deferred table in `CLAUDE.md` with a reason and the session number.

5. **Size check.** If `CLAUDE.md` is approaching 30k characters, flag yellow. Over 35k, flag red and recommend archiving session history to a `sessions/` folder.

6. **Session entry.** Write to the Complete (Recent) table. Format: max 8 lines, condensed. What changed, why, anything notable for next time. Increment the session number.

7. **Next session planning.** Draft the specific Next pointer for Upcoming Sessions — a sentence, not "continue P1 work." Show it to the user, get explicit confirmation, then write it.

## Notes

- This command is self-contained. It works without the Overture plugin installed.
- Voice: terse, evidence-led. No summary prose in entries — use the condensed format.
- Always get confirmation before writing the Next pointer to the operating doc.
