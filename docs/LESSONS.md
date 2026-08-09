# Distilled Lessons — why the protocol is shaped this way

Each rule below was paid for by a real incident. New lessons land here (with provenance)
and ship to every consuming project on the next kit upgrade — that propagation is the
kit's whole reason to exist.

## Coordination

1. **Claim before work; one owner per row; file fences are hard.**
   *Provenance:* three concurrent sessions partitioned ~15 workstreams in one evening with
   zero file collisions — only because every row carried an explicit file fence and claims
   were committed before work started (Einherjar, 2026-08-08).

2. **Worktree isolation for every implementation agent.** Concurrent sessions and their
   subagents never share main's working tree; non-isolated agents silently co-edit files.
   *Provenance:* Einherjar memory `feedback_isolate_worktree_for_concurrent_sessions`.

3. **NEVER `git stash` inside a worktree agent.** Stash refs are SHARED across all
   worktrees of a repo; two agents stashing concurrently popped each other's WIP. Prove a
   RED state via `git commit` + `git reset --soft`, or copy files to a scratchpad.
   *Provenance:* Einherjar B1/B2 stash collision, 2026-08-08.

4. **Sequential reconciles; exclusive deploy.** Land one worktree at a time onto main;
   claim the DEPLOY row before deploying. Parallel landings lose work; racing a deploy
   corrupts the cutover.
   *Provenance:* Einherjar M376/M377 two-session coordination.

5. **Commit board edits immediately.** Uncommitted board state is invisible to other
   sessions and gets swept into someone else's commit.

6. **Stale status docs cause duplicate rebuilds.** A "BUILD pending" line for work that
   was actually finished on a branch nearly caused a full re-implementation. When work
   lands somewhere non-obvious (a held branch), the status doc must say so, with the
   branch name and the reason it's held.
   *Provenance:* Einherjar ADR-0041 near-miss, 2026-08-08.

## Verification

7. **Independent verify at every hand-off edge.** A sibling implementation+test pair can
   confabulate the SAME wrong belief — wrong code + wrong test agree, and TDD shows green
   that means nothing. The verifier receives the contract only (spec + diff), never the
   implementer's reasoning, and judges against canonical ground truth (the spec/ADR/
   constants), never against a sibling's test.
   *Provenance:* Einherjar memory `feedback_multiagent_false_green_trace_semantics`.

8. **The verifier reports; it never edits.** A verifier that "helpfully" fixes masks the
   drift it exists to catch.

9. **No vacuous green.** A check that found nothing wrong and a check that ran on nothing
   are indistinguishable unless you assert the match/population count — "0 failed" out of
   0 run is not a pass.

10. **Read the REAL pass line, unpiped.** Pipes mask exit codes; a background-task
    completion notification masks a failing exit; a process can print its pass summary and
    then crash in teardown. Assert the literal "N passed / 0 failed" summary AND a clean
    exit, from output you captured yourself.
    *Provenance:* Einherjar memories `feedback_pipe_masks_exit_code`,
    `feedback_background_test_notification_masks_exit`.

11. **Gate red ≠ code red.** Know the project's infra-flake modes (e.g. one test
    container per file saturating Docker) and encode the trusted gate + the never-run
    commands in `ORCHESTRATION.md`. An untrustworthy red wastes every session's time.

12. **Gate green ≠ boots.** Unit-green says nothing about schema/seed/boot integrity;
    migrations need a boot or constraint check in the gate for their change class.
    *Provenance:* Einherjar memory `feedback_gate_green_but_boot_crashloops`.

13. **Re-verify subagent claims at reconcile.** "Pre-existing failure", "flake", and
    "done" are claims, not facts, until the reconciler re-runs the named suite in
    isolation and sees it with its own eyes.
    *Provenance:* Einherjar memory `feedback_verify_subagent_failure_claims`.

## Scope discipline

14. **Locked constants / spec-locked formulas need the human's sign-off.** Subagents get
    the list of locked items in their brief and treat it as read-only.
    *Provenance:* Einherjar memory `feedback_guard_locked_constants_from_subagents`.

15. **The board is institutional memory at the hand-off grain.** Closed rows keep their
    verifier verdict, real gate lines, and released fences — the next session's context
    starts there.
