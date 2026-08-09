---
name: reconcile
description: Land a finished implementation-agent's worktree onto main and run the project's authoritative gate (without deploying). Use right after a worktree subagent reports done, or when the user says "reconcile that agent", "land the worktree", "bring it into main". One worktree at a time — never reconcile in parallel with another session's landing.
---

# reconcile

A worktree's green is necessary but not sufficient — it can mislabel an environmental flake, miss what the production build catches, or be branched off a stale main. This skill lands the work and re-proves it on main. It does NOT deploy and does NOT write changelogs.

## Steps

1. **Identify + scope** — `git worktree list`; `git diff --stat main <branch>`. Confirm the diff stays inside the board row's file fence (stray edits to locked/unrelated files → STOP, surface). Classify the change per `ORCHESTRATION.md` → Change classes.
2. **Sequence** — check the board: is another session mid-reconcile, or does a coord note order this row after another? Honor it. One landing at a time.
3. **Land** — `git cherry-pick <branch>` (single commit) or `<oldest>^..<branch>` / `git merge --no-ff` for multi-commit. If the pick conflicts, resolve ONLY within the row's fence; anything else → stop and surface.
4. **Rebuild derived artifacts** if the overlay/build requires it (e.g. a shared package's dist that typecheck reads).
5. **Gate on main** — run the overlay's gate for the change class. Read the REAL result: literal pass line + clean exit, captured unpiped. A subagent's "pre-existing failure"/"flake" claim is re-proven here by an isolated re-run, or treated as a real regression.
6. **Clean up + report** — prune the landed worktree + branch (leave others alone); update the board row (SHA, gate lines, fence released); report "main green, ready to deploy" or the specific failure. Never deploy from here — the DEPLOY row claim governs that.
