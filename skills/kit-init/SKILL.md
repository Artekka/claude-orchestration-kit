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
   for f in lib-launch.sh start-team.sh recycle-sibling.sh ctx-fill.py; do put "$K/scripts/$f" "scripts/$f"; done
   chmod +x scripts/start-team.sh scripts/recycle-sibling.sh scripts/ctx-fill.py
   ```
   If the overlay names different doc paths (ORCHESTRATION.md → Docs), use those instead.
2. **Fill the overlay** (only if just created) — infer candidates from the repo (`package.json` scripts, `Makefile`, CI config), then ASK the human to confirm: gate command + pass-proof line, never-run commands, deploy vehicle (or "none"), validator seat (optional), locked items. Never silently guess a gate. Leave the `team:` block at its defaults unless the human wants other names.
3. **Fill AI_CONTEXT.md** (only if just created) — current version, test count (from one gate run), one line on what works. Leave the rest as prompts.
4. **CLAUDE.md section** — offer to append `templates/CLAUDE-section.md` (managed block `<!-- orchestration-kit vX -->`). Requires the human's yes; no CLAUDE.md → offer to create it with just this section. Marker already present → diff against the new template and propose the delta.
5. **Memory** — nothing to create. Claude Code makes its auto-memory (`~/.claude/projects/<slug>/memory/`) itself; `/orchestration-kit:retro` writes lessons there.
6. **Commit** — stage exactly the paths reported CREATE (never `git add -A`), `git commit -m "chore(orchestration): adopt orchestration-kit vX"`, `git push`.
7. **Next step for the human:**
   ```
   bash scripts/start-team.sh            # opens the seat (Orca) + Sib1, Sib2 — each in its own window
   bash scripts/start-team.sh --dry-run  # preview; launches nothing
   ```
   Offer to run it for them. Then: talk to the seat window only; siblings report to it. Not on Windows+WSL → the script prints the per-window `claude --name …` commands to run by hand.

## Rules

- Idempotent: never overwrite; re-running reports SKIP for everything that exists.
- The plugin ships the SessionStart hook itself (fresh sessions in a repo with a board are told to orient + send READY) — nothing to install in `.claude/settings.json` for it.
