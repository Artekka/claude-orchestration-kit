# orchestration-kit

Run **several Claude Code sessions on one repo at the same time** without file collisions,
lost work, or confabulated green: a shared claimable board, one git worktree per session,
and every piece of work verified by a session that didn't build it. Proven on the origin
project: three concurrent sessions, ~15 workstreams, one evening, zero collisions.

## Quickstart — two terminals, one repo (5 minutes)

```bash
# 1. Install into your repo (normal shell, not inside Claude; on Windows run `wsl` first)
cd ~/projects/myapp
claude plugin marketplace add Artekka/claude-orchestration-kit
claude plugin install orchestration-kit@artekka-kits --scope project

# 2. Set up the repo — inside Claude; tell it your test command, answer "Not now" to starting a team
claude
/orchestration-kit:kit-init

# 3. Open two sessions (two terminals, both in the repo)
claude --name Dev1 /orchestration-kit:orient
claude --name Dev2 /orchestration-kit:orient
```

```text
Dev1> add rows to the board for: <task A>; <task B>
Dev1> claim Dev1-1 and build it in your own worktree
Dev2> claim Dev1-2 and build it in your own worktree
Dev2> verify Dev1-1 against its row — contract only, don't fix anything
Dev1> /orchestration-kit:reconcile Dev1-1
```

That's **solo mode**: board + cross-verification, you coordinate. Walkthrough, Windows/macOS/Linux
notes and failure modes: **[`docs/GETTING-STARTED.md`](docs/GETTING-STARTED.md)**. Terms:
[`docs/GLOSSARY.md`](docs/GLOSSARY.md).

## Two modes

| Mode | Who coordinates | Start with |
|---|---|---|
| **Solo** (start here) | You, via the board. Sessions claim rows, build in their own worktrees, verify each other's rows | the Quickstart above |
| **Team** (Advanced) | A **seat** session plans, assigns, routes verification, merges one row at a time, deploys in trains, recycles full sessions. You talk only to the seat | `bash scripts/start-team.sh` (opens the seat + 2 siblings) — [GETTING-STARTED §5](docs/GETTING-STARTED.md#5-advanced-team-mode--who-does-what) |

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
| `skills/falsify` | mutation-prove a guard/test can fail: commit GREEN first, diff-verified mutant, prediction written before the run, red observed unfiltered, byte-clean restore, re-green |
| `skills/reconcile` | land one worktree at a time onto main, push merges immediately, re-prove the gate there |
| `skills/retro` | session close-out; in orchestrator mode skips deploy and replies "retro complete" to the seat |
| `skills/post-feature` · `skills/bootstrap-project` | per-feature close-out checklist · bare directory → kit-adopted project |
| `agents/verifier.md` | the read-only verifier subagent (contract-only, four checks, structured verdict) |
| `hooks/` | SessionStart hook: fresh sessions in a repo with a board are told to orient and send READY to the seat; silent no-op elsewhere · `worktree-guard.sh` (PreToolUse on Edit/Write/MultiEdit/NotebookEdit): with `worktrees: enforced` in ORCHESTRATION.md, blocks edits in the main checkout except `docs/orchestration/**`, the log and the status doc; no-op otherwise (the default is `advised`) · `git-guard.sh` (PreToolUse on Bash): with `git_guard: on`, blocks `git stash` (except list/show), `git add -A`/`.`/`--all`, `git commit -a`, `git pull --rebase` with the safe alternative; no-op otherwise (default `off`). Tests: `bash tests/run.sh` |
| `scripts/start-team.sh` | open the seat + N siblings, each in its own window (terminal auto-detected), default names, skips any already running; `--dry-run`, `--terminal <backend>` / `--terminal list` |
| `scripts/recycle-sibling.sh` | open a fresh `claude --name X` window, then SIGTERM the old one; `--dry-run`, `--terminal` |
| `scripts/lib-launch.sh` | the shared launcher both scripts source: detects the terminal backend — `tmux` (already inside tmux), `wsl-wt` / `wsl-conhost` (Windows + WSL), `macos-iterm` / `macos-terminal`, `gitbash-cmd`, `linux-<emulator>` (gnome-terminal, konsole, xfce4-terminal, kitty, alacritty, wezterm, foot, xterm, `$TERMINAL`, x-terminal-emulator), `tmux-detached` (SSH / headless), else `manual` (prints the commands, exits 2). Override: `--terminal` flag > `terminal:` in the team block > auto |
| `scripts/ctx-fill.py` | measure a session's REAL context fill from its transcript |
| `scripts/statusline-ctx.sh` | optional statusline: live context fill vs the 350K/400K marks (yellow = self-report, red = hand over); enable via `templates/settings-snippets.md` |
| `scripts/bootstrap.sh` | the mechanical half of `bootstrap-project` (idempotent, `--dry-run`) |
| `templates/` | `AGENT_BOARD.md` (banner/handover/READY/archive shapes), `ORCHESTRATION.md` (gate, deploy, team, validator, doc paths), `AI_CONTEXT.md` + `build-log.md` (institutional memory), `CLAUDE-section.md`, settings snippet, optional agents + memory starter |
| `docs/GETTING-STARTED.md` | first-timer walkthrough: install → kit-init → seat + siblings → recycling → failure modes |
| `docs/GLOSSARY.md` | the kit's vocabulary (seat, sibling, row, fence, gate, READ, wave train …) |
| `tests/` | `bash tests/run.sh` — git guard (every awk found), statusline, bootstrap idempotency + dry-run |
| `docs/LESSONS.md` | the distilled incident-backed lessons — the upgrade payload |
| `docs/EXAMPLE-SESSION.md` | **a real annotated 12-hour session** — one seat, three sibling builders, two deploy trains, and the six things the seat got wrong |

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

Even when installed more widely, its hooks stay silent unless the repo carries
the opt-in marker `docs/orchestration/.kit-hooks` (created by `kit-init`); the worktree guard
additionally needs `worktrees: enforced`.

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

## The team-mode workflow in one paragraph

The seat takes the board with an `ORCHESTRATOR ACTIVE` banner; siblings `/orchestration-kit:orient` and send
READY. `git fetch origin && git rebase origin/main` → read `docs/orchestration/AGENT_BOARD.md`
→ the seat assigns a row (message + board, disjoint file fences) → the sibling builds in its
**own worktree** (never `git add -A`, never `git stash`) → a **different sibling session**
verifies it against the contract only (PASS required) → the seat reconciles
**one worktree at a time** onto main, re-proving the overlay's gate with the literal
pass line → update the board, release the fence → deploy only via the exclusive DEPLOY
row claim, in wave trains. Full sessions retro, reply "retro complete", and are recycled.
Every rule traces to a paid-for incident — see `docs/LESSONS.md`.

## What's new

v0.5.0: solo mode as the starting path, a git guard hook (on in team mode, off solo), the `falsify` skill, a
context-fill statusline, MIT LICENSE, tests (`bash tests/run.sh`), a glossary, and the worked
example session. Full history: [`CHANGELOG.md`](CHANGELOG.md).

## Assumed plugins (user-level — documented, never copied)

The workflow assumes nothing beyond stock Claude Code. These user-level plugins are
routinely present on the origin setup and complement the kit, but the kit never installs
or requires them: `superpowers` (TDD/debugging discipline), `code-review`, a token/context
hygiene plugin. If a skill here references one, treat it as optional.
