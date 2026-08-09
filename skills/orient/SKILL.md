---
name: orient
description: Bring a fresh session up to speed on a kit-adopted project — read the project's ground rules, the orchestration overlay, the live agent board, and recent git history, then summarize state in five bullets. Use at session start ("orient me", "where are we", "catch me up") or when invoked on a project without context. If the project ships its own richer /orient skill, prefer that one.
---

# orient

Reads in order; don't summarize until all reads are done (partial summaries are wrong summaries).

## Steps

1. `CLAUDE.md` — the project's ground rules (a kit-adopted project carries the marked orchestration section).
2. Project status doc if one exists (e.g. `docs/AI_CONTEXT.md`, `STATUS.md`) — note its freshness date; flag if it trails recent commits.
3. `docs/orchestration/ORCHESTRATION.md` — gate, change classes, deploy vehicle, locked items, hazards.
4. `git pull --ff-only`, then `docs/orchestration/AGENT_BOARD.md` at HEAD — open rows, fences, in-flight sessions.
5. `git log --oneline -20` + `git status --short` — unlogged commits, uncommitted work.
6. Do NOT run the full test suite; trust the status doc's count unless evidence says otherwise, then run the overlay's fast gate only.

## Report — exactly five bullets

1. Current version/state + most recent shipped chunk.
2. What works today (one line).
3. Top unclaimed board rows / deferred items (up to 3, priority order).
4. Gate/test health per the docs (note staleness if suspected).
5. In-flight: open board claims by other sessions, uncommitted changes, half-done phases. Default: "Nothing in-flight."

Then ask what to work on — or, if the user already gave direction, claim via `/board` and start.
