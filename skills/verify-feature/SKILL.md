---
name: verify-feature
description: Independent, context-isolated verification of a finished feature — a fresh verifier agent (never given the implementer's reasoning) checks the code MATCHES the original spec (no drift) AND genuinely works (correct gate, real pass/fail line), then reports a structured verdict + blast-radius. Use after an implementation agent completes, at any parallel hand-off, or when the human asks "verify this", "did the agent actually build X". Auto-fires for the high-risk change classes in ORCHESTRATION.md; opt-in for trivial single-file tweaks. It never edits code.
---

# verify-feature

A validator node with a gate at each hand-off edge, anchored to canonical ground truth (spec / design doc / named constants) — never to the sibling's test. Closes TDD's blind spot: test+code confabulating the same wrong value pass TDD but fail an independent spec check (LESSON 7).

## When

| Change | Mode |
|---|---|
| Parallel / worktree hand-off (B will consume A's output) | **AUTO** — before B starts |
| ORCHESTRATION.md's high-risk classes (schema/migration, money/economy, security, golden-fixture) | **AUTO** — before reconcile |
| Other multi-file / shared-surface changes | AUTO in parallel work; else opt-in |
| Trivial single-file change, no shared surface | **OPT-IN** — and skipping is a recorded DECISION on the row, not an omission |

## Mechanism

Dispatch a **fresh** `verifier`-type agent with the **contract only**: `spec` (canonical text — board row / ADR / design doc, NOT the implementer's summary) + `target` (branch/worktree/diff) + `change_class` (→ gate command + model from ORCHESTRATION.md's table). The verifier is read-only; discipline + four checks + output schema live in `agents/verifier.md`.

If the `verifier` agent type isn't registered (defs load at session start), fall back to a general agent at the same model with an explicit `READ-ONLY — report, do not fix` line + the full discipline pasted in — prose-only enforcement, so prefer the real type once reloaded.

## Model policy

Default: the strongest generally-available tier you'd trust for review. Escalate one tier for the high-risk classes. **Never a small/fast model for the verdict.** If an escalated dispatch refuses (safety classifiers), re-dispatch the SAME verification on the default tier so an unattended gate never stalls — log the fallback.

## Acting on the verdict

- **PASS** → proceed (reconcile / next stage). A PASS may still carry a hardening `fixes[]` list — landing it pre-reconcile is normal (the roundtrip precedent).
- **DEVIATES** (drift on a green suite — the confabulation case) → downstream consumption blocked; return `deviations[]` to the SAME implementer for a fix-roundtrip, then a scoped delta re-verify.
- **BROKEN** → same, plus contain the blast radius: pause/re-verify every `blast_radius[]` consumer (files AND sibling worktrees) before they build further.

## Does NOT
Fix code (reports `fixes[]`) · replace the gate or reconcile · run the project's known-flaky full suite.
