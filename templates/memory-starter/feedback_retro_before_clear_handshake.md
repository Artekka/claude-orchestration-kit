---
name: feedback_retro_before_clear_handshake
description: /retro MUST complete (confirmed by reply) BEFORE a sibling terminal is recycled (closed and relaunched with an explicit --model); the orchestrator acts only after the sibling's explicit "retro complete"
metadata:
  type: feedback
---

*"Retro should come before a clear because the retro ties any loose knots and teaches our
agents what to expect when they next orient."*

**What happened:** the orchestrator sent retro orders to two stale sibling sessions and both
terminals were cleared before the orders processed. Committed state survived via the board,
commits and log; the unpersisted lessons (memories, skill candidates) were lost.

**Why:** `/clear` destroys context; the retro is the only step that turns context into durable
teaching for the next session. Racing them discards exactly what the lifecycle preserves.

**How to apply (orchestrator-led mode):** a three-step HANDSHAKE — (1) the seat sends "run the
retro now"; (2) the sibling replies "retro complete" (board synced, commits pushed, deploy
skipped); (3) ONLY THEN is the terminal closed and relaunched, one at a time, with an explicit
`--model` (a bare `/clear` keeps the old model). Never pre-announce a recycle; never batch-announce
before confirmations.
