# Getting started — from one Claude session to a seat + siblings

For someone who today opens **CMD**, types `wsl`, and runs `claude` inside WSL. After this page
you will run one **seat** (the orchestrator you talk to) and two **siblings** (builders) on
the same repo, each in its own window, without them stepping on each other. No names to
type, no settings to edit.

## 0. What you need

- Windows with WSL (Ubuntu or similar) and Claude Code installed **inside WSL**
  (`claude --version` works after `wsl`).
- A git repo inside WSL (e.g. `~/projects/myapp`) with a remote you can push to.
- Keep the repo in the Linux filesystem (`~/…`), not under `/mnt/c/…`, and with no spaces
  in its path — git and worktrees are much faster there, and the launch scripts require it.

## 1. Install the plugin (once)

In a WSL terminal:

```bash
claude plugin marketplace add Artekka/claude-orchestration-kit
claude plugin install orchestration-kit@artekka-kits
```

(`install` defaults to `--scope user`, so it's available in every repo.)

## 2. Set up your repo and start the team (once per repo)

Open **one** CMD window:

```
wsl
cd ~/projects/myapp
claude
```

In that Claude session run:

```
/orchestration-kit:kit-init
```

It creates the board, your project settings, the status doc and log, and the launch scripts,
and asks you a few questions:

| It asks | Example answer |
|---|---|
| Gate command + the line that proves it passed | `npm test` → `Tests: 42 passed, 0 failed` |
| Deploy command (or "none") | `npm run deploy` |
| A validator (optional) | "none" for now |
| Locked files (optional) | `src/pricing.ts` |

Last, it asks **two questions** — whether to start the team now (and how many siblings), and
which permission mode the sessions should use. Answer them, approve the one command it runs,
and the windows open: **Orca** (the seat) and **Sib1**, **Sib2** (siblings). You can close the
setup session.

**Start with 1 seat + 2 siblings.** You can change the team size, names or permission mode at
any time — just ask Claude to change it.

**Permission modes** (saved in `docs/orchestration/ORCHESTRATION.md`, so recycled sessions reopen the same way):

- **Normal** (recommended) — each session asks you before risky actions, in its own window.
  Safest while you learn the workflow.
- **Auto** (`--permission-mode auto`) — Claude Code's automatic permission checks decide most
  actions instead of prompting you, so the team runs with fewer interruptions.
- **Accept edits** (`--permission-mode acceptEdits`) — file edits are approved automatically;
  commands still ask.

Change it later by asking Claude ("switch the team to normal permissions"), by editing
`permission_mode:` in the `team:` block, or with `bash scripts/start-team.sh --mode auto`.
It applies to sessions opened from then on.

Started "Not now", or want to reopen missing windows? Run `bash scripts/start-team.sh` (or ask
Claude to). Sessions already running are skipped; `--dry-run` previews without opening anything.

## 3. What you get

| Piece | What it is |
|---|---|
| `/orchestration-kit:orchestrate` | The seat's loop — plans, assigns, verifies, merges, deploys, recycles |
| `/orchestration-kit:orient` | A fresh session catches up and tells the seat it's READY |
| `/orchestration-kit:board` | Claiming, updating and archiving board rows |
| `/orchestration-kit:reconcile` | Merging one finished worktree onto main and re-running the gate |
| `/orchestration-kit:retro` | Closing a session: lessons saved, board updated, work committed |
| `/orchestration-kit:verify-feature` | Subagent verification — fallback when no sibling is free to verify |
| `/orchestration-kit:post-feature` · `/orchestration-kit:kit-init` · `/orchestration-kit:bootstrap-project` | Per-feature checklist · repo setup · new-project setup |
| SessionStart hook (automatic) | Every fresh session in a repo with a board is told to orient and report to the seat. Silent in other repos |
| `docs/orchestration/AGENT_BOARD.md` | The shared board: who is doing what, and which files they own |
| `docs/orchestration/ORCHESTRATION.md` | Your project's settings: gate, deploy, team names, doc paths |
| `docs/AI_CONTEXT.md` · `docs/timeline/build-log.md` | Status doc (read first by every session) · append-only history |
| `scripts/start-team.sh` · `scripts/recycle-sibling.sh` · `scripts/ctx-fill.py` | Open the team · replace a full session · measure a session's context |
| Memory | Automatic: Claude Code keeps per-project memory under `~/.claude/projects/…/memory/`; `retro` saves lessons there |

## 4. Who does what

| Seat (Orca) | Siblings (Sib1, Sib2, …) |
|---|---|
| Talks to **you**. Give it tasks in plain language | Talk to the seat, not to you |
| Turns tasks into board rows, each with a file "fence" | Build one row at a time in their **own git worktree** |
| Assigns rows so fences never overlap | Report at milestones: claimed → failing test → passing → done |
| Picks a **different** sibling to verify each finished row | Verify each other's rows when asked (never their own) |
| Merges rows onto main **one at a time**, runs the gate | Never merge to main, never deploy |
| Deploys in batches ("wave trains"), keeps the log | Send any question or permission prompt to the seat |
| Asks you for decisions and approvals — all in its window | — |

Your job: talk to the seat window. You can ignore the sibling windows — if a sibling needs
you, the seat says so.

## 5. Recycling when a session fills up

Long sessions degrade as their context fills. The kit replaces them cleanly instead of `/compact`.

1. Each session measures itself with `python3 scripts/ctx-fill.py`. On a 1M-token model it
   self-reports around **350K** and hands over by **400K** (200K model: ~140K / ~160K).
2. The seat tells that sibling to retro. The sibling saves lessons, updates the board,
   commits, and replies **"retro complete"**.
3. The seat runs `bash scripts/recycle-sibling.sh Sib1`: a **new window** opens with a fresh
   Sib1, and only then is the old one closed. Windows Terminal is used if you have it, a plain
   console window otherwise.
4. The seat recycles itself the same way after writing a handover note on the board. If the
   script can't run, the seat asks you to type `/clear` in that window and then
   `/orchestration-kit:orient` (siblings) or `/orchestration-kit:orchestrate` (seat).

## 6. Common failure modes

| Symptom | Cause → fix |
|---|---|
| Siblings sit idle; the seat says nobody is ready | Siblings end orientation with a READY message. Tell the sibling: "send READY to the seat" |
| No new windows appear | Re-run `bash scripts/start-team.sh` (it falls back to plain console windows). Still nothing → see Advanced, open them by hand |
| Sessions keep asking for permission | That's Normal mode. Ask Claude to "switch the team to auto permissions", or say yes in each window |
| `start-team.sh` exits 2 | You're not in WSL. It prints the `claude --name …` command for each window — run them by hand |
| `Cannot rebase onto multiple branches` | Someone used `git pull --rebase`. Use `git fetch origin && git rebase origin/main` |
| `cannot lock ref 'refs/remotes/origin/main'` | Two sessions fetched at once. Harmless — run it again |
| Your edit shows up inside someone else's commit | Someone ran `git add -A` or edited outside a worktree. Stage explicit paths only |
| Work disappeared after `git stash pop` | Stashes are shared between worktrees. Never stash; commit instead |
| Tests green in a sibling, red on main | The gate ran from the wrong folder. Run it from inside your own worktree |
| A session gets vague or repeats itself | Context is full. Measure with `ctx-fill.py`; retro and recycle |

## 7. Changing things later

Nothing here is fixed. Ask Claude — in the seat's window, or any Claude session in the repo —
and it will make the change for you. For example:

| You say | What changes |
|---|---|
| "make it 3 siblings" | `siblings:` in the `team:` block; `start-team.sh` opens Sib3 |
| "switch the team to normal permissions" | `permission_mode:` in the `team:` block; applies to sessions opened from then on |
| "rename the siblings to Worker1…" | `prefix:` in the `team:` block (then recycle the old windows) |
| "our tests run with `make check` now" | the Gate section of `docs/orchestration/ORCHESTRATION.md` |
| "deploy with `npm run release`" | the Deploy section of `ORCHESTRATION.md` |
| "add a column for reviewer to the board" | `docs/orchestration/AGENT_BOARD.md` layout |
| "make orient also read docs/ARCHITECTURE.md" | a project-level copy of the skill in `.claude/skills/` |

## 8. Advanced / customize

- **Other names, sizes or modes:** `bash scripts/start-team.sh --seat Lead --prefix Dev --siblings 3 --mode auto`,
  or set them once in the `team:` block of `docs/orchestration/ORCHESTRATION.md`.
- **Opening a session by hand** (other OS, or no automatic windows): one terminal per session,
  in the repo:
  ```
  claude --name Orca /orchestration-kit:orchestrate        # add --permission-mode auto etc. after the name
  claude --name Sib1 /orchestration-kit:orient
  claude --name Sib2 /orchestration-kit:orient
  ```
  `--name` (long form, first) is required: sessions message each other by that name, and the
  scripts find a running session by matching `claude --name <Name>`. Keep names one word.
- **A dedicated validator:** add a sibling that only verifies and never builds, and name it
  in ORCHESTRATION.md → Validator seat. It is independent of every row by construction.
- **Upgrading the plugin:** `claude plugin marketplace update artekka-kits`, then
  `claude plugin update orchestration-kit@artekka-kits`, restart sessions, and re-run
  `/orchestration-kit:kit-init` (it only adds what's missing).
- Further reading: `skills/orchestrate/SKILL.md` (the seat's loop) and `docs/LESSONS.md`
  (why each rule exists).
