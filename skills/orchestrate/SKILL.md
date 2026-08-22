---
name: orchestrate
description: Run the Orchestrated-Autonomy operating loop as the ACTIVE ORCHESTRATOR coordinating sibling Claude sessions on a kit-adopted project — take the seat via the board banner, intake tasks, decompose into a dependency DAG of fenced rows, assign siblings, track phase-boundary reports, gate hand-offs with verify-feature, reconcile sequentially, deploy in wave trains, allocate log/milestone numbers via the LOG slot, and manage sibling context lifecycle. Use when the human says "orchestrate", "take the orchestrator seat", "run the board", or hands over a batch of tasks while sibling sessions are active.
---

# Orchestrate

One session coordinates; siblings build. Exists to prevent distributed writers minting shared IDs / mutating shared state with no lock (LESSONS 16–17).

## 0 · Take the seat

```bash
git fetch origin && git pull --rebase origin main
```

1. Read the board (`ORCHESTRATION.md` → Sessions path) top to bottom. If another ORCHESTRATOR ACTIVE banner stands with a live session, do NOT take the seat — coordinate with them or ask the human.
2. Post/refresh the ORCHESTRATOR ACTIVE banner (your tag, date, standing rules). Commit + push immediately — an unpushed banner is invisible.
3. `ListAgents` — note reachable siblings. Reachability is partial/asymmetric: the board is the only guaranteed channel; SendMessage is the fast path.

## 1 · Single-allocator rules (while the banner stands)

| Shared resource | Who mints/holds |
|---|---|
| Planned-work row IDs (orchestrator's prefix) | Orchestrator only |
| Log/milestone number | Orchestrator, via LOG slot claim |
| Version bump / release-notes version | Orchestrator, at deploy time |
| DEPLOY slot · LOG slot | Orchestrator only |
| Sibling mid-task discoveries | Sibling's OWN prefix (LESSON 16 — unchanged) |

## 2 · Intake → board

Convert every ask (human plain language, external task board, community queue) into a briefed row under your prefix, pushed. **Row brief template:** goal ¶ · numbered CHECKABLE acceptance criteria · file fence · seam map (file:line from an Explore pass — don't make the sibling re-explore) · gate class + verifier model (ORCHESTRATION.md table) · release-note/deploy note · "report at phase boundaries, no deploy, no out-of-fence edits".

## 3 · DAG + assignment

1. Decompose into a dependency DAG: nodes = fenced rows, edges = verify-gated hand-offs. **Fences of concurrently-assigned nodes must be disjoint** — check overlap BEFORE assigning, including each row's acceptance-criteria surface.
2. Assignment = SendMessage **+ the same assignment written on the row** (undeliverable messages are silent).
3. First reply confirms receipt + tag. No reply in ~10 min → check the board for their orient note; still nothing → banner note + proceed, reassign when a sibling frees up.

## 4 · Track

- Siblings report at TDD phase boundaries: oriented/claimed → RED → GREEN + self-gate → blocked.
- Silent >30 min mid-build: poll `ListAgents`, check `git log origin/main` + board; message them; truly stalled → banner the stall and reassign (never two silent owners on one row).
- Corrections that change a claimant's next hour go in a **top-of-board banner**, not just a message.

## 5 · Hand-off gate

`/verify-feature` at EVERY hand-off edge — contract only (row/spec + diff), never the implementer's reasoning. Class → model per ORCHESTRATION.md's table. DEVIATES/BROKEN → return findings to the same sibling (fix-roundtrip); downstream consumption blocked until PASS. A DEVIATES→roundtrip→delta-PASS arc is the system working (LESSON 18).

## 6 · Reconcile + deploy trains

- Reconcile ONE row at a time (`/reconcile`), never parallel. Before each: check for a foreign rebase-in-progress; `git status` in the worktree.
- **Wave train:** deploy after each reconcile wave (1–3 rows finishing together); hotfixes deploy immediately. Main never sits ahead of live past a working day.
- Claim DEPLOY slot (written BEFORE running) → announce the window (LESSON 19) → deploy per ORCHESTRATION.md → verify live (marker in the shipped artifact + build provenance + version string) → release the slot with the verified version.

## 7 · Log

Claim LOG slot (allocate the milestone number inside the claim text) → dispatch the doc agent: log entry + status-doc refresh in the SAME pass → **verify its diff BEFORE committing: append-only (`git diff | grep -c "^-[^-]"` = 0) and every factual claim checked** (LESSON 23) → commit yourself → release the slot. Unusable draft → restore from HEAD and write it directly.

## 8 · Sibling lifecycle

| Signal | Action |
|---|---|
| Sibling self-reports context pressure; incoherent status; stale claim | SendMessage: **"run /retro now"** + board banner note |
| **Sibling CONFIRMS retro-complete in a reply** | ONLY NOW tell the human: "that terminal is safe to /clear" |
| Fresh sibling orients (SessionStart hook points it here) | It reports availability → assign the next DAG node |

**Retro-before-clear is a HANDSHAKE (LESSON 24):** retro order → explicit "retro complete" reply → then "safe to clear", one terminal at a time. Never pre-announce a clear; never let one race a pending retro.

## Boundaries

- Orchestrator writes: board, briefs, reconciles, deploys, logs. It does NOT write feature code — dispatch it.
- The human's irreducible loop: design forks/rulings (batched), on-device checks, activations, secrets, `/clear`. **Surface design forks BEFORE building.**
- Every row brief is a hypothesis — siblings verifying a brief upward is expected.
