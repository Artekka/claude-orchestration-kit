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
| `scripts/start-team.sh` | open the seat + N siblings, each in its own window (terminal auto-detected), default names, skips any already running; `--dry-run`, `--terminal <backend>` / `--terminal list`, `--model` / `--effort` (always passed explicitly) |
| `scripts/recycle-sibling.sh` | replace a session with a fresh `claude --name X`: **in the same tab** when it runs under `sibling-shell.sh`, else a new window first and then SIGTERM the old one (`--new-tab` forces that); `--dry-run` (prints `mode:`), `--terminal`, `--account` (keeps each session on its own Claude Code account), `--model` / `--effort` (always passed, never inherited: the lane picks the model) |
| `scripts/sibling-shell.sh` | the respawn loop every tab the kit opens runs: starts `claude` as a child and, when `recycle-sibling.sh` leaves it a hand-off file, starts the next one in the same tab (crash-loop guard: two instant exits in a row stop it) |
| `scripts/lib-launch.sh` | the shared launcher both scripts source: detects the terminal backend — `tmux` (already inside tmux), `wsl-wt` / `wsl-conhost` (Windows + WSL), `macos-iterm` / `macos-terminal`, `gitbash-cmd`, `linux-<emulator>` (gnome-terminal, konsole, xfce4-terminal, kitty, alacritty, wezterm, foot, xterm, `$TERMINAL`, x-terminal-emulator), `tmux-detached` (SSH / headless), else `manual` (prints the commands, exits 2). Override: `--terminal` flag > `terminal:` in the team block > auto |
| `scripts/ctx-fill.py` | measure a session's REAL context fill from its transcript; `--window 1m\|200k` picks the marks (350K/400K on 1M, 120K/150K on 200K); a Haiku transcript implies 200K |
| `scripts/statusline-ctx.sh` | optional statusline: live context fill vs the 350K/400K marks (120K/150K on a 200K window) (yellow = self-report, red = hand over); enable via `templates/settings-snippets.md` |
| `scripts/bootstrap.sh` | the mechanical half of `bootstrap-project` (idempotent, `--dry-run`) |
| `templates/` | `AGENT_BOARD.md` (banner/handover/READY/archive shapes), `ORCHESTRATION.md` (gate, deploy, team, validator, doc paths), `AI_CONTEXT.md` + `build-log.md` (institutional memory), `CLAUDE-section.md`, `CLAUDE-slimness.md` (keep the always-loaded file slim), `briefs/` (row brief template + README), settings snippet, optional agents + memory starter |
| `docs/GETTING-STARTED.md` | first-timer walkthrough: install → kit-init → seat + siblings → recycling → failure modes |
| `docs/MULTI-ACCOUNT.md` | **optional:** run one team across several Claude Code accounts — `CLAUDE_CONFIG_DIR` per account, the shared session registry that makes cross-account messaging work, `--account` on both launch scripts |
| `docs/GLOSSARY.md` | the kit's vocabulary (seat, sibling, row, fence, gate, READ, wave train …) |
| `tests/` | `bash tests/run.sh` — git guard (every awk found), statusline, bootstrap idempotency + dry-run, multi-account launch, model/effort launch flags, ctx-fill marks |
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

v0.7.0: recycling in place. A recycled session now restarts in the SAME terminal tab (a respawn wrapper, `scripts/sibling-shell.sh`, runs
every tab the kit opens), with a fresh context, an explicit model and its own account. A session started by hand moves over at
its next recycle. See "Recycling in place" below.
v0.6.0: a model per lane (`--model` / `--effort` on both launch scripts, always passed, never inherited),
lean builder starts (`/orchestration-kit:orient --brief <ROW>` from a brief file), per-window context marks
(120K/150K on a 200K window), optional multi-account teams, and a note on keeping `CLAUDE.md` slim.
v0.5.0: solo mode as the starting path, a git guard hook (on in team mode, off solo), the `falsify` skill, a
context-fill statusline, MIT LICENSE, tests (`bash tests/run.sh`), a glossary, and the worked
example session. Full history: [`CHANGELOG.md`](CHANGELOG.md).

## Recycling in place (v0.7.0)

`start-team.sh` and `recycle-sibling.sh` open each tab running `scripts/sibling-shell.sh <Name>`, which runs `claude` as its child. To
recycle, `recycle-sibling.sh <Name>` leaves the wrapper a small hand-off file (model, effort, permission mode, account, prompt) under
`~/.orchestration-kit/sessions/`, SIGTERMs only the old `claude`, and the wrapper starts the fresh one in the same tab. Same tab, no
stray windows, and nothing the old context held is lost, because a recycle only runs after the session replied "retro complete".
It opens a new tab instead (running the wrapper, so that session recycles in place next time) when there is no old process, the old
one was started by hand, you pass `--new-tab`, the machine has no `setsid` (macOS) and the seat is recycling itself, or the in-place
attempt times out (60 s; `RECYCLE_INPLACE_TIMEOUT`). The seat can recycle itself in place: the script prints a log path
(`~/.orchestration-kit/sessions/<Name>.recycle.log`), hands the work to a detached copy of itself and exits, and the copy ends the seat's
session about 2 s later (`RECYCLE_DETACH_DELAY`) so the seat's last command finishes first. `--dry-run` prints `mode: in-place` or `mode: new-tab`, and `detach: yes|no` for a self-recycle. `LAUNCH_NO_WRAPPER=1` opens tabs with a bare
`claude` as before.

**What is tested where.** The in-place path reads the process tree, so it needs `pgrep`: it is tested on Linux (and WSL), including
the `ps` code path that macOS uses (forced with `LAUNCH_NO_PROC=1`), but it has **not been run on a real Mac or in Git Bash**. Git
Bash (no `pgrep`) and the `manual` backend keep launching a bare `claude` and the old new-window recycle. On WSL a kit path that
contains a space cannot cross the `wt.exe` command line, so those tabs fall back to a bare `claude` too.

## Assumed plugins (user-level — documented, never copied)

The workflow assumes nothing beyond stock Claude Code. These user-level plugins are
routinely present on the origin setup and complement the kit, but the kit never installs
or requires them: `superpowers` (TDD/debugging discipline), `code-review`, a token/context
hygiene plugin. If a skill here references one, treat it as optional.
