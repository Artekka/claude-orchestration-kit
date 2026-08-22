---
name: falsification-mutants-one-tree-no-stderr-suppression
description: "Mutation/falsification commands must target ONE explicit tree with stderr visible — a stray relative path in a compound command mutated the SHARED checkout and blocked a sibling's cherry-pick; diff-verify every tree the command could have touched, not just the one the test reads"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2e45a8bb-b2e2-4cb6-81aa-e88b591b612e
  modified: 2026-08-21T20:04:52.812Z
---

During S2-1's falsification pass (2026-08-21), a compound Bash command carried TWO perl invocations — a leftover path guess targeting `../../../packages/client/...` (which resolves from a worktree root to the SHARED checkout) with `2>/dev/null`, then the correct worktree-relative one. The stray silently mutated main's copy of MaintenanceBanner.tsx; the restore only covered the worktree, and the orphaned mutation blocked the orchestrator's cherry-pick sequencer mid-reconcile (the M411 wrong-tree class, via a mutation command instead of a gate).

**Why:** falsification mutants are deliberately destructive edits run outside the commit history — nothing downstream (gate, status check scoped to the worktree, test run) will ever notice a copy mutated in a tree the test doesn't read. Suppressed stderr removed the one signal that would have flagged the first path when it was wrong.

**How to apply:**
- One mutation command = ONE explicit target path. Never leave earlier path guesses in the compound; retype the command clean.
- Never `2>/dev/null` on a command that EDITS files.
- After restore, diff-verify every tree the command string could have reached (worktree AND the shared checkout), not just the tree the test reads.
- The evidence itself can still be valid when the test provably read the mutated-and-restored copy (path-resolution + in-worktree diff count) — but re-prove the one falsification cleanly anyway; an evidence chain with an asterisk is not worth the minutes saved.
