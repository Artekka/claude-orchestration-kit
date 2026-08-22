---
name: feedback-multisession-board-orchestration-default
description: "Art wants the multi-session claimable AGENT_BOARD orchestration workflow as the PERMANENT default — this project and all future ones — plus a portable \"orchestration kit\" package"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0326a78c-bfe8-44c6-aa46-3eb25d1d517a
  modified: 2026-08-09T05:41:10.096Z
---

Art's directive (2026-08-08): the workflow used that session — a **shared claimable task board** (`docs/orchestration/AGENT_BOARD.md`) coordinating MULTIPLE Claude Code sessions, each dispatching parallel Opus worktree subagents with file fences, verify-feature gates at hand-offs, sequential reconciles, and an exclusive deploy claim — is how he wants ALL substantial work run from now on, in every project.

**Why:** three concurrent Fable sessions (fable-A/B/3) partitioned ~15 workstreams without a single file collision; the board made claims, fences, and status visible across sessions.

**How to apply:**
- At session start on any substantial task list, read/create `docs/orchestration/AGENT_BOARD.md` (protocol lives in the file itself), claim rows by committed edit, dispatch isolated-worktree Opus agents per row, verify-feature before reconcile, reconcile one at a time, deploy via exclusive claim.
- Never let worktree agents `git stash` (refs are shared across worktrees — B1/B2 collision 2026-08-08).
- The portable **orchestration-kit** carries this whole workflow (skills, verifier agent, board/overlay/CLAUDE templates, LESSONS): new projects run its `bootstrap-project` (or `kit-init` on an existing repo) instead of hand-copying. Its version and install state live in the kit repo's CHANGELOG — check there, not here.
