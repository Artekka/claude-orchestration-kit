---
name: bootstrap-project
description: Spin up a NEW project (or adopt an existing directory) with the full orchestration-kit workflow in one pass — mkdir/git init if needed, board + overlay + CLAUDE starter, core skills, verifier agent, optional team agents, curated agnostic-memory starter, then approval-gated settings snippets (SessionStart hook + auto-compact off). Idempotent; never overwrites a live file. Use when the human says "bootstrap a project", "spin up a new project with the kit", "set this directory up for orchestration".
---

# bootstrap-project

Superset of `/kit-init`: kit-init scaffolds the board/overlay into an existing repo; this one takes a bare directory to a fully kit-adopted project. The mechanical work lives in `scripts/bootstrap.sh` so it is deterministic and dry-runnable.

## Steps

1. **Dry-run first, show the plan:**
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/bootstrap.sh" <target-dir> --dry-run [--with-team-agents]
   ```
   Every line is MKDIR/INIT/CREATE/SKIP/NOTE. Show the human; confirm the target and whether team agents are wanted (`--with-team-agents` — user-level agent defs take precedence, so project copies only matter on machines/for collaborators without them).
2. **Run it for real** (same command minus `--dry-run`). Re-running later is safe: existing files always SKIP — a live board, overlay, CLAUDE.md, or memory store is state, not scaffolding.
3. **Fill the overlay WITH the human.** Open `docs/orchestration/ORCHESTRATION.md`: gate command + pass-proof line, change classes, never-run commands, deploy vehicle, locked items. Infer candidates from the repo; NEVER silently guess a gate.
4. **CLAUDE.md when it already existed:** the script only NOTEs it. Offer `templates/CLAUDE-section.md` as an append (managed marker `<!-- orchestration-kit vX -->`); requires the human's yes.
5. **Settings snippets — ONE approval step, both offered together** (`templates/settings-snippets.md`): the SessionStart orient-and-check-banner hook, and `autoCompact: false` (the no-/compact house flow — the CLAUDE section carries the rule; this makes the automatic side match). They edit `.claude/settings.json` (user config) — apply only on an explicit yes, and verify the autoCompact key against the current Claude Code version first.
6. **Commit** in the target repo: `chore(orchestration): bootstrap orchestration-kit v0.3.0`.
7. **Print the day-1 loop:** orient → pull → read board → claim by pushed edit → isolated-worktree build → independent verify → sequential reconcile → exclusive deploy.

## Rules

- Idempotent via install-only-if-missing; the ONLY overwrite path is a kit UPGRADE diffing against a managed marker, proposed as a delta.
- Plugins are user-level: document (README "Assumed plugins"), never copy.
- extras/ (e.g. backfill) are take-or-leave: mention, don't install.
