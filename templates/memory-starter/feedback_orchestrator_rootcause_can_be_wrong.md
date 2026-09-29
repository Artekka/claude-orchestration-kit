---
name: feedback_orchestrator_rootcause_can_be_wrong
description: An orchestrator's traced root cause is a hypothesis — briefs must tell the builder to REPRODUCE first and report if it can't; deductive chains need their alternatives enumerated
metadata:
  type: feedback
---

The orchestrator traced a plausible engine root cause for a "damage not registering" bug and
dispatched a fix brief asserting it. The builder wrote the reported scenarios against the
UNMODIFIED code — all passed — reported honestly "no RED reproducible", shipped only harmless
regression guards, and pointed at the client. The real bug was a display issue on the client.

**Why:** a plausible code trace can be wrong. A brief that demands RED→GREEN can pressure an agent
into confabulating a fix.

**How to apply:** in a bug-fix brief, tell the builder to REPRODUCE the symptom against current
code FIRST and REPORT BACK if it can't. Treat "the traced cause doesn't hold, here's what I found"
as success. The orchestrator's root cause is a *hypothesis to test*, not a *conclusion to build*.

**The same failure in a deductive shape:**
1. "X doesn't exist anywhere in the repo" — after grepping two of three packages. **Scope every
   claim to the paths you actually searched.**
2. A closed-looking chain: "the step is satisfied only by A; A never happened; yet we're past it;
   therefore the step didn't exist yet." Wrong — a third path (an automatic advance when a
   predicate returned true) was never listed.
3. A peer's real-browser repro settled it in seconds.

**Rule:** when a chain ends in "therefore it must be X", write out the alternatives you
eliminated and ask **what class you never listed** — especially automatic paths (auto-advance,
reconcilers, cron, retries). A deterministic repro outranks any deduction.
