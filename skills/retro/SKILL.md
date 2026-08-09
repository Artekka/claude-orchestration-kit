---
name: retro
description: Close out a session on a kit-adopted project — the write-back half of /orient. Board rows updated and fences released, new lessons distilled (to project memory AND proposed upstream to the kit's LESSONS.md), status docs refreshed, work committed, and a clean-handoff check so the next session can orient cold. Use when the user says "retro", "wrap up", "close out the session", "let's call it".
---

# retro

Orient loads state at session start; retro writes it back at session end. A session that ends without this leaves the board lying and its lessons trapped in one context window.

## Steps

1. **Board close-out** — every row you touched: status current, verifier verdict + REAL gate line recorded, fences released, `git pull` → commit → push the board edit. An open claim you're abandoning goes back to OPEN with a note.
2. **Work committed** — nothing of value left uncommitted; branches/worktrees you own either landed (via reconcile) or their state is noted on their row. Deploy state goes through the DEPLOY row, never a retro side effect.
3. **Lesson distillation — the kit's whole point:**
   - Walk the session for incidents: a wrong assumption that cost time, a collision, a flaky signal, a rule that saved you. Write each to the project's memory system (if it has one).
   - **Cross-project lessons go upstream:** anything not project-specific is a candidate for the kit's `docs/LESSONS.md` (rule + one-line incident provenance). Add it to the kit repo and bump the minor version — that is how every other project inherits it — or, if you can't write the kit repo, record the candidate on the board for someone who can.
4. **Status docs refreshed** — whatever the project's orientation doc is (see overlay / CLAUDE.md): current-state line, counts, deferred list. A stale status doc is how the next session rebuilds finished work.
5. **Clean-handoff check** — final gate: could a fresh session run `/orient` right now and get the true picture from docs + board alone? If anything load-bearing lives only in this conversation, write it down (board note, status doc, or memory) before ending.

## What stays project-level

Deploys, patch notes, changelog/dev-log conventions, external task-board syncs — a project's own richer retro skill should do those and can chain this one for the generic half.
