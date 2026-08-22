---
name: retro
description: Close out a session on a kit-adopted project — the write-back half of /orient. Board rows updated and fences released, durable lessons written as memories/skills (invocation IS the approval), new lessons proposed upstream to the kit's LESSONS.md, status docs refreshed, work committed, deploy ensured (or handed to the active orchestrator), and a clean-handoff check so the next session can orient cold. Use when the human says "retro", "wrap up", "close out the session" — or when an active orchestrator orders "run /retro now".
---

# retro

Capture what would evaporate on `/clear`, AND leave the session committed, logged, and (when you own deploys) live. After this, a fresh `/orient` must reflect reality. Invocation is the standing approval — write, don't ask per-item.

## Steps

1. **Walk the conversation backwards.** Corrections → feedback memory (rule + why). Quiet confirmations a non-obvious approach worked → feedback memory. Sequences run ≥2× → skill candidate. Non-obvious repo facts / root-cause paths → reference memory. Human decisions not visible in code → memory. Bar: a memory is something a future agent gets *wrong or slow* without it; empty buckets are valid. UPDATE existing files over duplicating.
2. **Propose kit-worthy lessons upstream.** A lesson that holds on ANY project belongs in the kit's `docs/LESSONS.md` (terse numbered rule + one-line provenance) — that propagation is the kit's reason to exist. Project-only lessons stay in project memory.
3. **Board write-back.** Update every row you touched: status, verifier verdict, REAL gate lines, released fences. Close only rows whose FULL scope verifiably shipped (check reality — code + log + git — not the row's description). Sync any external task board both directions if the project uses one.
4. **Commit the session's work.** Explicit paths (never `git add -A`; a sibling's WIP may share the tree). Release notes for user-visible work per the project's convention. Dispatch the doc agent for the log + status-doc refresh in one pass — then verify its diff is append-only and factual before committing it yourself (LESSON 23).
5. **Deploy — banner check FIRST.** If the board carries an `ORCHESTRATOR ACTIVE` banner and you are not the orchestrator: **skip deploying entirely**; hand reconciled-but-undeployed SHAs to the orchestrator (message + board note). Otherwise ensure HEAD is live per ORCHESTRATION.md's deploy vehicle and verify a marker from this session in the live artifact.
6. **Handshake close.** Final tight summary: memories/skills written, lessons proposed upstream, rows closed/flagged, commits, deploy status, leftover manual actions. If an orchestrator ordered this retro, **reply "retro complete" — only that reply makes your terminal safe to clear** (LESSON 24).

## When NOT to use
Mid-task, or right after `/orient` — nothing to look back on.
