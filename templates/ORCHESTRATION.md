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
slow path:    <the exhaustive gate reserved for pre-deploy, and when it's required>
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
vehicle:      <command or skill, e.g. /deploy | scripts/deploy.sh | gh workflow run deploy>
exclusivity:  claim the DEPLOY row on the board first; one instance at a time
post-deploy:  <how to verify the deploy actually took, e.g. bundle marker / health URL>
```

## Locked

Constants, formulas, fixtures, and files that subagents must NEVER change without the
human's explicit sign-off in-context:

- `<e.g. balance constants in src/constants.ts>`
- `<e.g. golden fixtures>`

## Sessions

```
board path:   docs/orchestration/AGENT_BOARD.md
tag scheme:   <who>@<instance> YYYY-MM-DD HH:MM
```

## Test hazards

Project-specific traps that make a red untrustworthy or a green vacuous:

- `<e.g. integration tests flake under container concurrency — run files one at a time>`
- `<e.g. piping test output masks the exit code — always read the real summary line>`
