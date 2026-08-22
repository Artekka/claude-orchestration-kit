---
name: a-test-can-ratify-the-defect
description: A green test can RATIFY a defect instead of catching it — a passing assertion that pins buggy behavior reads as a deliberate decision, so the next reader reasons AROUND the bug; worse than no test at all
metadata:
  type: feedback
---

Canonical merge of three sibling lessons (origin project kept its three files; commits and logs there reference them individually).

A test is only protection when it asserts the SPEC. Three ways a green suite ships a defect:

1. **The assertion IS the bug.** `expect(moveBeat.state).toEqual(attackBeat.state)` asserted the shared state that *was* the defect — and shipped to production on that green. A passing test reads as a deliberate decision, so reviewers reason *around* it instead of questioning it.
2. **The test pins the fail-open.** Predicate tests asserted the fail-open behavior the code happened to have, freezing the hazard in place as if it were contract.
3. **The guard cannot fail.** A live-sourced assertion whose source value hit 0/empty/null auto-passes and means nothing (`toContain("6")` when the constant is interpolated; `toContain("INT 0")` matching the broken sentence it existed to prevent).

**Why:** this is worse than a missing test — absence invites scrutiny; a green assertion certifies.

**How to apply:** for every guard, name the production change that would make it FAIL before writing it; falsify it at least once (RED-first, or a diff-verified mutant). When touching a suspicious passing test, ask "does this assert the spec, or the code's current behavior?" — and check what the assertion would do against the CORRECT behavior.
