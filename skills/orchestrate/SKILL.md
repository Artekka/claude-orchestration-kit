---
name: orchestrate
description: Run the orchestrated-autonomy loop as the ACTIVE ORCHESTRATOR ("the seat") coordinating sibling Claude sessions on a kit-adopted project — take the seat via the board banner, intake tasks into briefed fenced rows, decompose into a dependency DAG, assign siblings (SendMessage + board), track phase-boundary reports, gate every hand-off with a SIBLING-SESSION verifier, reconcile one row at a time, deploy in wave trains, allocate log numbers via the LOG slot, route all human approvals, and recycle siblings (and itself) when context fills. Use when the human says "orchestrate", "take the seat", "run the board", or hands over a batch of tasks while sibling sessions are active.
---

# orchestrate

One session (the **seat**) plans, assigns, verifies-by-proxy, lands and ships; 2+ **siblings** build in their own worktrees. Exists because distributed writers minting shared IDs / mutating shared state with no lock collide silently (LESSONS 16–17, 28–41). Project specifics (gate, deploy, validator, board path) come from `docs/orchestration/ORCHESTRATION.md`.

## 0 · Take the seat

```bash
git fetch origin && git rebase origin/main          # NOT `git pull --rebase` — shared FETCH_HEAD race (LESSON 29)
# exit 1 "cannot lock ref 'refs/remotes/origin/main'" = a sibling's fetch won the lock; nothing rebased. Retry once:
git fetch origin || { sleep 2; git fetch origin; } && git rebase origin/main
```

0. Fresh seat → do the `/orchestration-kit:orient` reads first (Steps 0–6; skip its READY step — you are the one receiving READYs).
1. Read the board top to bottom (archives: grep only, never whole). Another `ORCHESTRATOR ACTIVE` banner with a live seat → do NOT take it; ask the human.
2. Post the banner at the TOP of the board (shape: the board's "Seat banner — SHAPE ONLY" section, or `${CLAUDE_PLUGIN_ROOT}/templates/AGENT_BOARD.md`): seat name + `[ref]`, era/date, your row prefix, model + window **from your own env block**, measured fill, standing rules. **Commit + push immediately** (board-write recipe, §6) — an unpushed banner is invisible.
3. Measure yourself: `python3 scripts/ctx-fill.py` → paste `current` into the banner.
4. `ListAgents` shows who is **reachable**, never who is **ready** — terminal uptime survives `/clear`. Build the roster from READY signals only (§3). Re-run `ListAgents` right before publishing any roster/dispatch plan.
5. **Siblings not running?** Offer the human `bash scripts/start-team.sh` (opens any missing seat/sibling window; skips names already running; `--dry-run` to preview) and run it on a yes.

## 1 · Single-allocator (while the banner stands)

| Shared resource | Minted/held by |
|---|---|
| Planned-work row IDs (`<seatprefix>-n`) | Seat only |
| Log / milestone number | Seat, inside a LOG-slot claim |
| Version bump / release-note version | Seat, at deploy time |
| DEPLOY slot · LOG slot | Seat only |
| Sibling mid-task discoveries | Sibling's OWN prefix (`<sibprefix>-n`) — never a shared counter |

## 2 · Intake → briefed rows

Every ask (human plain language, external tracker, issue queue) becomes a row under your prefix. The board line carries **status only**; the **brief goes to the builder by message** (a narrative board briefs its own verifiers).

**Row brief template:**
```
<ID> · <title>
Goal: <one paragraph>
Acceptance (checkable): 1. … 2. … 3. …
Fence: <exact files/dirs this row may edit>
Seam map: <file:line pointers from your own Explore pass — don't make the builder re-explore>
Gate: <class from ORCHESTRATION.md → command + pass-proof line>
Release note: <user-language line, or "internal">
Rules: own worktree · report at phase boundaries · no deploy · no out-of-fence edits ·
       questions/approvals to the seat, never the human
```
Every brief is a hypothesis — a builder correcting it upward is expected, not insubordination.

## 3 · DAG + assignment

1. Decompose into a DAG: nodes = fenced rows, edges = verify-gated hand-offs. **Concurrent nodes' fences must be disjoint** — check BEFORE assigning, including each row's acceptance-criteria surface (tests, fixtures, docs it must touch).
2. Wait for **READY** from each sibling (format in `/orchestration-kit:orient` Step 7): `READY <PREFIX> [<ref>] · fill <current> · <can take> · seen: <rows already read>`. The `seen:` list decides who may later VERIFY what.
3. **Assignment = SendMessage + the same assignment on the board row** (an undelivered message is silent; the board always works).
4. First reply confirms receipt. No reply in ~10 min → check the board; still nothing → banner note, reassign when someone frees up.

## 4 · Track

- Siblings report at phase boundaries: claimed → RED → GREEN + self-gate (literal pass line) → blocked/done.
- Silent >30 min mid-build → `git log origin/main` + board + message. Truly stalled → banner the stall, reassign (never two silent owners on one row).
- A correction that changes a builder's next hour goes in a **top-of-board banner**, not only a message.

## 5 · Hand-off verify gate — a SIBLING SESSION verifies

Every hand-off edge (downstream consumes upstream output) and every high-risk class in ORCHESTRATION.md gets an independent READ before reconcile.

| Rule | Why |
|---|---|
| The verifier is **another sibling session**, not a subagent you spawn | A peer has its own context window; your subagent inherits the seat's framing — and you've read the builder's reports all wave |
| **Nobody verifies their own row** | Self-review judges against the model already built |
| **No mutual pairs** (A reads B ⇒ B doesn't read A) | Reciprocity is a bias |
| Verifier gets the **contract only**: row goal + acceptance + fence + diff/branch + gate command | Withholding the builder's reasoning is the SEAT's discipline |
| Verifier **reports to the seat**, never messages the builder, never fixes | Negotiating with the author ≠ independent; fixing masks drift |
| Pick a verifier whose `seen:` doesn't include the builder's narrative for that row | Independence is per-row, not per-session |
| Verdict must state **DERIVED** (re-derived from spec/ground truth) or **CONSISTENCY-CHECKED** (only checked against the board's claim) | Every sibling reads the board, so all are anchored by the seat's framing; only DERIVED is verification |
| Instruct: "falsify the brief, don't confirm it" | Counteracts the shared anchor |

**Validator seat (recommended):** one sibling (ORCHESTRATION.md → Validator) that **never builds** — READ, re-read, train/merge verification, falsification, measurement. A terminal that never builds is independent of every row. Others may READ when it's busy. Never hand the validator a build or fix round.

Verdicts: **PASS** → reconcile. **DEVIATES/BROKEN** → findings to the SAME builder (fix-roundtrip) → scoped delta re-read; downstream blocked until PASS (LESSON 18). The subagent `verifier` (`/orchestration-kit:verify-feature`) remains the fallback when no independent sibling is free — say so on the row.

## 6 · Reconcile + board writes

- **One row at a time** (`/orchestration-kit:reconcile`), never parallel. Before each: no foreign rebase in progress; `git status` in the builder's worktree.
- After `git merge --no-ff`, **push immediately** (before notes, before the gate) — an unpushed merge gets linearized by the next plain rebase and the builder's SHAs never reach origin. Refresh with `git rebase --rebase-merges origin/main` while a merge is unpushed.
- Quote **on-main** SHAs only: `git branch -r --contains <sha> | grep -q origin/main`.

**Board write in the shared checkout (every time):**
```bash
[ "$(git symbolic-ref -q HEAD)" = refs/heads/main ] || { echo "shared checkout not on main — STOP"; exit 1; }
git diff HEAD --quiet || { echo "shared tree/index dirty — a sibling's staged hunk would ride your commit; wait"; exit 1; }
# edit the board, then stage + commit AS ONE COMMAND (the index is shared):
git add docs/orchestration/AGENT_BOARD.md && git commit -m "chore(orchestration): <what>"
git push origin main                                # never HEAD:main
```
"nothing added to commit" + "Everything up-to-date" right after a write = a sibling's commit swept your hunk; re-check `git log -1 -p`.

**Board size:** status, not narrative. Past ~60 KB → `cp` it verbatim to `docs/orchestration/archive/BOARD_ARCHIVE_<YYYY-MM-DD>.md`, add a row to the board's archive table, rewrite the live board to status only. Archives are grepped, never read whole.

## 7 · Wave-train deploys

- Deploy after each reconcile wave (1–3 rows finishing together); a hotfix or human-awaited fix ships immediately. Main never sits ahead of live past a working day.
- Claim DEPLOY slot (written + pushed BEFORE running) → announce the window → run **ORCHESTRATION.md → Deploy `vehicle`** → verify with its `post-deploy` check (a marker from this train in the live artifact + the version string) → release the slot with the verified version.
- Siblings never deploy while the banner stands; they hand SHAs to the seat.

## 8 · Log

Claim LOG slot (number allocated inside the claim text) → append the entry to the log (ORCHESTRATION.md → Docs; default `docs/timeline/build-log.md`) **with Edit — old_string = its last lines, new_string = those + the entry; NEVER Write** — and refresh the status doc (version, test count, deferred) in the SAME pass. A dispatched doc agent gets that Edit rule verbatim → **verify the diff: append-only (`git diff <log> | grep -c '^-[^-]'` = 0) and every fact checked** (LESSON 23) → commit yourself → release the slot.

## 9 · Sibling lifecycle

| Signal | Action |
|---|---|
| Sibling self-reports fill at the prompt mark; incoherent status; stale claim | SendMessage **"run /orchestration-kit:retro now"** + board note. A row already in flight finishes first |
| Sibling replies **"retro complete"** | ONLY NOW recycle: `bash scripts/recycle-sibling.sh <Name>` (launch fresh → wait → SIGTERM old). Script exits 2 (no usable terminal: `manual`) → tell the human "terminal <Name> is safe to /clear, then /orchestration-kit:orient" |
| Fresh sibling sends READY | Assign the next DAG node (check `seen:` before giving it a READ) |

Retro-before-clear is a **handshake** (LESSON 24): order → explicit "retro complete" → recycle, one terminal at a time. Never pre-announce a clear.

## 10 · Seat context self-check

| Window (read your OWN env block) | Self-report | Hand over by |
|---|---|---|
| ~1M | ~350K | ~400K |
| ~200K | ~140K (70%) | ~160K (80%) |

- Measure: `python3 scripts/ctx-fill.py [--window N]` — sums input + cache_read + cache_creation off the last assistant turn. **Never `bytes ÷ 4`** (biased high 30–60%, unstably). **Never infer a window from a transcript's model string.**
- At handover: finish only what is already in verify → write the **handover block** under the banner (slots, in-flight rows + SHAs, READs owed, human's queue) → run your own `/orchestration-kit:retro` → `bash scripts/recycle-sibling.sh <SeatName> /orchestration-kit:orchestrate` (the fresh seat opens first, then this one is SIGTERMed), or tell the human: "seat retro complete — /clear this terminal, then run /orchestration-kit:orchestrate".
- Include your measured fill + model in every handover and every roster report.

## 11 · The human's loop — all approvals through the seat

- Siblings **never** ask the human in their terminal. A permission prompt/denial or design question → the sibling stops and messages the seat → the seat asks the human HERE (batched) → relays the ruling (or runs the action itself). Restate this in every READY ack.
- Irreducible human work: design forks (surface BEFORE building), on-device checks, secrets, activations, `/clear` when recycling isn't available.
- The seat writes: board, briefs, reconciles, deploys, logs. It does **not** write feature code.
