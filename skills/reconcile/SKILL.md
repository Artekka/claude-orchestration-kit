---
name: reconcile
description: Land a finished implementation-agent's worktree onto main and run the project's authoritative gate for the change class (without deploying). Use right after a worktree subagent reports done, or when the human says "reconcile that agent", "land the worktree", "bring it into main". One worktree at a time — never reconcile in parallel with another session's landing.
---

# reconcile

A worktree green is necessary, not sufficient — it can be off a stale main, hide an environmental flake, or miss what the production build catches. This lands the work and runs the AUTHORITATIVE gate. It does not deploy and does not write logs/release notes.

## Steps

1. **Identify branch + scope.** `git worktree list` + the agent's report. `git diff --stat main <branch>` — confirm no files outside the row's fence (stray edits to locked items = stop and flag), and classify the change per ORCHESTRATION.md's change classes → that picks the gate.
2. **Land it.** `git cherry-pick <branch>` (range or `merge --no-ff` for multi-commit). Sequential only: land one chunk before dispatching the next so it branches off the landed plumbing.
   **⚠ After ANY interrupted/conflicted sequence: COUNT THE PICKS** — compare landed commits against the branch's commit list; a conflict abort can silently drop a commit (LESSON 20).
3. **Rebuild derived artifacts** the project's typecheck/tests read (ORCHESTRATION.md names them), e.g. a shared package's dist.
4. **Run the class gate — read the REAL result.** Capture output yourself; assert the literal "N passed / 0 failed" line AND a clean exit (LESSON 10). Never run the project's known-flaky full suite; run the changed integration surfaces isolated, one at a time, if the class calls for them.
5. **Verify, don't trust.** "Pre-existing failure", "flake", and "done" are claims — re-run the named suite in isolation yourself (LESSON 13).
6. **Clean up + report.** Prune the landed worktree + branch (leave others alone). Report what landed, the gate lines, and green-ready-to-deploy or the exact failure.
   **⚠ Quote the ON-MAIN SHA, never the builder's** — cherry-pick mints new hashes; re-read `git log origin/main` after the pick. Check: `git branch -r --contains <sha> | grep origin/main` — empty ⇒ worktree-only hash.
