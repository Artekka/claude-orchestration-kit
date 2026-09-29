# Project Orchestration Config — the overlay the kit's skills read

> Generic protocol lives in the kit (`orchestration-kit` plugin) and in `AGENT_BOARD.md`'s
> protocol table. THIS file holds everything project-specific. Every kit skill reads this
> file first and defers to it. Keep it short, keep it true.

## Gate

The trusted fast verification command(s) and what a REAL pass looks like.

```
command:      <e.g. pnpm gate | make check | cargo test --workspace>
pass proof:   <the literal summary line to assert, e.g. "Tests N passed / 0 failed" per suite —
               NEVER trust exit code alone; a chained clean run can mask an earlier failure>
never run:    <known-flaky full-suite commands and WHY, e.g. "full parallel test — container storm">
slow path:    <the exhaustive gate reserved for pre-deploy / before a train, and when it's required>
run from:     INSIDE your own worktree (a script that cd's to its own dir gates the tree it lives in)
```

## Change classes

Path patterns → risk class → extra gate + verifier escalation. Classes listed here as
high-risk get an AUTO independent verification before reconcile.

| Path pattern | Class | Extra gate | Verifier model |
|---|---|---|---|
| `<e.g. src/engine/**>` | `<e.g. golden-critical>` | `<e.g. goldens byte-identical>` | strongest available |
| `<e.g. **/migrations/**, schema files>` | `migration` | `<boot/constraint check>` | strongest available |
| `<e.g. billing/auth paths>` | `economy` / `security` | `<value/path tracing>` | strongest available |
| everything else | `standard` | — | default strong model |

## Deploy

```
vehicle:      <the ONE command the seat runs for a wave train, e.g. make deploy | gh workflow run deploy>
exclusivity:  claim the DEPLOY slot on the board first; under an ORCHESTRATOR ACTIVE banner only the seat deploys
post-deploy:  <how to verify the deploy actually took, e.g. bundle marker / health URL>
```

## Locked

Constants, formulas, fixtures, and files that subagents must NEVER change without the
human's explicit sign-off in-context:

- `<e.g. balance constants in src/constants.ts>`
- `<e.g. golden fixtures>`

## Sessions

```
board path:     docs/orchestration/AGENT_BOARD.md
archive dir:    docs/orchestration/archive/   (BOARD_ARCHIVE_<YYYY-MM-DD>.md; archive past ~60 KB)
tag scheme:     <Name> [<ref>]  — Name = the terminal's `claude --name`, ref = from ListAgents
context marks:  1M window: self-report ~350K, hand over by ~400K · 200K window: ~140K / ~160K
                measure: python3 scripts/ctx-fill.py [--window N]   (never bytes ÷ 4)
start team:     bash scripts/start-team.sh [--dry-run] [--siblings N]   (skips names already running)
recycle:        bash scripts/recycle-sibling.sh <Name> [prompt]         (Windows+WSL; else /clear by hand)
```

Team names — optional; `scripts/start-team.sh` reads this block (flags override it; without it
the defaults are seat `Orca`, siblings `Sib1`..`Sib2`). Keep the `team:` line unindented and the
keys indented:

```
team:
  seat:      Orca
  prefix:    Sib
  siblings:  2
```

## Docs (institutional memory)

```
status doc:   docs/AI_CONTEXT.md           # what orient reads first: current state, deferred work
log:          docs/timeline/build-log.md   # append-only: Edit (append after the last lines), NEVER Write
memory:       Claude Code's auto-memory (~/.claude/projects/<slug>/memory/) — created by Claude Code; retro writes lessons there
```

## Validator seat

A sibling that NEVER builds — it only READs (verifies), re-reads fix rounds, verifies trains,
falsifies guards, and measures. Independent of every row because it built none of them.

```
validator:      <e.g. Check — or "none: any non-builder sibling READs">
lanes:          READ · re-read · train/merge verification · falsification · measurement
never:          build or fix rounds (a validator that builds loses its independence)
```

## Test hazards

Project-specific traps that make a red untrustworthy or a green vacuous:

- `<e.g. integration tests flake under container concurrency — run files one at a time>`
- `<e.g. piping test output masks the exit code — always read the real summary line>`
