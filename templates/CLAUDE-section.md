<!-- orchestration-kit v0.3.0 — managed section; upgrades diff against this marker -->
## Multi-session orchestration (orchestration-kit)

This project runs the multi-session claimable-board workflow from the `orchestration-kit`.
Protocol table lives in the board file; project specifics in `docs/orchestration/ORCHESTRATION.md`.

### The non-negotiables

1. **Every piece of work happens in its own worktree** — the main thread's edits included.
   Docs/board edits happen in a worktree too, or are committed within seconds. Never
   `git add -A` / `git commit -a` in the shared checkout (a wildcard add annexes a sibling's
   live WIP); never `git stash` (stash refs are shared across worktrees). A dirty status you
   didn't cause is a sibling at work — leave it alone.
2. **Refresh the board before claiming, always:** `git fetch origin && git pull --rebase origin main`,
   then re-read the board; claim by committed + PUSHED edit before starting. Verify the row
   against the CODE (an OPEN status is a hypothesis) and treat the row's proposed fix as a
   hypothesis too — correcting a brief upward is expected.
3. **New board rows carry a per-session prefix** (`<tag>-1`, `<tag>-2` …), numbered within
   your own session. NEVER read the board's highest id and add one — that read-then-write
   has no lock, git can't catch the collision, and both ids go live.
4. **Independent verification at every hand-off** — before a downstream agent consumes an
   upstream agent's output, and automatically for the high-risk change classes in
   ORCHESTRATION.md. Contract only (spec + diff), never the implementer's reasoning; the
   verifier reports, it never fixes.
5. **Reconcile one worktree at a time** onto main; run the class gate and read the REAL
   pass line. After any interrupted cherry-pick sequence, count the picks. Quote on-main
   SHAs, never worktree hashes.
6. **Deploys are exclusive** — claim the board's DEPLOY slot in writing BEFORE running.
   Log/milestone numbers are allocated through the LOG slot the same way. Announce resource
   windows (gate/integration/container runs, deploys, shared-daemon dev stacks) on the board.
7. **Locked items** (ORCHESTRATION.md → Locked) need the human's sign-off — never let a
   subagent tune them.

### Orchestrator-led mode

When the board carries an **`ORCHESTRATOR ACTIVE`** banner: one session coordinates, the
others build. Planned-work row IDs, log numbers, version bumps, and the DEPLOY + LOG slots
are minted/held by the orchestrator only (mid-task discoveries keep your own prefix).
Deploys are wave trains — hand finished rows to reconcile and message the orchestrator;
never self-deploy. Fresh sessions report availability to the orchestrator instead of asking
the human for work. Context lifecycle is a handshake: the orchestrator orders "run /retro
now"; only your explicit "retro complete" reply makes your terminal safe to clear.

### Testing gate (fill per project in ORCHESTRATION.md)

Use the project's layered gate, never its known-flaky full suite. Verify the printed pass
summary yourself — exit codes lie through pipes and background-task notifications. If the
gate prints which tree it gated, read that line. A change that ADDS test output gets one
pass through the real gate stage before hand-off.

### Context discipline

Never `/compact` mid-orchestration — compaction loses exactly the correction/decision
detail the next phase needs. Context pressure → the retro-before-clear handshake instead.

### Skill authoring (applies to new skills here)

A skill's SKILL.md loads fully into context on every invocation — author as a terse schema:
frontmatter → H1 → step headers → fenced commands → tables for mappings. One-line "why" per
non-obvious step; war stories go to memory files, linked by slug. Compress rationale, never
commands, flags, guards, or pass/fail assertions.

### Doc routine

After every meaningful chunk: the doc agent appends a log entry AND refreshes the status doc
(version, test count, deferred list) in the SAME pass — coupled so they can't drift. Its
diff must be append-only for the log and fact-checked line-by-line before commit.
<!-- /orchestration-kit -->
