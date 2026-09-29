---
name: orient
description: Bring a fresh session up to speed on a kit-adopted project — restate the multi-session non-negotiables, read the ground rules, the orchestration overlay, the live board, and recent git history, then summarize state in five bullets and report availability to any active orchestrator. Use at session start ("orient me", "where are we", "catch me up") or when invoked on a project without context. If the project ships its own richer /orient, prefer that one.
---

# orient

Load a fresh session's working memory without the human re-explaining. End state: five bullets + a productive next question (or a report to the orchestrator).

## Step 0 — The multi-session non-negotiables (restate in your summary)

1. **ALL edits happen in your own worktree** — the main thread's included. Board/docs edits in the shared checkout are committed within seconds via the board-write recipe (`/orchestration-kit:board`). Never `git add -A` / `.` / `git commit -a`; never `git stash` (stash refs are shared across worktrees). A dirty status you didn't cause is a sibling at work — leave it.
2. **Refresh before claiming** — `git fetch origin && git rebase origin/main` (NOT `git pull --rebase`: shared FETCH_HEAD race). `cannot lock ref` = a sibling's fetch won; retry: `git fetch origin || { sleep 2; git fetch origin; } && git rebase origin/main`. A claim is only real once pushed. OPEN rows and briefs are hypotheses — verify against the CODE.
3. **New rows carry YOUR session prefix** (`<tag>-1`, `<tag>-2` …) — never the board's highest id + 1 (LESSON 16). State your prefix in the summary.
4. **Run the gate from INSIDE your own worktree** and check its printed counts against your delta — a script that `cd`s to its own directory gates whichever tree it lives in.
5. **The board is status, not narrative.** Archives (`docs/orchestration/archive/BOARD_ARCHIVE_*.md`) are grepped, never read whole: `grep -n '<ROW-ID>' docs/orchestration/archive/*.md | cut -c1-200`.
6. **Questions and approvals go to the seat** when a banner stands — never to the human in your terminal.

## Steps 1–6 — The reads, in order

1. The status doc (ORCHESTRATION.md → Docs; default `docs/AI_CONTEXT.md`) — note how stale its "Last refresh" is.
   **Missing, or still has `<…>` placeholders? → bootstrap mode:** orient from the project itself instead — `README*`, `CLAUDE.md`, the package manifest(s), `ls docs/`, a 2-level directory listing, `git log --oneline -30`. Then:
   | You are | Do |
   |---|---|
   | The seat, or a lone session (no banner) | Write/fill the status doc from what you read (mark guesses `(unverified)`), commit it via the board-write recipe, say so in your summary |
   | A sibling under a banner | Do NOT write it (concurrent writers) — orient from the sources, and put "status doc missing/template" in your READY so the seat fills it |
2. `CLAUDE.md` top to bottom — the ground rules. (Claude Code's auto-memory index loads by itself.)
3. `docs/orchestration/ORCHESTRATION.md` — gate, change classes, deploy, validator, locked items, hazards.
4. The last two entries of the log (default `docs/timeline/build-log.md`: `tail -120`) — what shipped, what's in flight. Log older than the latest commits ⇒ unlogged work; note it.
5. The board — every open row's fence is a no-edit zone for you.
6. `git log --oneline -20` + `git status`. Don't run the full test suite — trust the status doc's counts unless the docs look stale, then run a fast targeted subset only.

## Summarize in five bullets

1. Current version + latest shipped chunk. 2. What works today. 3. Top deferred items. 4. Suite health (from the status doc, not a fresh run). 5. In-flight work / stale docs. Then your row prefix + one line confirming the Step-0 rules.

## Step 7 — Roster handshake (banner-aware)

`ListAgents` reports terminal **liveness** only — uptime survives `/clear`, so a fresh context and a spent one look identical. Rosters are built from **READY signals**, never from a listing.

| You are | Do |
|---|---|
| Sibling · `ORCHESTRATOR ACTIVE` banner | Send READY to the named seat as your LAST orientation act. Don't ask the human for work. The human still outranks the seat if they type in YOUR terminal |
| Sibling · no banner | Ask the human what to work on |
| The seat | Re-run `ListAgents` at the end of orientation, then WAIT for READY signals — never infer readiness from the listing |

**READY signal** (`SendMessage` to the seat; board note `AVAILABLE <prefix>` under the banner only if SendMessage fails):
```
READY <PREFIX> [<ref>] · fill <current from ctx-fill, verbatim> · <what you can take> · seen: <rows whose builder narrative you've already read, or "none">
```
- `<ref>` = your own identity line from `ListAgents` (e.g. "This session is Sib1 [57f3ab]") — not your session uuid.
- Fill = `python3 scripts/ctx-fill.py` run as its own command. If it says the window is UNKNOWN, read your env block and add the window it states.
- `seen:` is your independence disclosure — it decides which rows you may later verify.
- If the banner's era/seat looks stale against the board body, say so in READY.

Don't start work until direction arrives (human or seat).
