---
name: board
description: Work the shared multi-session agent board — read it, claim a row, add rows, update status, release fences, close rows. Use at the start of any substantial task ("check the board", "claim a task", "what's unclaimed"), after finishing a chunk (status update), and before deploying (DEPLOY row claim). The board file is the live coordination surface between concurrent Claude sessions on this repo.
---

# board

Board path: `ORCHESTRATION.md` → Sessions (default `docs/orchestration/AGENT_BOARD.md`). The protocol table lives IN the board file — honor it exactly.

## Read (always first)

```
git pull --ff-only     # the board is only current at HEAD
```

Read the board top to bottom: every open row's file fence is a hard no-edit zone for you.

## Claim

1. Pick an OPEN row (or add one from the human's ask — task, notes, suspected files).
2. Edit status → `CLAIMED <your tag>` per the board's tag scheme; state your intended file fence.
3. **Commit + push the board edit BEFORE starting work:**
   `chore(orchestration): <tag> claims <row>`
4. If the push rejects (another session moved the board), pull --rebase, re-read (your row may have been claimed), re-claim.

## Update / close

- Status transitions per the board's Statuses line; note the independent-verify verdict and the REAL gate summary (literal pass line, not "green").
- On done: release the fence explicitly ("fence released: <files>") so other sessions can proceed.
- Every board edit is its own prompt commit — uncommitted board state is invisible and gets swept into someone else's commit.

## Fence discipline

- Never edit files inside another open row's fence. If your fix genuinely needs a fenced file, coordinate via the board (a coord note on both rows, sequential reconcile order) — not by editing first.
- Keep fences as narrow as honest: file paths, or file + region for big files.
