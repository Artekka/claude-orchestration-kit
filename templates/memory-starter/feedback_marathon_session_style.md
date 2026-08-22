---
name: feedback_marathon_session_style
description: "Art runs long multi-phase marathon sessions — keep shipping phase-by-phase via delegated subagents, verify on disk, commit per phase, checkpoint between phases"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a87b3d58-abd4-4b76-b949-a38f178e853a
---

Art is comfortable with very long, multi-epic sessions and will say "we've got context, continue" / "let's keep going" to push through several phases in one sitting (this session: dual-clock cutover → Rest → Phase F design + F1 + F2).

**Why:** he trusts the delegate-and-verify loop and values momentum; he'd rather chain phases than stop and re-orient. He's also context-aware ("we've got a lot of context") and will himself call for a checkpoint/`/clear`/`/retro` when he wants one.

**How to apply:**
- Keep the cadence: one well-scoped phase at a time → dispatch a subagent (TDD) → **verify the edits on disk yourself** (`verify_before_narrate`) → run the green gate → commit per phase → brief status → offer to continue or checkpoint. Don't try to one-shot a whole epic.
- At each phase boundary give a tight status + a genuine continue/checkpoint choice; let him steer the stopping point rather than stopping early "to be safe".
- For large multi-round epics use a feature branch + additive-then-swap (`feedback_phased_additive_then_swap`) so every commit is green and revertable across the marathon.
- Keep your own context lean so the marathon lasts: delegate file-heavy reads/builds to subagents (their reading doesn't bloat the main thread), and write durable decisions to memory mid-session so they survive an eventual `/clear`.

**Validated epic playbook (2026-06-12 — shipped proficiency v0.45.0 + materials v0.46.0, two full epics + a UI toggle in one session):** when a feature has design forks, run `AskUserQuestion` first; Art reliably picks **"drive to deploy-ready"** — i.e. I run the whole phased build autonomously and only stop for him at genuine forks + the final irreversible deploy/backfill. The loop that worked, per epic: lock the design to a `project_*` memory → spawn the **architect** to write the ADR (it writes to the main checkout) → for EACH phase spawn a **`general-purpose` agent in the main checkout** doing RED→GREEN (see `reference_subagent_worktree_vs_main_checkout` — qa/backend/frontend agents auto-worktree from stale main and cost a reconcile; general-purpose writes to main and sees prior committed phases) → **re-run the full suite + typecheck myself** to a /tmp log and verify on disk before trusting the agent's "green" (`feedback_verify_the_test_gate_yourself`, `feedback_verify_subagent_failure_claims`) → green commit per phase → the doc agent does the log + status-doc refresh → checkpoint for the deploy → merge `--no-ff` + `/deploy` + verify prod migrations. Test-safety lever for engine epics: gate new modifiers behind a present-only guard so the pure-engine goldens stay byte-identical.

**Doc-agent log-ordering caveat:** the dev log is **newest-at-BOTTOM** (chronological; `tail` shows the latest). Doc agents have PREPENDED a new entry ABOVE the prior one (wrong) — after any log dispatch, grep the heading pattern and confirm the new entry is last; swap the trailing blocks if not.

**Validated 2026-06-20 (single mega-session: belt fix + economy cost retune/per-family/rename + Focus-path UI + deep-expedition difficulty/rewards + loot-count-v2 + affix multi-select + item-upgrade sink → Milestones 131–133, ~12 deploys):** Art also runs a HYPERACTIVE variant — he fires many requests RAPIDLY, often as new messages mid-work (the harness injects them as "you MUST address after the current task"). Handling that worked:
- **Board EVERY request immediately** (project board or external task board) so nothing is lost, then keep building; close rows as each ships.
- **Batch related small fixes** into one deploy (e.g. icon-label + cache-depth) to limit prod restarts; ship one logical chunk → commit → `/deploy` → verify health + bundle marker → close row.
- **Delegate well-specified multi-file changes** to a `general-purpose` agent in the main checkout, then **re-run the gate myself** (lootRoll/goldens/typecheck to /tmp) before committing — the agents were reliable but I verified every "green" + the actual diff/constants.
- **Confirm BALANCE NUMBERS, not just approach, via `AskUserQuestion` with `preview` tables** (loot tier floors, drop-count curve) before building — Art eyeballs the resulting per-region/per-depth table and picks/tweaks in one step. Cheaper than building a wrong guess.
- He closes with an explicit sequence ("ship X, then Y, then Z, then retro + write all memories, then I'll clear and orient") — execute it in order; "write all memories" IS the green light to write without a separate proposal round.
- Combat **goldens stayed 285 byte-identical the whole session** — loot/economy/enemy-count/UI changes never touch the engine; that invariant is the fast confidence check after each delegated change.
