---
name: feedback_parallelize_independent_work
description: Batch independent tool calls in one message and run independent work streams as concurrent agents, never serially without a real dependency
metadata:
  type: feedback
---

When work has independent parts, do them AT THE SAME TIME:
1. **Batch independent tool calls** (reads, greps, edits to DIFFERENT files, queries) into a
   single message so they run concurrently.
2. **Launch independent investigation/implementation streams as concurrent agents** — one
   message, several Agent calls — instead of awaiting one before starting the next.
3. When several agents mutate files in parallel, isolate each in its own **worktree**.
4. Serialize only on a TRUE dependency (stream B needs stream A's output).

**Why:** idle sequential round-trips waste wall-clock in long multi-ask sessions.

**How to apply:** default to fan-out. Before each tool call, ask "what else independent can I
fire in this same batch?"
