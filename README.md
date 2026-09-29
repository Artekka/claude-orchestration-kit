# orchestration-kit

Run **multiple Claude Code sessions on one repo at the same time** — each dispatching
parallel isolated-worktree subagents — without file collisions, lost work, or
confabulated green. Proven on the origin project: three concurrent sessions,
~15 workstreams, one evening, zero collisions.

**New here? Start with [`docs/GETTING-STARTED.md`](docs/GETTING-STARTED.md)** — one page
from "I run one Claude session in WSL" to a seat + two siblings.

This repo is a Claude Code **plugin** and its own **marketplace** (`artekka-kits`).
A project "depends" on the kit the way it depends on a package: install it, get the
workflow; upgrade it, get the newly distilled lessons.

## What's inside

| Piece | What it does |
|---|---|
| `skills/kit-init` | `/orchestration-kit:kit-init` — scaffold a project (board + overlay + scripts + CLAUDE.md section), idempotent |
| `skills/orchestrate` | the seat loop: banner, single-allocator, briefed rows, DAG + disjoint fences, sibling-session verification, one-at-a-time reconcile, wave-train deploys, LOG slot, sibling + seat recycling, approvals through the seat |
| `skills/orient` | session orientation: multi-session non-negotiables, five-bullet state, READY signal to the seat |
| `skills/board` | claim/update/close rows, per-session prefixes, the shared-checkout write recipe, status-not-narrative + archiving |
| `skills/verify-feature` | subagent verification — the fallback when no independent sibling session is free |
| `skills/reconcile` | land one worktree at a time onto main, push merges immediately, re-prove the gate there |
| `skills/retro` | session close-out; in orchestrator mode skips deploy and replies "retro complete" to the seat |
| `skills/post-feature` · `skills/bootstrap-project` | per-feature close-out checklist · bare directory → kit-adopted project |
| `agents/verifier.md` | the read-only verifier subagent (contract-only, four checks, structured verdict) |
| `hooks/` | SessionStart hook: fresh sessions in a repo with a board are told to orient and send READY to the seat; silent no-op elsewhere |
| `scripts/start-team.sh` | Windows+WSL: open the seat + N siblings, each in its own window, default names, skips any already running; `--dry-run` |
| `scripts/recycle-sibling.sh` | Windows+WSL: open a fresh `claude --name X` window, then SIGTERM the old one; `--dry-run` |
| `scripts/lib-launch.sh` | the shared launcher both scripts source (distro / main checkout / wt.exe detection, conhost fallback) |
| `scripts/ctx-fill.py` | measure a session's REAL context fill from its transcript |
| `scripts/bootstrap.sh` | the mechanical half of `bootstrap-project` (idempotent, `--dry-run`) |
| `templates/` | `AGENT_BOARD.md` (banner/handover/READY/archive shapes), `ORCHESTRATION.md` (gate, deploy, team, validator, doc paths), `AI_CONTEXT.md` + `build-log.md` (institutional memory), `CLAUDE-section.md`, settings snippet, optional agents + memory starter |
| `docs/GETTING-STARTED.md` | first-timer walkthrough: install → kit-init → seat + siblings → recycling → failure modes |
| `docs/LESSONS.md` | the distilled incident-backed lessons — the upgrade payload |

**Generic vs project-specific:** the kit never hardcodes a gate or deploy command.
Project specifics live in the consuming repo's `docs/orchestration/ORCHESTRATION.md`
(created by kit-init); every kit skill reads it first. That split is what makes lessons
portable: they land here once and every project pulls them on upgrade.

## Install

Per repo (recommended — the kit is active only in the repos you install it into).
Run from inside the repo:

```bash
claude plugin marketplace add Artekka/claude-orchestration-kit   # or a local path
claude plugin install orchestration-kit@artekka-kits --scope project   # or --scope local
```

Even when installed more widely, its SessionStart hook stays silent unless the repo carries
the opt-in marker `docs/orchestration/.kit-hooks` (created by `kit-init`).

Then, in each project: run `/orchestration-kit:kit-init` once (it copies the scripts into
`scripts/`), then `bash scripts/start-team.sh`. Step by step: [`docs/GETTING-STARTED.md`](docs/GETTING-STARTED.md).

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

The seat takes the board with an `ORCHESTRATOR ACTIVE` banner; siblings `/orchestration-kit:orient` and send
READY. `git fetch origin && git rebase origin/main` → read `docs/orchestration/AGENT_BOARD.md`
→ the seat assigns a row (message + board, disjoint file fences) → the sibling builds in its
**own worktree** (never `git add -A`, never `git stash`) → a **different sibling session**
verifies it against the contract only (PASS required) → the seat reconciles
**one worktree at a time** onto main, re-proving the overlay's gate with the literal
pass line → update the board, release the fence → deploy only via the exclusive DEPLOY
row claim, in wave trains. Full sessions retro, reply "retro complete", and are recycled.
Every rule traces to a paid-for incident — see `docs/LESSONS.md`.

## v0.4.0 — the seat + siblings upgrade

- **`orchestrate` rewritten** around sibling-SESSION verification (no self-reads, no mutual
  pairs, report to the seat, DERIVED vs CONSISTENCY-CHECKED), a never-builds validator seat,
  READY-signal rosters, the shared-checkout board-write recipe, push-merges-immediately,
  seat context self-check with measured fill, and all human approvals routed through the seat.
- **Zero-setup team:** kit-init asks two questions (start now? permission mode?) and opens the
  team; `start-team.sh` opens the seat + siblings with default names (no `--name` typing) in
  normal / auto / accept-edits mode, remembered for recycles; the plugin's own SessionStart hook points every fresh session at
  `/orchestration-kit:orient` + READY; all launch prompts and cross-references use the
  namespaced skill names that actually resolve.
- **Scripts:** `start-team.sh` + `recycle-sibling.sh` on one shared launcher (`lib-launch.sh`:
  Windows+WSL, conhost fallback, `--dry-run`), and `ctx-fill.py` (real context fill; refuses to
  guess the session).
- **Institutional memory scaffolded:** kit-init creates `docs/AI_CONTEXT.md` and an
  append-only `docs/timeline/build-log.md`; orient reads them, retro/orchestrate append with
  Edit (never Write). Lessons go to Claude Code's own auto-memory.
- **Git hardening across skills/templates:** `fetch && rebase origin/main` instead of
  `pull --rebase` (shared FETCH_HEAD race), HEAD + index guards for board writes, gate from
  your own worktree, board = status with dated verbatim archives.
- **`docs/GETTING-STARTED.md`** and LESSONS 28–41.

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
