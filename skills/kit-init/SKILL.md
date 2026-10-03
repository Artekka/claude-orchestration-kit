---
name: kit-init
description: Initialize a project for the multi-session orchestration workflow — scaffold the shared AGENT_BOARD, the ORCHESTRATION.md project overlay, the institutional-memory docs (AI_CONTEXT + build log), the session scripts (start-team, recycle-sibling, ctx-fill), and (with approval) the CLAUDE.md starter section. Use on any project adopting the orchestration-kit, when the user says "set up the board", "init the orchestration kit", "make this project multi-session ready". Idempotent — safe to re-run; never overwrites an existing file.
---

# kit-init

Scaffold a repo for the seat + siblings workflow. Sources: `${CLAUDE_PLUGIN_ROOT}/templates/` and `${CLAUDE_PLUGIN_ROOT}/scripts/`. **Every file is created only if missing** — an existing board, overlay, log, status doc or script is live state, never scaffolding.

## Steps

1. **Copy what's missing** (prints CREATE/SKIP per file):
   ```bash
   K="${CLAUDE_PLUGIN_ROOT}"
   put() { if [ -e "$2" ]; then echo "SKIP   $2 (exists)"; else mkdir -p "$(dirname "$2")" && cp "$1" "$2" && echo "CREATE $2"; fi; }
   put "$K/templates/AGENT_BOARD.md"   docs/orchestration/AGENT_BOARD.md
   put "$K/templates/ORCHESTRATION.md" docs/orchestration/ORCHESTRATION.md
   put "$K/templates/briefs/README.md" docs/orchestration/briefs/README.md
   put "$K/templates/briefs/_TEMPLATE.md" docs/orchestration/briefs/_TEMPLATE.md
   put "$K/templates/AI_CONTEXT.md"    docs/AI_CONTEXT.md
   put "$K/templates/build-log.md"     docs/timeline/build-log.md
   [ -e docs/orchestration/.kit-hooks ] || { printf '%s\n' "# opt-in marker: the orchestration-kit SessionStart hook runs only in repos carrying this file. Delete it to silence the hook." > docs/orchestration/.kit-hooks && echo "CREATE docs/orchestration/.kit-hooks"; }
   for f in lib-launch.sh start-team.sh recycle-sibling.sh ctx-fill.py statusline-ctx.sh; do put "$K/scripts/$f" "scripts/$f"; done
   chmod +x scripts/start-team.sh scripts/recycle-sibling.sh scripts/ctx-fill.py scripts/statusline-ctx.sh
   ```
   If the overlay names different doc paths (ORCHESTRATION.md → Docs), use those instead.
2. **Fill the overlay** (only if just created) — infer candidates from the repo (`package.json` scripts, `Makefile`, CI config), then ASK the human to confirm: gate command + pass-proof line, never-run commands, deploy vehicle (or "none"), validator seat (optional), locked items. Never silently guess a gate. Leave the `team:` block at its defaults unless the human wants other names.
3. **Write AI_CONTEXT.md** (only if just created) — never leave it a template.
   **First ask, once — ONE `AskUserQuestion`:** "No orientation doc found. How should I learn this project?" → **Search the project (Recommended)** · **I'll give you an outline** (a file path, or paste it in your reply) · **Both — my outline first, then check it against the project**. With an outline: read it, treat it as the human's word on purpose/priorities, and verify its factual claims (paths, commands, versions) against the repo — the repo wins on facts, flag any mismatch. The doc you then write is the record, so this question never repeats.
   Survey (search path, or to check an outline):
   ```bash
   ls; cat README* CLAUDE.md 2>/dev/null | head -200      # purpose, setup, conventions
   ls package.json pyproject.toml Cargo.toml go.mod Makefile 2>/dev/null   # stack + scripts
   find . -maxdepth 2 -type d -not -path './.git*' -not -path '*/node_modules*' | head -60
   ls docs .github/workflows 2>/dev/null; git log --oneline -30; git tag --sort=-v:refname | head -3
   ```
   Fill EVERY section: version (tag/manifest), test count (one gate run, literal pass line), what works, in flight (open branches), architecture quick-ref (path → what it is), deferred work (TODO/FIXME hotspots, open issues if visible). Mark anything inferred-not-verified `(unverified)`. Ask the human ONE `AskUserQuestion` for what the repo can't tell you: top priority right now + working-style preferences (offer "skip"). Also append the first log entry: `Milestone 1 — <date>: adopted orchestration-kit (baseline: <version>, <test line>)`.
4. **CLAUDE.md section** — offer to append `templates/CLAUDE-section.md` (managed block `<!-- orchestration-kit vX -->`). Requires the human's yes; no CLAUDE.md → offer to create it with just this section. Marker already present → diff against the new template and propose the delta.
5. **Memory** — nothing to create. Claude Code makes its auto-memory (`~/.claude/projects/<slug>/memory/`) itself; `/orchestration-kit:retro` writes lessons there.
6. **Commit** — stage exactly the paths reported CREATE (never `git add -A`), `git commit -m "chore(orchestration): adopt orchestration-kit vX"`, `git push`.
7. **Ask to start the team — ONE `AskUserQuestion` call, three questions.** Never run start-team without the answers.
   First detect the terminal backend (no question — shown in the summary; override later with `terminal:` in the team block):
   ```bash
   bash scripts/start-team.sh --dry-run --siblings 0 | grep -E '^(backend|reason) '   # backend + why it was picked
   ```

   | Q | Options (first = recommended) |
   |---|---|
   | "Start the team now? You can change the team size, names, permission mode or worktree setting at any time — just ask Claude to change it." | **Seat + 2 siblings (Recommended)** · **Choose how many** (follow up: 1–9) · **Not now** |
   | "Permission mode for the team's sessions?" | **Normal (Recommended)** — asks before risky actions (no flag) · **Auto** — `--permission-mode auto`: Claude Code's automatic permission checks decide instead of prompting · **Accept edits** — `--permission-mode acceptEdits`: file edits approved automatically, commands still ask |
   | "Separate worktrees per session? Sessions are instructed to use their own worktree either way; some workflows deliberately share one tree or file between agents, so enforcement is optional." | **Advised (Recommended)** — every session is told to use its own worktree, but nothing blocks it · **Enforced** — a hook blocks edits in the main checkout except board/log files |

   On a start answer, run it through Bash — say in one line first: "Your OK on the next Bash prompt is the final go-ahead to open the windows."
   ```bash
   bash scripts/start-team.sh --siblings <N> --mode <normal|auto|accept-edits>
   ```
   `--mode` is saved to the `team:` block (`permission_mode:`) so recycles reuse it — commit that change (explicit path). "Not now" → show the same command for later. Backend `manual` (nothing here can open windows) → say so, and instead of launching show the per-window commands from `bash scripts/start-team.sh --siblings <N> --mode <mode> --dry-run` (`by hand` lines): one terminal each, in the repo. `tmux-detached` → also tell the human `tmux attach -t <session>` (the script prints it).
   Persist the worktree answer, and set the git guard **from the start answer — no question**: a team start (seat + 1–9 siblings) → `git_guard: on`; **Not now** (solo mode) → `git_guard: off`. Then commit that path:
   ```bash
   C=docs/orchestration/ORCHESTRATION.md
   setkey() {  # <key> <value>
     if grep -Eq "^[[:space:]]+$1:" "$C"; then sed -i -E "s/^([[:space:]]+$1:[[:space:]]*).*/\1$2/" "$C"
     elif grep -q '^team:[[:space:]]*$' "$C"; then sed -i "/^team:[[:space:]]*\$/a\  $1:        $2" "$C"
     else printf '\nteam:\n  %s:        %s\n' "$1" "$2" >> "$C"; fi
   }
   setkey worktrees <advised|enforced>; setkey git_guard <on if a team was started, else off>
   git add "$C" && git commit -m "chore(orchestration): worktrees + git_guard settings"
   ```
   Both take effect at once: the plugin's PreToolUse hooks read the file on every call (only in repos with `.kit-hooks`).
8. **End-of-setup summary** (print it): files created/skipped · gate + deploy recorded · "Windows will open via: <backend> (change any time — just ask Claude)" (for `manual`: "Windows can't be opened automatically here — run these commands, one terminal each:" + the commands) · team started (names, mode) or the command to start it · "talk to the seat window; siblings report to it" · "Each session is instructed to work in its own worktree; this is [advised/enforced] — change it any time by asking Claude." (fill in the answer) · "Risky git commands (stash, add -A, commit -a, pull --rebase) are [blocked — on by default in team mode/not blocked — off in solo mode; say "turn on the git guard" when you add more sessions] — change it any time by asking Claude." · and this line verbatim: **"You can change any of this — team size, names, permission mode, gate or deploy commands — at any time. Just ask Claude to change it."**

## Rules

- Idempotent: never overwrite; re-running reports SKIP for everything that exists.
- The plugin ships its hooks itself — nothing to install in `.claude/settings.json`: SessionStart (fresh sessions are told to orient + send READY) PreToolUse `worktree-guard.sh` (a no-op unless `worktrees: enforced`) and PreToolUse `git-guard.sh` on Bash (a no-op unless `git_guard: on`). All run only in repos carrying `.kit-hooks`.
