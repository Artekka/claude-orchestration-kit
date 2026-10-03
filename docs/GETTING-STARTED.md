# Getting started — solo mode first, then a seat + siblings

For someone who today opens a terminal and runs `claude` in one repo — on **Windows (WSL),
macOS or Linux**. Two paths, in this order:

1. **Solo mode (start here)** — two Claude sessions on one repo, coordinated by a shared board,
   each one's work checked by the other. You are the coordinator. ([§3](#3-start-small-solo-mode-two-terminals-no-seat))
2. **Team mode (Advanced)** — one **seat** (an orchestrator session you talk to) plans, assigns,
   verifies and merges for two or more **siblings** (builders), each in its own window.

New words (seat, sibling, row, fence, gate …) are defined in [`GLOSSARY.md`](GLOSSARY.md).

## 0. What you need

- **Windows (WSL), macOS or Linux**, with Claude Code installed (`claude --version` works in
  your terminal; on Windows, inside WSL).
- A git repo (e.g. `~/projects/myapp`) with a remote you can push to.
- The launch script picks how to open windows on your machine — see the per-OS notes below.
- **A recent Claude Code** — run `claude update` first. The seat and siblings talk to each other
  with Claude Code's **built-in** SendMessage / ListAgents tools (nothing to install); they are
  newer features, so an old version may not have them.

### Windows (WSL)

You open **CMD**, type `wsl`, and run `claude` inside WSL. Claude Code must be installed
**inside WSL** (`claude --version` works after `wsl`). Keep the repo in the Linux filesystem
(`~/…`), not under `/mnt/c/…`, and with no spaces in its path — git and worktrees are much
faster there, and the Windows launcher requires it. Windows open in **Windows Terminal** if you
have it, else in plain console windows.

Git Bash without WSL also works, less well: windows open as `cmd.exe` consoles, but Git Bash
has no `pgrep`, so the scripts can't see which sessions are running — recycling opens the fresh
window and asks you to close the old one yourself.

### macOS

Use Terminal or iTerm2. Windows open in **iTerm2** when you run the setup from iTerm2 (or it's
running), else in **Terminal**. The first time, macOS asks whether your terminal may control
Terminal/iTerm2 ("automation" permission) — allow it, or no windows appear.

### Linux

On a desktop session, windows open in your terminal emulator: `$TERMINAL` if you set it, else
the first one found of x-terminal-emulator, gnome-terminal, konsole, xfce4-terminal, kitty,
alacritty, wezterm, foot, xterm.

### Over SSH, headless, or already in tmux

If you run the setup **inside tmux**, each session opens as a new tmux window (on any OS). Over
**SSH** or on a machine with no desktop, the sessions open in a detached tmux session named
after the repo — attach with `tmux attach -t <repo-name>` (the script prints the exact
command). No tmux installed → the script prints one command per window for you to run.

To see what your machine supports: `bash scripts/start-team.sh --terminal list`. To pick one
yourself, ask Claude ("open the team in tmux"), set `terminal:` in the `team:` block of
`docs/orchestration/ORCHESTRATION.md`, or pass `--terminal <backend>`.

## 1. Install the plugin (once)

In a terminal (on Windows: a WSL terminal), **from inside the repo you want to use it in**
(type these at the normal `$` prompt, not inside Claude):

```bash
cd ~/projects/myapp
claude plugin marketplace add Artekka/claude-orchestration-kit
claude plugin install orchestration-kit@artekka-kits --scope project
```

`--scope project` turns the kit on for **this repo only** — your other projects are
untouched. (Use `--scope local` instead if you don't want the setting committed for
collaborators.) Repeat the `install` line inside any other repo you want it in.
Already inside Claude? The same commands work as `/plugin marketplace add …` and
`/plugin install …`; restart Claude afterwards.

## 2. Set up your repo (once per repo)

Open **one** terminal in the repo and start Claude. On Windows, that's one CMD window:

```
wsl
cd ~/projects/myapp
claude
```

On macOS or Linux: `cd ~/projects/myapp && claude`.

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

Last, it asks **three questions** — whether to start the team now (and how many siblings),
which permission mode the sessions should use, and whether separate worktrees per session are
advised or enforced. The git guard (below) follows your first answer: **on** if you start a
team, **off** for solo mode.

**Solo mode (recommended first time):** answer **Not now** to starting the team, pick the other
two, and continue at [§3](#3-start-small-solo-mode-two-terminals-no-seat).

**Team mode (Advanced):** answer with a team size, approve the one command it runs,
and the windows open: **Orca** (the seat) and **Sib1**, **Sib2** (siblings). The setup summary
says how they open on your machine ("Windows will open via: …"). You can close the setup session.

**Start with 1 seat + 2 siblings.** You can change the team size, names, permission mode or worktree setting at
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

**Worktrees: advised vs enforced** (saved as `worktrees:` in the same `team:` block). Either way,
every session is instructed to work in its own git worktree, so two sessions never edit the same
checkout at once.

- **Advised** (recommended) — the instruction only; nothing blocks an edit. Pick this if your
  workflow deliberately shares one tree or file between agents (pairing two sessions on one
  branch, a helper agent writing into the tree another session owns, one-person repos), or while
  you learn the workflow.
- **Enforced** — a hook blocks file edits in the main checkout, so a session that forgot to
  create its worktree is stopped and told how. The board, the log and the status doc stay
  editable in place (they are committed within seconds by design), as does anything outside the
  repo. Pick this once several sessions run at the same time and a stray edit on main has cost
  you work.

Switch any time by asking Claude ("enforce worktrees", "make worktrees advised again"), or by
editing `worktrees:` in `docs/orchestration/ORCHESTRATION.md`. It takes effect on the next edit.

**Git guard: on in team mode, off in solo mode** (saved as `git_guard:` in the same `team:`
block; kit-init sets it from your start answer). Four git habits that
are harmless alone damage other sessions' work in a shared repo:

| Blocked when on | Why | Claude is told to use |
|---|---|---|
| `git stash` (except `list` / `show`) | Stashes are shared by every worktree; a pop can take another session's work | commit WIP on its branch, or copy to a scratch dir |
| `git add -A` / `--all` / `.` / `-u` with no paths | Stages other sessions' uncommitted files | `git add <explicit paths>` |
| `git commit -a` / `--all` | Same, at commit time | `git add <paths> && git commit` |
| `git pull --rebase` | Races on the shared `.git/FETCH_HEAD` | `git fetch origin && git rebase origin/main` |

It only reads Claude's Bash commands (quoted text and commit messages that merely *mention* these
are fine); you can still run anything yourself in your own terminal. Change it with "turn on the
git guard" / "turn off the git guard", or `git_guard: on|off`.

Started "Not now", or want to reopen missing windows? Run `bash scripts/start-team.sh` (or ask
Claude to). Sessions already running are skipped; `--dry-run` previews without opening anything.

## 3. Start small: solo mode (two terminals, no seat)

The board and independent verification are most of the value; the seat is an add-on. Run two
sessions yourself and let the board keep them apart:

```bash
# Terminal 1 (on Windows: `wsl` first)
cd ~/projects/myapp && claude --name Dev1 /orchestration-kit:orient
# Terminal 2
cd ~/projects/myapp && claude --name Dev2 /orchestration-kit:orient
```

Then type, in plain language:

| Where | You say | What happens |
|---|---|---|
| Dev1 | "add rows to the board for: fix the login timeout; add CSV export" | Rows `Dev1-1`, `Dev1-2` appear on `docs/orchestration/AGENT_BOARD.md`, committed + pushed |
| Dev1 | "claim Dev1-1 and build it in your own worktree" | Claims the row (with a file fence), works on its own branch |
| Dev2 | "claim Dev1-2 and build it in your own worktree" | Same, with a fence that doesn't overlap |
| Dev2 (when Dev1 is done) | "verify Dev1-1 against its row — contract only, don't fix anything" | Dev2 never saw Dev1's reasoning, so it checks the work against the row, not against the author's intent. Or run `/orchestration-kit:verify-feature` |
| Dev1 (after PASS) | "/orchestration-kit:reconcile Dev1-1" | Lands the branch on main, re-runs your gate, closes the row |

Rules that make this safe (the sessions already know them): each session edits in its own git
worktree, stages explicit paths, never stashes, and verifies the *other* session's rows, never
its own. When a session's context fills, run `/orchestration-kit:retro` in it, then `/clear`
and `/orchestration-kit:orient`.

**Ready for more?** Move to team mode when you're the bottleneck — relaying between windows,
deciding who takes what. Say "turn on the git guard" (team mode's default), then
`bash scripts/start-team.sh` opens a seat + siblings; the rest of this
page covers it.

## 4. What you get

| Piece | What it is |
|---|---|
| `/orchestration-kit:orchestrate` | The seat's loop — plans, assigns, verifies, merges, deploys, recycles |
| `/orchestration-kit:orient` | A fresh session catches up and tells the seat it's READY |
| `/orchestration-kit:board` | Claiming, updating and archiving board rows |
| `/orchestration-kit:falsify` | Prove a new test or guard can actually fail (mutation check) before trusting it |
| `/orchestration-kit:reconcile` | Merging one finished worktree onto main and re-running the gate |
| `/orchestration-kit:retro` | Closing a session: lessons saved, board updated, work committed |
| `/orchestration-kit:verify-feature` | Subagent verification — fallback when no sibling is free to verify |
| `/orchestration-kit:post-feature` · `/orchestration-kit:kit-init` · `/orchestration-kit:bootstrap-project` | Per-feature checklist · repo setup · new-project setup |
| SessionStart hook (automatic) | Every fresh session in a repo with a board is told to orient and report to the seat. Silent in other repos |
| Worktree guard (PreToolUse hook) | Only with `worktrees: enforced`: blocks edits in the main checkout except board/log/status files. Silent otherwise |
| Git guard (PreToolUse hook on Bash) | Only with `git_guard: on`: refuses `git stash`, `git add -A` / `.`, `git commit -a`, `git pull --rebase` and tells Claude the safe command. Silent otherwise |
| `docs/orchestration/AGENT_BOARD.md` | The shared board: who is doing what, and which files they own |
| `docs/orchestration/ORCHESTRATION.md` | Your project's settings: gate, deploy, team names, doc paths |
| `docs/AI_CONTEXT.md` · `docs/timeline/build-log.md` | Status doc (read first by every session) · append-only history |
| `scripts/start-team.sh` · `scripts/recycle-sibling.sh` · `scripts/ctx-fill.py` | Open the team · replace a full session · measure a session's context |
| Memory | Automatic: Claude Code keeps per-project memory under `~/.claude/projects/…/memory/`; `retro` saves lessons there |

## 5. Advanced: team mode — who does what

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

**Check the sessions can hear each other** (once, after the windows open): in the seat window ask
*"list the other Claude sessions"*. If it names Sib1, Sib2 … messaging works. If it doesn't,
run `claude update` in each window and restart the team. Even without messaging the workflow
still runs — the board file (`docs/orchestration/AGENT_BOARD.md`) is the guaranteed channel:
siblings post `AVAILABLE` / status lines there and the seat reads it. It's just slower, because
nobody gets pinged.

## 6. Recycling when a session fills up

Long sessions degrade as their context fills. The kit replaces them cleanly instead of `/compact`.

1. Each session measures itself with `python3 scripts/ctx-fill.py`. On a 1M-token model it
   self-reports around **350K** and hands over by **400K** (200K model: ~120K / ~150K; tell it which with `--window 1m|200k`).
   Optional: show it permanently in the status bar — add
   `"statusLine": { "type": "command", "command": "bash scripts/statusline-ctx.sh" }` to
   `.claude/settings.json` (or ask Claude: "add the context statusline"). It turns yellow at the
   self-report mark and red at handover.
2. The seat tells that sibling to retro. The sibling saves lessons, updates the board,
   commits, and replies **"retro complete"**.
3. The seat runs `bash scripts/recycle-sibling.sh Sib1 --model 'sonnet[1m]'` (the model for
   that lane; see "Model per lane" below): a **new window** opens with a fresh
   Sib1, and only then is the old one closed. It opens the same way `start-team.sh` does on
   your machine (Windows Terminal, Terminal/iTerm2, your Linux emulator, or a tmux window).
4. The seat recycles itself the same way after writing a handover note on the board. If the
   script can't run, the seat asks you to type `/clear` in that window and then
   `/orchestration-kit:orient` (siblings) or `/orchestration-kit:orchestrate` (seat).

### Model per lane

Not every row needs your strongest model, and a fresh session must never start on whatever model the
old terminal happened to have. The seat picks a model **by work type** when it launches a session:

| Work | Model |
|---|---|
| Heavy reasoning and verification (core logic, migrations, security, money, every READ of those), the seat, the validator | `opus[1m]` |
| Routine features, UI, plumbing, test-only fixes | `sonnet[1m]` |
| Docs, board/log edits, mechanical sweeps | `haiku` (the small model never writes facts) |

`scripts/recycle-sibling.sh <Name> --model <m> [--effort <e>]` and `scripts/start-team.sh --model <m>`
always pass the model explicitly. Change the default for every launch with `model:` in the team block
of `docs/orchestration/ORCHESTRATION.md`. A bad value exits 64 before anything launches; `--dry-run`
prints the model and effort. Bounded one-off jobs (a search, a mechanical sweep) can be subagents; long
builds and every verification are sessions. Details: the orchestrate skill, "Model per lane".

### Lean start for a builder

The seat writes a **brief file** per row (`docs/orchestration/briefs/<ROW>.md`, from
`templates/briefs/_TEMPLATE.md`) and the builder starts with `/orchestration-kit:orient --brief <ROW>`:
the brief + the board banner, then READY. A full orient reads a whole project to learn one row; the
brief is the row. Keep `CLAUDE.md` slim too (`templates/CLAUDE-slimness.md`): it is re-read on every
turn of every session.

## 7. Common failure modes

| Symptom | Cause → fix |
|---|---|
| Siblings sit idle; the seat says nobody is ready | Siblings end orientation with a READY message. Tell the sibling: "send READY to the seat" |
| No new windows appear | Run `bash scripts/start-team.sh --dry-run` to see which terminal it picked and why; `--terminal list` shows the alternatives. On macOS, allow the "automation" prompt. Over SSH / tmux-detached: `tmux attach -t <repo-name>`. Still nothing → see Advanced, open them by hand |
| Sessions keep asking for permission | That's Normal mode. Ask Claude to "switch the team to auto permissions", or say yes in each window |
| `start-team.sh` exits 2 | It found no terminal it can open windows in (no WSL, tmux, macOS, desktop emulator). It prints the `claude --name …` command for each window — run them by hand, or install tmux |
| `Cannot rebase onto multiple branches` | Someone used `git pull --rebase`. Use `git fetch origin && git rebase origin/main` |
| `cannot lock ref 'refs/remotes/origin/main'` | Two sessions fetched at once. Harmless — run it again |
| Your edit shows up inside someone else's commit | Someone ran `git add -A` or edited outside a worktree. Stage explicit paths only |
| Work disappeared after `git stash pop` | Stashes are shared between worktrees. Never stash; commit instead |
| Tests green in a sibling, red on main | The gate ran from the wrong folder. Run it from inside your own worktree |
| A session gets vague or repeats itself | Context is full. Measure with `ctx-fill.py`; retro and recycle |

## 8. Changing things later

Nothing here is fixed. Ask Claude — in the seat's window, or any Claude session in the repo —
and it will make the change for you. For example:

| You say | What changes |
|---|---|
| "make it 3 siblings" | `siblings:` in the `team:` block; `start-team.sh` opens Sib3 |
| "switch the team to normal permissions" | `permission_mode:` in the `team:` block; applies to sessions opened from then on |
| "open the team in tmux" / "use iTerm" | `terminal:` in the `team:` block (`tmux`, `tmux-detached`, `macos-iterm`, … or `auto`) |
| "enforce worktrees" / "make worktrees advised" | `worktrees:` in the `team:` block; takes effect on the next edit |
| "turn on the git guard" / "turn off the git guard" | `git_guard:` in the `team:` block; takes effect on the next command |
| "rename the siblings to Worker1…" | `prefix:` in the `team:` block (then recycle the old windows) |
| "our tests run with `make check` now" | the Gate section of `docs/orchestration/ORCHESTRATION.md` |
| "deploy with `npm run release`" | the Deploy section of `ORCHESTRATION.md` |
| "add a column for reviewer to the board" | `docs/orchestration/AGENT_BOARD.md` layout |
| "make orient also read docs/ARCHITECTURE.md" | a project-level copy of the skill in `.claude/skills/` |

## 9. Advanced / customize

- **Other names, sizes or modes:** `bash scripts/start-team.sh --seat Lead --prefix Dev --siblings 3 --mode auto`,
  or set them once in the `team:` block of `docs/orchestration/ORCHESTRATION.md`.
- **Opening a session by hand** (no automatic windows, e.g. native Windows without WSL): one terminal per session,
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
