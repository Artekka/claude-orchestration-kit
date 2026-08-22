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
- The **portable orchestration kit EXISTS**: `~/projects/claude-orchestration-kit` — **v0.1.0 built 2026-08-08** (fable-3, board row O4/D4). Claude Code plugin + self-hosting marketplace (`orchestration-kit@artekka-kits`): 5 generic skills (kit-init/board/verify-feature/reconcile/orient), read-only contract-only `verifier` agent, board/overlay/CLAUDE-section templates, LESSONS.md ×15. Design doc: einherjar `docs/orchestration/KIT_DESIGN.md`; Einherjar dogfood overlay: `docs/orchestration/ORCHESTRATION.md`. **INSTALLED (2026-08-08 late, Art-authorized):** pushed to `github.com/Artekka/claude-orchestration-kit` (private) and installed at USER scope (`orchestration-kit@artekka-kits` v0.1.0) — kit skills (`orchestration-kit:kit-init` etc.) + verifier agent are available in every project. gh CLI now installed + auth'd on this machine. Optional remaining per-project switches: CLAUDE.md marked-section append + project `.claude/settings.json` enablement (self-describing repo for other machines). New projects: install the kit + run `/orchestration-kit:kit-init` instead of hand-copying. See [[reference-independent-verify-skill]] and [[feedback-isolate-worktree-for-concurrent-sessions]].
