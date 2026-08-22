---
name: feedback-parallelize-independent-work
description: "Art wants maximum parallelism — batch independent tool calls in one message and run independent work streams as concurrent agents, never serially."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a6c7a60b-9b62-4429-9d62-7653c4f680ce
---

When work has independent parts, do them AT THE SAME TIME, not one-after-another:
1. **Batch independent tool calls** (reads, greps, edits to DIFFERENT files, DB queries, memory writes) into a SINGLE message so they run concurrently.
2. **Launch independent implementation/investigation streams as CONCURRENT agents** — one message, multiple Agent calls — rather than awaiting one before starting the next.
3. When multiple agents mutate files in parallel, isolate each in its own **worktree** to avoid clobber (`feedback_isolate_worktree_for_concurrent_sessions`).
4. Only serialize on a TRUE dependency (stream B needs stream A's output, e.g. a prod backfill that needs the recomputed number first).

**Why:** Art runs long, multi-ask marathon sessions (`feedback_marathon_session_style`); idle sequential round-trips waste wall-clock. He stated this explicitly on 2026-07-11 after watching sequential tool use during the Reaper epic.

**How to apply:** Default to fan-out. Before每 tool call, ask "what else that's independent can I fire in this same batch?" Related: `reference_tdd_phase_orchestration_loop`.
