---
name: feedback_orchestrator_rootcause_can_be_wrong
description: "A confident orchestrator-traced root cause can be a red herring; brief impl agents to REPRODUCE the reported symptom against unmodified code before \"fixing\", and trust a \"no RED reproducible\" report"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 234f516e-1a0d-4cb1-bf44-ddc5d781d91b
  modified: 2026-08-20T12:58:07.660Z
---

In the Dragoon "spear damage not registering, only collision" bug, the orchestrator traced a specific engine root cause (stale `currentTarget.hp` clobbering the primary strike) and dispatched a hotfix brief asserting it. The impl agent verified the hypothesis did NOT reproduce — it wrote the reported scenarios against the UNMODIFIED engine, all passed, reported honestly "no RED reproducible," shipped only harmless regression guards, and pointed to the client. The real bug was client float occlusion.

**Why:** a plausible code-trace by the orchestrator can be wrong; here the engine was already correct. A brief that demands a RED→GREEN "fix" can pressure an agent into confabulating one.

**How to apply:** in a bug-fix brief, tell the impl agent to REPRODUCE the reported symptom against current code FIRST and to REPORT BACK if it can't reproduce (rather than force a fix onto a wrong hypothesis). Treat "the traced cause doesn't hold, here's what I actually found" as a success, not a failure. Keep the orchestrator's root cause as a *hypothesis to test*, not a *conclusion to implement*.

**2026-08-19 — the same failure, three times on ONE bug (O79, the tutorial soft-lock), and the shape is worth memorising.**

1. Claimed "no `returned-home` event exists anywhere in the repo." I had grepped `packages/shared/src/tutorial/*.ts` and `packages/server/src/**/*.ts` and stated the result **repo-wide**. It existed 16 times — fully wired in `packages/client/`. **Scope every claim to the paths you actually searched.** "I didn't find it in shared+server" and "it doesn't exist" are different sentences.
2. Then built a *closed-looking* proof chain: the step is satisfied only by X, X never happened, yet the cursor is past it, and the client button can't be clicked past — **therefore** the step must not have existed yet. Wrong. I had enumerated two ways past a gate (clicked it, or it wasn't there) and missed the third: **an event step AUTO-ADVANCES when its predicate returns true.** I had verified the *button* was gated and never asked whether the *predicate could lie*.
3. A peer's real-browser smoke then reproduced it on a fresh account in 2s, which no amount of my reasoning had.

**Why:** a deductive chain feels stronger than a trace, so it gets challenged less — but it is only as closed as its enumeration of alternatives, and an enumeration is exactly the thing you cannot check from inside it. Both my errors survived because each conclusion was *reasonable*.

**How to apply:** when a chain ends in "therefore it must be X", write out the alternatives you eliminated **and ask what class you never listed** — especially automatic/implicit paths (auto-advance, reconcilers, cron, retries) that need no user action. Prefer a reproduction over a deduction: if a peer can produce a deterministic repro, that outranks any chain. And when a peer corrects you, verify it — the second correction here came from checking the first.

Links [[feedback_verify_before_narrate]] [[feedback_verify_subagent_failure_claims]] [[feedback_trust_user_observation_over_code_skim]] [[reference_dragoon_charge_damage_and_float_batch]] [[reference_fail_open_null_when_store_not_loaded]] [[feedback_a_test_can_pin_the_defect]].
