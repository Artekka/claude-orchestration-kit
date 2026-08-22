---
name: log-every-major-feature
description: Every meaningful feature, breakthrough, or fix bundle gets BOTH a dev-log entry (internal detail, SHAs, reasoning) AND a user-facing release-notes entry — different audiences, different framing; never just one
metadata:
  type: feedback
---

After landing a major chunk (new feature, new mechanic, bundled fix pass, infra change with user impact), do BOTH — don't pick one:

1. Add/update an entry in the project's user-facing release-notes surface — friendly language, 3–5 bullets.
2. Have the doc agent append a dated entry to the project's dev log — internal detail with SHAs, test counts, and the WHY.

**Why:** the human called it out after a session shipped 4+ features with only release notes updated — the dev log was silent, so the next session's orientation was incomplete and needed manual catch-up. Reaffirmed later as a STANDING rule: after any meaningful chunk ships, log it and COMMIT the docs without asking permission each time.

**How to apply:**
- The `/post-feature` skill encodes the checklist — invoke it when wrapping up.
- Default to logging even when the human didn't ask; over-logging is cheaper than gaps.
- Tiny chores (typo, comment, dep bump) skip both.
- The dev log captures WHY + technical detail; release notes capture WHAT in plain language.
- A same-version bugfix to a just-shipped feature still warrants a dev-log entry (it can skip the release-notes version bump).
