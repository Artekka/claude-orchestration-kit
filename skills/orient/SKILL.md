---
name: orient
description: Bring a fresh session up to speed on a kit-adopted project — restate the multi-session non-negotiables, read the ground rules, the orchestration overlay, the live board, and recent git history, then summarize state in five bullets and report availability to any active orchestrator. Use at session start ("orient me", "where are we", "catch me up") or when invoked on a project without context. If the project ships its own richer /orient, prefer that one.
---

# orient

Load a fresh session's working memory without the human re-explaining. End state: five bullets + a productive next question (or a report to the orchestrator).

## Step 0 — The multi-session non-negotiables (restate in your summary)

1. **ALL edits happen in a worktree** — main-thread edits included; docs/board edits either in a worktree or committed within seconds. Never `git add -A` / `git commit -a` / `git stash` in the shared checkout. A dirty status you didn't cause is a sibling at work — leave it.
2. **Refresh the board BEFORE claiming:** `git fetch origin && git pull --rebase origin main`, then re-read the board. A claim is only real once pushed. Verify the row against the CODE (OPEN is a hypothesis) and treat the brief as a hypothesis too.
3. **New rows carry YOUR session prefix** (`<tag>-1`, `<tag>-2` …) — never read the board's highest id and add one (LESSON 16). State your prefix in the summary.
4. **If the gate script prints which tree it gated, READ that line** — a gate invoked from the wrong tree prints a legitimate green for a tree you are not in.

## Steps 1–5 — The reads, in order

1. The project's status doc (ORCHESTRATION.md → Status path), if one exists — note how stale its "last refresh" is.
2. `CLAUDE.md` top to bottom — the ground rules.
3. `docs/orchestration/ORCHESTRATION.md` — gate, change classes, deploy, locked items, hazards.
4. The board — every open row's fence is a no-edit zone for you.
5. `git log --oneline -20` + `git status`. Don't run the full test suite — trust the status doc's counts unless the docs look stale, then run a fast targeted subset only.

## Step 6 — Summarize in five bullets

1. Current version + latest shipped chunk. 2. What works today. 3. Top deferred items. 4. Suite health (from the status doc, not a fresh run). 5. In-flight work / stale docs. Then your row prefix + one line confirming the Step-0 rules.

**Then check the board top for an `ORCHESTRATOR ACTIVE` banner:**
- Banner present, you're not the orchestrator → do NOT ask the human for work. Report availability to the named orchestrator (reply to its message, else SendMessage by name, else post `AVAILABLE <tag>` under the banner — the board always works). The human still outranks the orchestrator in YOUR terminal.
- No banner (or you ARE the orchestrator) → ask the human what to work on. Don't start until direction arrives.
