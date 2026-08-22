---
name: feedback_trust_user_observation_over_code_skim
description: "When the user reports observed behavior that contradicts your code read, trust the observation and trace EVERY branch (esp. fallbacks) — a code-skim or read-only Explore agent can assert the wrong branch runs."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: acd22cd1-e143-4035-b194-8411a4ca73f7
---

When Art reports "X happens" (especially with a screenshot / battle id / repro), treat it as ground truth and find the branch that PRODUCES X — do not assert the opposite from a single code path or a read-only agent's conclusion.

**Why:** Day 63 (2026-06-11) Art reported vs-AI battles fielding his whole account roster despite the lobby dropdowns. I (and an Explore agent) read the `if (teamComposition) generateRandomParty(...)` happy path in `createBattleState` and confidently told him "vs-AI does NOT load your roster" — missing the `else → loadPartyAsUnits(sideAUserId)` fallback that fired whenever `lobby.teamComposition` was NULL (a client emit race left it NULL). Art had to push back hard with screenshots before I traced the fallback. The skim concluded the wrong branch executes.

**How to apply:** (1) Believe the user's observation over your read of the code. (2) Read EVERY branch of the relevant function — the bug usually lives in the `else`/fallback/default-arg path, not the obvious one. (3) For "does X happen" questions, verify against running behavior (server logs, DB state, a repro) before claiming the opposite — a read-only agent's "it does Y" is a hypothesis, not proof. Related: [[feedback_dont_trust_comments_trace_code]], [[feedback_verify_before_narrate]], [[feedback_visual_bug_triage]], [[feedback_balance_complaint_check_path_asymmetry]].
