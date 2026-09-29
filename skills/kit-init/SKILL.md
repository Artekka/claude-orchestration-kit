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
   put "$K/templates/AI_CONTEXT.md"    docs/AI_CONTEXT.md
   put "$K/templates/build-log.md"     docs/timeline/build-log.md
   [ -e docs/orchestration/.kit-hooks ] || { printf '%s\n' "# opt-in marker: the orchestration-kit SessionStart hook runs only in repos carrying this file. Delete it to silence the hook." > docs/orchestration/.kit-hooks && echo "CREATE docs/orchestration/.kit-hooks"; }
   for f in lib-launch.sh start-team.sh recycle-sibling.sh ctx-fill.py; do put "$K/scripts/$f" "scripts/$f"; done
   chmod +x scripts/start-team.sh scripts/recycle-sibling.sh scripts/ctx-fill.py
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
7. **Ask to start the team — ONE `AskUserQuestion` call, two questions.** Never run start-team without the answers.

   | Q | Options (first = recommended) |
   |---|---|
   | "Start the team now? You can change the team size, names or permission mode at any time — just ask Claude to change it." | **Seat + 2 siblings (Recommended)** · **Choose how many** (follow up: 1–9) · **Not now** |
   | "Permission mode for the team's sessions?" | **Normal (Recommended)** — asks before risky actions (no flag) · **Auto** — `--permission-mode auto`: Claude Code's automatic permission checks decide instead of prompting · **Accept edits** — `--permission-mode acceptEdits`: file edits approved automatically, commands still ask |

   On a start answer, run it through Bash — say in one line first: "Your OK on the next Bash prompt is the final go-ahead to open the windows."
   ```bash
   bash scripts/start-team.sh --siblings <N> --mode <normal|auto|accept-edits>
   ```
   `--mode` is saved to the `team:` block (`permission_mode:`) so recycles reuse it — commit that change (explicit path). "Not now" → show the same command for later. Not on Windows+WSL → the script prints one `claude --name …` command per window to run by hand.
8. **End-of-setup summary** (print it): files created/skipped · gate + deploy recorded · team started (names, mode) or the command to start it · "talk to the seat window; siblings report to it" · and this line verbatim: **"You can change any of this — team size, names, permission mode, gate or deploy commands — at any time. Just ask Claude to change it."**

## Rules

- Idempotent: never overwrite; re-running reports SKIP for everything that exists.
- The plugin ships the SessionStart hook itself (fresh sessions in a repo with a board are told to orient + send READY) — nothing to install in `.claude/settings.json` for it.
