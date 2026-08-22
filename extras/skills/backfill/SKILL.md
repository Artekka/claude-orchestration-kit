---
name: backfill
description: Surgically bring EXISTING production rows in line with a forward-only code change WITHOUT a destructive re-seed — dump → deterministic recompute → guarded reviewable SQL → staged-file apply → read-back verify. Use when a change "only applies going forward" but existing users should be corrected too, or for any one-off prod data fix. (Kit extra — take-or-leave; not part of the orchestration core.)
---

# backfill

Golden rule: **never mutate prod from a script that writes the DB directly.** Compute offline, emit reviewable SQL, show the human, then apply. Every statement guarded so re-running is a no-op.

## Steps

1. **Scope + confirm.** Which rows, what changes, why a backfill vs going-forward-only. Rows with FK dependents rule out re-seeding — that's why surgical. Confirm the target set with the human.
2. **Dump → JSON** (read-only): everything the recompute needs AND the current values you'll validate against.
3. **Count the impact** (read-only): how many rows the condition matches. Surface it.
4. **Compute deterministically — REUSE the live functions.** A one-off script reads the JSON, calls the same shared function the live path uses, and WRITES SQL to a temp file — it never touches the DB. **Determinism guard:** re-derive each row's CURRENT state first; a mismatch (user progressed past the seed, hand-edit, model drift) means SKIP that row — the change stays purely additive, never overwrites real progress.
5. **Emit GUARDED, idempotent SQL** in one transaction. Every statement guarded by the old value (`WHERE col < floor`, `WHERE id=$1 AND template_id='<old>'`); update only the columns you mean to; honor invariants the change touches.
6. **Review gate.** SQL statement count vs the impact count; show the human a sample; get the explicit go-ahead before applying.
7. **Apply via staged file** (`psql -v ON_ERROR_STOP=1 < file`), each statement reporting `UPDATE N` matching the count — an `UPDATE 0` means a guard didn't match: investigate, don't assume.
8. **Read-back verify:** the Step-3 count must now be 0; spot-check rows. **Fixpoint rule:** if the recompute's inputs include rows the backfill itself raises (lineage chains), loop dump→compute→apply until the read-back is 0 — guarded statements make each pass safe.
9. **Record:** commit the applied SQL + script as an audit record; note "prod backfill: N rows" in the project log.

## Never
`RESET`/wipe · re-seed rows with dependents · DB writes from the compute script · skipping the review gate, even with standing approval in principle.
