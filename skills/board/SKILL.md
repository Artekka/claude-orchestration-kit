---
name: board
description: Work the shared multi-session agent board — read it, claim a row, add rows under your session prefix, update status, announce resource windows, release fences, close rows. Use at the start of any substantial task, after finishing a chunk, and before deploying (DEPLOY slot claim). The board file is the live coordination surface between concurrent Claude sessions on this repo.
---

# board

Board path: `ORCHESTRATION.md` → Sessions (default `docs/orchestration/AGENT_BOARD.md`). The protocol table lives IN the board file — honor it exactly.

## Read (always first)

```
git fetch origin && git pull --rebase origin main   # the board is only current at HEAD
```

Read top to bottom: every open row's file fence is a hard no-edit zone for you. Check the top for an `ORCHESTRATOR ACTIVE` banner — if one stands, IDs/slots are single-allocator (see `/orchestrate` §1) and task intake routes through the orchestrator.

## Claim

1. Pick an OPEN row — then **verify it against the CODE** (OPEN is a hypothesis; rows rot) and treat its proposed fix as a hypothesis too.
2. Edit status → `CLAIMED <your tag>`; state your file fence.
3. **Commit + push BEFORE starting work:** `chore(orchestration): <tag> claims <row>`. An unpushed claim is not a claim.
4. Push rejected → pull --rebase, re-read (your row may be gone), re-claim.

## New rows — YOUR prefix, never a shared counter

File `<tag>-1`, `<tag>-2` … numbered within your OWN session (LESSON 16). Never read the board's highest id and add one. Under an orchestrator banner, planned-work IDs are the orchestrator's; your prefix covers your mid-task discoveries.

## Slots + windows

- **DEPLOY slot:** claim in writing BEFORE running the deploy; release with the verified live version.
- **LOG slot:** claim before appending any milestone/log entry; the number is allocated inside the claim text (LESSON 17).
- **Resource windows:** announce gate runs, integration/container runs, deploys, and shared-daemon dev-stack boots BEFORE running them; mark the window CLOSED when done (LESSON 19).

## Update / close

- Status transitions per the board's Statuses line; record the verify verdict and the REAL gate summary (literal pass line, never "green").
- On done: release the fence explicitly so other sessions can proceed.
- Every board edit is its own prompt commit — uncommitted board state is invisible and gets swept into someone else's commit.

## Fence discipline

Never edit inside another open row's fence; genuine need → coordinate via notes on both rows + sequential landing order, never by editing first. Keep fences as narrow as honest.
