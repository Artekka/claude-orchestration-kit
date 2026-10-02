# Multiple Claude Code accounts (optional)

**Skip this unless** you have more than one Claude Code account and want one team to use them all,
for example to keep building on account 2 while account 1's usage resets. One account needs none of this.

Check your plan's terms before you run several subscriptions. This page only covers the mechanics.

## How it works

Claude Code has no `--account` flag. It reads its login and config from one directory: `~/.claude`
by default, or whatever the **`CLAUDE_CONFIG_DIR`** environment variable points to. Each account
gets its own directory, and you pick the account by setting that variable when you start a session.

| Account | Config dir | Start it with |
|---|---|---|
| 1 (default) | `~/.claude` | `claude` |
| 2 | `~/.claude-acct2` | `claude2` (alias below) |
| 3 | `~/.claude-acct3` | `claude3` |

The scripts use the `~/.claude-acctN` convention: `--account 2` means `~/.claude-acct2`.
A full path works too.

## Set up account N (example: 2)

**1. Make the directory and an alias** (bash/zsh; add the alias to `~/.bashrc` or `~/.zshrc`):
```bash
mkdir -p ~/.claude-acct2
alias claude2='CLAUDE_CONFIG_DIR=$HOME/.claude-acct2 claude'
```

**2. Log in:** run `claude2`, then `/login`, and choose the second account. `/status` shows which
account a session is on. On Linux/WSL the login lands in `~/.claude-acct2/.credentials.json`; on
macOS it goes in the Keychain.

**3. Share what the team needs.** Repo files (`CLAUDE.md`, `.claude/skills`, hooks, the board) work
on every account automatically. Your user-level pieces live in the config directory, so link or
copy them. **Close every account-2 session first.**
```bash
cp ~/.claude/settings.json ~/.claude-acct2/settings.json          # copy: permissions, plugins, statusline
ln -s ~/.claude/sessions ~/.claude-acct2/sessions                 # shared session registry (see below)
ln -s ~/.claude/projects ~/.claude-acct2/projects                 # shared memories + transcripts
ln -s ~/.claude/skills   ~/.claude-acct2/skills                   # user-level skills
ln -s ~/.claude/agents   ~/.claude-acct2/agents                   # user-level agents
```
- **Never share `.credentials.json`.** That file is what keeps the accounts apart.
- `settings.json` is a **copy**, so one account's permission change can't silently change the
  other. Re-copy it when you change it on purpose.
- Plugins may need re-installing or re-authenticating per account.
- ⚠ `ln -s` onto a directory that **already exists** puts the link *inside* it
  (`projects/projects`) instead of replacing it. Remove or merge the real directory first, then
  link. Merge example: `cp -rn ~/.claude-acct2/projects/. ~/.claude/projects/`.

**4. Check:**
```bash
ls -la ~/.claude-acct2 | grep -E 'sessions|projects'
# both lines must show  ->  /home/you/.claude/...   (no arrow = still a separate directory)
```

## Why `sessions` is the link that matters

Sessions find each other through a **registry**: each running session writes `<pid>.json` (with its
message socket) into `<config dir>/sessions/`. `ListAgents` / `/list-agents` read only their own
account's registry. So without the link, an account-2 sibling is invisible to an account-1 seat,
and the seat can't send it work or receive its READY. The sockets themselves live in one per-user
place. Once the registry is shared, discovery and messaging work across accounts both ways
(verified: account-1 seat → account-2 sibling PING/PONG).

The board works regardless, so it stays the fallback channel.

## Launching and recycling on a chosen account

Both scripts take `--account N|DIR`:
```bash
scripts/start-team.sh --account 2                 # the whole team on account 2
scripts/recycle-sibling.sh Sib3 --account 2       # move Sib3 to account 2
scripts/recycle-sibling.sh Sib3                   # no flag: Sib3 STAYS on whatever account it was on
scripts/recycle-sibling.sh --dry-run Sib3         # shows "account  ..." and the exact command
```
- **Inheritance:** a recycle reads the old session's `CLAUDE_CONFIG_DIR` from its process
  environment (`/proc/<pid>/environ` on Linux/WSL, `ps eww` on macOS) and relaunches on the same
  account. `--account 1` forces the default.
- **Refusals (exit 64):** a missing directory; a directory with no login (Linux/WSL: no
  `.credentials.json`); a path containing spaces or `; " ' % ^ & | < >`, which the terminal
  command lines can't carry.
- **Labels (optional):** put one line in `<config dir>/ACCOUNT`, e.g. `acct2 · work`, and the
  scripts print it instead of the path. Don't put anything private in it: it is printed to
  terminals and logs.
- Aliases don't exist inside scripts, so the scripts set `CLAUDE_CONFIG_DIR=...` directly. That
  is exactly what `claude2` does. It's an environment assignment, not a program argument, so
  session detection (`pgrep -f "^claude --name <Name>"`) is unchanged. On Git Bash the cmd.exe
  form is `set CLAUDE_CONFIG_DIR=<win path>&& claude ...`.

## Working the seat across accounts

- **Report the account with fill.** A READY signal can add `· acct2`, so the seat knows which
  sessions draw on which usage pool.
- **Spread by headroom.** When one account nears its limit, recycle its idle siblings onto
  another with `--account N` after their retro, as usual.
- **Context-fill tooling** (`ctx-fill.py`, the statusline) reads transcripts under `projects/`,
  so it works for every account once `projects` is linked.
