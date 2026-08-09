<!-- orchestration-kit v0.1.0 — managed section; upgrades diff against this marker -->
## Multi-session orchestration (orchestration-kit)

This project runs the multi-session claimable-board workflow from the `orchestration-kit`
plugin. The rules that matter:

1. **Before any substantial work:** `git pull`, read `docs/orchestration/AGENT_BOARD.md`,
   claim a row by committed edit (session tag + timestamp) BEFORE starting. Protocol table
   lives in the board file; project specifics live in `docs/orchestration/ORCHESTRATION.md`.
2. **Implementation happens in isolated git worktrees** — one worktree per implementation
   agent, never in main's tree while other sessions are live. **Never `git stash` inside a
   worktree agent** (stash refs are shared across worktrees).
3. **Independent verification at every hand-off** — before a downstream agent consumes an
   upstream agent's output, and automatically for the high-risk change classes in
   `ORCHESTRATION.md`. The verifier gets the contract only (spec + diff), never the
   implementer's reasoning, and it reports — it never fixes.
4. **Reconcile worktrees one at a time** onto main. Run the gate from `ORCHESTRATION.md`
   and read the REAL pass line — never trust exit codes or a subagent's green claim.
5. **Deploys are exclusive** — claim the board's DEPLOY row first.
6. **Locked items** (see `ORCHESTRATION.md` → Locked) need the human's sign-off — never let
   a subagent tune them.
<!-- /orchestration-kit -->
