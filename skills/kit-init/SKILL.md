---
name: kit-init
description: Initialize a project for the multi-session orchestration workflow — scaffold the shared AGENT_BOARD, the ORCHESTRATION.md project overlay, and (with approval) the CLAUDE.md starter section. Use on any project adopting the orchestration-kit, when the user says "set up the board", "init the orchestration kit", "make this project multi-session ready". Idempotent — safe to re-run; never overwrites a live board.
---

# kit-init

Scaffold a project to run the claimable-board workflow. Templates live in this plugin's `templates/` directory (resolve via `${CLAUDE_PLUGIN_ROOT}/templates/`).

## Steps

1. **Board** — if `docs/orchestration/AGENT_BOARD.md` is missing, create it from `templates/AGENT_BOARD.md`. If it exists, leave it untouched (a live board is state, not scaffolding).
2. **Overlay** — if `docs/orchestration/ORCHESTRATION.md` is missing, create it from `templates/ORCHESTRATION.md`, then FILL it, don't leave placeholders:
   - Infer candidates from the repo (`package.json` scripts, `Makefile`, CI config) for Gate / Deploy.
   - ASK the human to confirm gate command, pass-proof line, never-run commands, deploy vehicle, and locked items. Never silently guess a gate.
3. **CLAUDE.md section** — offer to append `templates/CLAUDE-section.md` (marked block `<!-- orchestration-kit vX -->`). Requires the human's yes; if CLAUDE.md is missing, offer to create it with just this section.
4. **Commit** — `chore(orchestration): adopt orchestration-kit vX (board + overlay)`.
5. **Print the day-1 loop** so the human sees what changes: orient → `git pull` → read board → claim by committed edit → isolated-worktree build → independent verify → sequential reconcile → exclusive deploy.

## Rules

- Idempotent: re-running upgrades templates ONLY where the target is missing or carries the managed marker; never clobber project-customized content.
- On kit upgrade: diff the project's marked CLAUDE.md block against the new template and propose the delta.
