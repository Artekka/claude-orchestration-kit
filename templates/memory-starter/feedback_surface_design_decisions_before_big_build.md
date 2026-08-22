---
name: feedback_surface_design_decisions_before_big_build
description: "For a sizable feature, investigate then present the genuinely BRANCHING design decisions via AskUserQuestion (with concrete ASCII/table/code previews) BEFORE building. Art picks, then says build/deploy. Small mechanical choices stay inline as stated defaults."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 27852ff1-7c0f-474c-9ff1-f85762b9a627
  modified: 2026-07-26T20:37:50.696Z
---

Repeatedly effective across the 2026-07-25/26 session (5 features shipped: biggest-hit leaderboard, accessory buff, Proving Grounds, formation Phases 1-2): when a request is more than a one-liner, don't dive straight in — investigate the subsystem, then surface the decisions that actually change the build via `AskUserQuestion` with **concrete previews** (ASCII mockups for UI/layout, value tables for balance, code/preview for approaches). Art answers crisply and then says "build and deploy" / "let's do it".

**Why:** a wrong-direction build on a large feature is expensive; a 2-3 question checkpoint is cheap, and the previews let Art compare options concretely instead of imagining them. He does NOT want to be asked about choices with an obvious default.

**How to apply:**
- Ask only the branching decisions (2-3 max); take sensible defaults on the rest and STATE them (travel days, grid dims, storage model) rather than asking.
- Then run the full ship cadence: build all layers → `pnpm gate` → patch note + `LATEST_PATCH_VERSION` bump → `/deploy` (verify the live bundle carries a marker from this change) → dispatch Felix (build-log milestone + AI_CONTEXT refresh) → commit her docs → push.
- For a LARGE multi-phase feature, offer to ship Phase 1 (the actual pain-fix) now and build the rest as a follow-up — but don't be over-cautious about context: at ~50% of a 1M window there's ample room to keep going (Art asked directly, 2026-07-26).

Related: [[feedback_art_iterates_ui_via_local_mockups]] · [[feedback_pull_board_before_scoping_and_dont_overengineer]] · [[feedback_deploy_per_task_cadence]].
