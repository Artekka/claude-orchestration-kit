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
| `skills/retro` | session close-out: board close-out, lesson distillation (upstream to LESSONS.md), status refresh, clean-handoff check |
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

## v0.3.0 — the orchestrated-autonomy port

New since v0.2.0 (extracted from the 2026-08-20/21 Orchestrated-Autonomy pilot: 20+ rows,
8 production releases, 15+ independent verifier runs across a 4-session fleet):

- **`orchestrate`** — the active-orchestrator operating loop: seat-taking via board banner,
  single-allocator rules (row IDs, LOG slot, DEPLOY slot, versions), briefed-row intake,
  dependency-DAG assignment, phase-boundary tracking, verify-gated hand-offs, wave-train
  deploys, doc-agent logging, and the retro-before-clear sibling lifecycle handshake.
- **`bootstrap-project`** — super-init: bare directory → fully kit-adopted project in one
  pass, driven by `scripts/bootstrap.sh` (idempotent, `--dry-run`). Offers the settings
  snippets (SessionStart hook + auto-compact off) as ONE approval-gated step.
- **`post-feature`** — the coupled log+status-doc close-out checklist.
- **Refreshed** `orient` / `reconcile` / `retro` / `verify-feature` / `board` with the
  pilot's protocol: per-session row prefixes, LOG slot, resource-window announcements,
  count-the-picks, on-main-SHA discipline, banner-aware branches.
- **`templates/agents/`** — an optional generic team set (orchestrator, architect,
  backend-dev, frontend-dev, qa-lead, devops, tech-writer). **Precedence note:** user-level
  agent definitions with the same names WIN day-to-day; project copies exist for machines
  and collaborators without them, and install only with `--with-team-agents`, only when
  missing.
- **`templates/memory-starter/`** — 31 curated agnostic memories (30 ported + 1 canonical merge) (working-style + process;
  ratified 2026-08-21). Project FACTS and STANDING PERMISSIONS were deliberately excluded —
  a trust grant never ports to a fresh project by default.
- **`extras/`** — take-or-leave skills outside the orchestration core (currently
  `backfill`: guarded, lineage-preserving prod data surgery). Not installed by bootstrap.
- **LESSONS 16–27** — the pilot's harvest.

## Assumed plugins (user-level — documented, never copied)

The workflow assumes nothing beyond stock Claude Code. These user-level plugins are
routinely present on the origin setup and complement the kit, but the kit never installs
or requires them: `superpowers` (TDD/debugging discipline), `code-review`, a token/context
hygiene plugin. If a skill here references one, treat it as optional.
