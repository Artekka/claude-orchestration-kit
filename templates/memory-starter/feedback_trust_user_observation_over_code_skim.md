---
name: feedback_trust_user_observation_over_code_skim
description: When the user reports observed behavior that contradicts your code read, trust the observation and trace EVERY branch (esp. fallbacks) — a code skim or read-only agent can assert the wrong branch runs.
metadata:
  type: feedback
---

When the user reports "X happens" (especially with a screenshot, id, or repro), treat it as
ground truth and find the branch that PRODUCES X — don't assert the opposite from one code path
or a read-only agent's conclusion.

**Why:** a user reported a mode loading the wrong data. The agent (and an Explore agent) read the
happy path and confidently said "it doesn't do that" — missing an `else` fallback that fired
whenever a field was NULL (left NULL by a client race). The user had to push back with
screenshots before the fallback was traced.

**How to apply:** (1) Believe the observation over your read of the code. (2) Read EVERY branch
of the relevant function — the bug usually lives in the `else`/fallback/default path.
(3) For "does X happen" questions, verify against running behavior (logs, DB state, a repro)
before claiming the opposite — a read-only agent's "it does Y" is a hypothesis, not proof.
