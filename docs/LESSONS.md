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

## Orchestrated autonomy (harvest 2026-08-19 → 2026-08-21)

16. **Per-session row-ID prefixes — never a shared counter.** "Read the highest and add one"
    is a read-then-write with no lock; sessions append in different places so git never
    conflicts, both ids go live, and a grep returns two unrelated rows that look deliberate.
    Prefix = session tag (`O7-1`, `FQ-2`); collisions become impossible by construction.
    *Provenance:* six manual reconciliations in two days (Einherjar M416).

17. **Milestone/log numbers are allocated through a claimed LOG slot** (same shape as the
    DEPLOY slot). Any shared monotonic counter needs a single allocator while concurrent
    sessions run.

18. **A verify arc of DEVIATES → fix-roundtrip → delta-PASS is the system WORKING.** The
    verifier's findings are the record's most valuable content; a fully green suite can
    still carry spec drift. Roundtrip fixes land at the layer the finding names, falsified
    one-red-each.

19. **Announce resource windows on the board** — gate runs, integration/testcontainer runs,
    deploys, AND dev-stack boots on a shared daemon. A sibling's sweeper, deploy, or
    resource-hungry run is a killer for anything it can't see.

20. **After ANY interrupted cherry-pick / rebase sequence: count the picks.** A conflict
    abort can silently DROP a commit from the sequence; compare landed commits against the
    branch's commit list before declaring the landing complete.
    *Provenance:* a green branch's GREEN commit vanished from a landing mid-sequence
    (Einherjar, 2026-08-21); caught by diffing against the branch tip.

21. **Mutation/falsification commands: one explicit target tree, stderr visible.** Never
    leave earlier path guesses in a compound command; never `2>/dev/null` anything that
    edits files; after restore, diff-verify EVERY tree the command string could have
    reached, not just the one the test reads. And a mutant you haven't diff-verified as
    APPLIED proves nothing.

22. **A change that ADDS test output needs one pass through the real gate stage** — gates
    that classify stage output by pattern make output part of the interface; a realistic
    fixture string in test logs can impersonate an infra-error signal and false-RED every
    session's gate. Capture loggers in tests (and assert they fired); never reword a
    fixture away from the real message to dodge a classifier.

23. **Doc-agent diffs are APPEND-ONLY and fact-checked line-by-line before commit.** A
    delegated log write once replaced a 32k-line institutional log with an 82-line stub,
    with fabricated details; `git diff` deletions must be zero for an append, and every
    factual claim is checked against what actually happened.

24. **Retro-before-clear is a HANDSHAKE.** `/clear` destroys unpersisted context; the retro
    converts it into memories and tied-off state. Order: retro order → the session's
    explicit "retro complete" → only then "safe to clear", one terminal at a time.

25. **No mid-orchestration `/compact`.** Context quality is load-bearing at hand-offs;
    compaction mid-arc loses exactly the correction/decision detail the next phase needs.
    Context pressure → the retro-before-clear handshake instead.

26. **Inserting a step into an ordered, PERSISTED sequence is a migration.** If a cursor
    stores a position and only resolves forward, a mid-list insertion strands everyone
    already past that index — precisely the users it was written to protect. Ship the
    backfill + a guard in the same change. Projects carrying such sequences should elevate
    this into their own CLAUDE.md.
    *Provenance:* a tutorial-step insertion soft-locked the project owner's own account
    (Einherjar TUT-30/31).

27. **Never expose user PII in public channels or shared artifacts** — usernames, emails,
    ids stay out of anything that leaves the project's private surface.
