---
name: log every major feature both to dev-log and patch notes
description: the doc agent must append to the project build log AND a player-facing the release-notes file entry must be added for every meaningful feature, breakthrough, or fix bundle
type: feedback
originSessionId: 3e9750fb-e8f7-4022-8b83-9a818bfe3fd6
---
After landing a major progress chunk (new feature, new mechanic, bundled bug-fix pass, sprite/asset wiring, infra change with player impact), do BOTH of these — don't pick one:

1. Add or update an entry in `packages/client/src/lib/the release-notes file` so the change shows up on the Battle Hall patch-notes panel. Player-friendly language, 3-5 bullets.
2. Dispatch the the tech-writer doc agent sub-agent to append a new dated entry to `the project build log` — internal-detail dev log with SHAs, test counts, and reasoning.

**Why:** Art reminded me on 2026-05-30 after a session where I shipped 4+ features and only updated patch notes — the build log was silent. The build log is the project's institutional memory; without it the next agent's `/orient` summary is incomplete and Art has to catch them up manually.

**How to apply:**
- The `/post-feature` skill already encodes this checklist — invoke it when wrapping up rather than skipping straight to `/deploy`.
- After a `/deploy` for a meaningful feature, default to dispatching the doc agent even if the user didn't explicitly ask. Better to over-log than to leave gaps.
- For tiny chores (typo fix, comment update, dep bump), skip both — patch notes are for players, build log is for non-trivial work.
- The dev log captures the WHY and the technical detail; patch notes capture the WHAT in plain language. Both audiences need different framing.
- **Reaffirmed 2026-06-24:** when I offered to log a shipped+deployed fix vs. fold it into the next entry, Art said "always commit that stuff." Read this as a STANDING rule: after any meaningful chunk ships+deploys, log it (the doc agent build-log + the status doc refresh, per the dev-log routine) and COMMIT the docs — don't ask permission each time. A same-version bugfix to a just-shipped feature still warrants a build-log milestone entry (it can skip the the release-notes version bump).
