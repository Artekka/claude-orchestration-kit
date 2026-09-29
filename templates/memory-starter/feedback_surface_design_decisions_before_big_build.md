---
name: feedback_surface_design_decisions_before_big_build
description: For a sizable feature, investigate, then present the genuinely BRANCHING design decisions via AskUserQuestion (with concrete previews) BEFORE building. Small mechanical choices stay inline as stated defaults.
metadata:
  type: feedback
---

When a request is more than a one-liner, don't dive straight in — investigate the subsystem,
then surface the decisions that actually change the build via `AskUserQuestion`, with
**concrete previews** (ASCII mockups for layout, value tables for tuning, code sketches for
approaches). The user picks, then says "build it".

**Why:** a wrong-direction build on a large feature is expensive; a 2–3 question checkpoint is
cheap, and previews let the user compare options instead of imagining them. Don't ask about
choices with an obvious default.

**How to apply:**
- Ask only the branching decisions (2–3 max); take sensible defaults on the rest and STATE them.
- Then run the full ship cadence: build → project gate → release note → deploy (verify the live
  artifact) → log + status-doc refresh → commit → push.
- For a large multi-phase feature, offer to ship Phase 1 (the actual pain fix) now and the rest
  as a follow-up.
