# orchestration-kit

Run **multiple Claude Code sessions on one repo at the same time** — each dispatching
parallel isolated-worktree subagents — without file collisions, lost work, or
confabulated green. Proven on Einherjar/Camelot Tactics: three concurrent sessions,
~15 workstreams, one evening, zero collisions.

This repo is a Claude Code **plugin** and its own **marketplace** (`artekka-kits`).
A project "depends" on the kit the way it depends on a package: install it, get the
workflow; upgrade it, get the newly distilled lessons.

## What's inside

| Piece | What it does |
|---|---|
| `skills/kit-init` | `/orchestration-kit:kit-init` — scaffold a project (board + overlay + CLAUDE.md section), idempotent |
| `skills/board` | claim/update/close rows on the shared board, fence discipline |
| `skills/verify-feature` | independent context-isolated verification at hand-offs |
| `skills/reconcile` | land one worktree at a time onto main, re-prove the gate there |
| `skills/orient` | five-bullet session orientation for kit-adopted projects |
| `agents/verifier.md` | the read-only verifier subagent (contract-only, four checks, structured verdict) |
| `templates/` | `AGENT_BOARD.md`, `ORCHESTRATION.md` (project overlay), `CLAUDE-section.md` |
| `docs/LESSONS.md` | the distilled incident-backed lessons — the upgrade payload |

**Generic vs project-specific:** the kit never hardcodes a gate or deploy command.
Project specifics live in the consuming repo's `docs/orchestration/ORCHESTRATION.md`
(created by kit-init); every kit skill reads it first. That split is what makes lessons
portable: they land here once and every project pulls them on upgrade.

## Install

One-time, user level (Art's default — available in every project):

```bash
claude plugin marketplace add Artekka/claude-orchestration-kit   # or the local path
claude plugin install orchestration-kit@artekka-kits --scope user
```

Then, in each project: run `/orchestration-kit:kit-init` once and commit the scaffolding.

Per-project (self-describing repo — teammates/machines get the plugin offered
automatically) — add to the project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "artekka-kits": {
      "source": { "source": "github", "repo": "Artekka/claude-orchestration-kit" }
    }
  },
  "enabledPlugins": { "orchestration-kit@artekka-kits": true }
}
```

## Upgrade

```bash
claude plugin marketplace update artekka-kits
claude plugin update orchestration-kit
```

Read `CHANGELOG.md` for what changed. New lessons/hardenings = minor bump. A breaking
board-format/protocol change = major bump with a migration note. After upgrading, re-run
`/orchestration-kit:kit-init` in a project to be offered the template deltas (managed
markers keep your customizations safe).

## The workflow in one paragraph

`git pull` → read `docs/orchestration/AGENT_BOARD.md` at HEAD → claim a row by
**committed** board edit (session tag, file fence) → dispatch an isolated-worktree
implementation agent with the fence in its brief (never `git stash` in a worktree) →
independent `verify-feature` at the hand-off (contract only; PASS required) → reconcile
**one worktree at a time** onto main, re-proving the overlay's gate with the literal
pass line → update the board, release the fence → deploy only via the exclusive DEPLOY
row claim. Every rule traces to a paid-for incident — see `docs/LESSONS.md`.
