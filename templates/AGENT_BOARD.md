# Agent Orchestration Board — shared across Claude Code instances

> **What this is:** the live coordination surface for ALL Claude sessions working on
> this repo at the same time. Read it AFTER the project's orientation docs, BEFORE
> claiming any work. Any instance may edit it; every edit must be committed promptly
> (`chore(orchestration): update board`) so other instances' `git pull` sees it.
> Uncommitted board edits WILL be swept into someone else's deploy commit — commit them yourself first.
>
> Project-specific values (gate command, deploy vehicle, change classes, locked areas)
> live in `ORCHESTRATION.md` next to this file — the protocol below is generic.

## Protocol (mandatory)

| Rule | Why |
|---|---|
| **Read the board, then claim by editing it** — add your session tag + timestamp to a row BEFORE starting. | Two instances fixing the same bug wastes work and can double-edit files. |
| **One owner per row. One isolated git worktree per implementation agent.** | Non-isolated agents write main's tree and collide. |
| **File-ownership column is a hard fence.** Don't edit files owned by an open row you don't own. | Reconcile conflicts are the #1 cross-session failure. |
| **Independent verification at every hand-off** (auto for the high-risk change classes in `ORCHESTRATION.md`). | A sibling impl+QA pair can confabulate the same wrong belief; only an independent verifier catches it. |
| **Reconcile worktrees ONE AT A TIME onto main**, never in parallel. | Sequential landings are what keep concurrent sessions from losing work. |
| **Run the project's trusted gate** (see `ORCHESTRATION.md` → Gate), never a known-flaky full suite. | Infra-flake red is untrustworthy signal and wastes everyone's time. |
| **Deploys are exclusive.** Claim the DEPLOY row before deploying; only one instance deploys at a time. | Racing a deploy corrupts the cutover. |
| **Locked constants / spec-locked formulas need the human's sign-off** — never let a subagent "tune" them. | Silent balance/contract drift is worse than a missing feature. |
| **NEVER `git stash` inside a worktree agent** (prove RED via commit + soft-reset, or copy files to a scratchpad). | Stash refs are SHARED across all worktrees — two agents stashing concurrently pop each other's WIP. |
| Done? Set status, note the verifier verdict + real gate summary, release the fence. | The board is only useful if it reflects reality. |

**Session tag format:** `<who>@<instance> YYYY-MM-DD HH:MM` (e.g. `alpha 2026-08-08 19:40`).

## Statuses

`OPEN` → `CLAIMED` → `BUILDING` (worktree) → `VERIFY` (independent verification) → `RECONCILE` → `ON MAIN` → `DEPLOYED`.
`BLOCKED(<on what>)` allowed anywhere.

---

## Live board — last updated: <session tag>

### In flight (owned by <session> — do NOT touch their files)

| Row | Task | Status | Worktree agent | File ownership (fence) |
|---|---|---|---|---|
| A1 | <task> | CLAIMED <tag> | <model>, isolated worktree | <exact files / file regions this row owns> |

### Open (unclaimed — safe for another instance to take)

| Row | Task | Notes |
|---|---|---|
| O1 | <task> | <context, pointers, suspected cause> |

### Recently landed (context for merges)

- <SHA> <what landed, verifier verdict, gate summary>

---

## How a fresh instance uses this board

1. Orient (project docs + `ORCHESTRATION.md`).
2. `git pull`, read this file at HEAD.
3. Pick an OPEN row (or add one from the human's ask), edit status → CLAIMED with your session tag, **commit the board edit**.
4. Dispatch an isolated-worktree implementation agent with a brief that includes the row's file fence.
5. On completion: independent verify → update row (verdict + gate lines) → reconcile (one at a time) → update row → commit board.
6. Deploy only via the DEPLOY row's claim.
