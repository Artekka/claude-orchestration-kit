---
name: feedback_retro_before_clear_handshake
description: "Art's ruling 2026-08-20 — /retro MUST complete (confirmed by reply) BEFORE a sibling terminal is /cleared; the orchestrator only announces 'safe to /clear' after the sibling's explicit retro-complete confirmation"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3180df04-6528-4e84-8c6d-655efa30816c
  modified: 2026-08-20T20:56:44.965Z
---

Art, 2026-08-20 (Orchestrated-Autonomy pilot, fleet fan-out): *"Retro should come before a clear because the retro ties any loose knots and teaches our agents what to expect when they next orient and builds any skills necessary from the work we did."*

**What happened:** the orchestrator sent retro orders to two 11-day-stale sibling sessions and Art `/clear`ed both terminals before the orders processed — the fresh sessions had nothing to retro. Committed state survived via the durable record (board/commits/build-log); the stale contexts' unpersisted lessons (memories, skill candidates) were unrecoverable.

**Why:** `/clear` destroys context; `/retro` is the only step that converts context into durable teaching (memories, skills, tied-off knots) for the next oriented session. Racing them silently discards exactly what the lifecycle exists to preserve.

**How to apply (orchestrator-led mode):** the lifecycle is a three-step HANDSHAKE — (1) orchestrator sends "run /retro now"; (2) sibling replies "retro complete" (board synced, commits pushed, deploy skipped per orchestrator-mode rule); (3) ONLY THEN the orchestrator tells Art "terminal <name> is safe to /clear", one terminal at a time. Never pre-announce clears, never batch-announce before confirmations. Codified in `.claude/skills/orchestrate/SKILL.md` §8. Related: [[feedback_multisession_board_orchestration_default]], [[reference_cross_session_peer_reachability]].
