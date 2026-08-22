# Changelog — orchestration-kit

## 0.2.0 — 2026-08-08

- New skill: `retro` — the write-back half of `orient` (board close-out, lesson
  distillation with upstream-to-kit propagation, status-doc refresh, clean-handoff
  check). Without it, LESSONS.md had no trigger to accrete — the upgrade payload
  only grows if session-end prompts the write. (Art's observation, night one.)

## 0.1.0 — 2026-08-08

Initial release, extracted from the Einherjar/Camelot Tactics multi-session workflow
(the 2026-08-08 three-session evening: fable-A/B/3, ~15 workstreams, zero collisions).

- Board template + claim protocol (fences, statuses, committed edits, session tags).
- Project overlay model (`ORCHESTRATION.md`: gate, change classes, deploy, locked, hazards).
- Skills: kit-init, board, verify-feature, reconcile, orient.
- Agent: `verifier` (contract-only, read-only, four checks, structured verdict).
- LESSONS.md v1: 15 incident-backed rules, including the two added the night of
  extraction — never `git stash` in worktree agents (shared stash refs), and
  exclusive DEPLOY-row claims.

## 0.3.0 — 2026-08-21

The orchestrated-autonomy port (from the Einherjar pilot, 2026-08-20/21) + the
`bootstrap-project` super-init. New: orchestrate, bootstrap-project (+ scripts/bootstrap.sh,
idempotent + --dry-run), post-feature, generic team-agent templates (optional,
install-only-if-missing, user-level precedence), agnostic memory starter (30 ratified,
trust grants excluded), extras/backfill, settings-snippets template (SessionStart hook +
auto-compact off, one approval step), LESSONS 16–27. Refreshed: orient, reconcile, retro,
verify-feature, board, CLAUDE-section (v0.3.0 marker), verifier (model-pinned;
bypassPermissions demoted to an opt-in comment — trust grants never ship as defaults).
