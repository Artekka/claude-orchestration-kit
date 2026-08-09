---
name: verify-feature
description: Independent, context-isolated verification of a finished feature — a fresh verifier agent (never given the implementer's reasoning) checks the code MATCHES the original spec (no drift) AND genuinely works (correct gate, real pass/fail line), then reports a structured verdict + blast-radius. Use after an implementation agent completes, at any parallel hand-off, or when the user asks "verify this", "did the agent actually build X", "check the agent's work". Auto-fires for the high-risk change classes in ORCHESTRATION.md. It never edits code.
---

# verify-feature

Adds a **validator node at each hand-off edge**, anchored to canonical ground truth (the spec / design doc / named constants), not to the sibling agent. Closes TDD's blind spot: test+code that confabulate the same wrong value pass TDD but fail an independent spec check.

## When to run

| Change | Mode |
|---|---|
| Parallel / worktree hand-off (agent B will consume agent A's output) | **AUTO** — before B starts |
| A high-risk class listed in `ORCHESTRATION.md` → Change classes | **AUTO** — before reconcile |
| Other multi-file / shared-surface changes | AUTO in parallel work; else opt-in |
| Trivial single-file change, no shared surface | **OPT-IN** |

## Mechanism

Dispatch a **fresh** subagent — `agentType: orchestration-kit:verifier`. Pass the **contract only**:

- `spec` — canonical source text: the board row / issue / design doc (ground truth), NOT the implementer's summary.
- `target` — branch / worktree path / diff to verify.
- `gate` — the gate command for this change class, read from `ORCHESTRATION.md` (command + the literal pass-proof line to assert).
- `locked` — the overlay's Locked list (the verifier flags any touch).

Never pass the implementer's transcript or reasoning. The verifier is read-only and returns a verdict: `PASS | DEVIATES | BROKEN` + deviations + fixes + blast radius.

## Model policy

Default = a strong model (never a small/fast tier for the verdict). Escalate to the strongest available for the overlay's high-risk classes. If the strongest model refuses (safety classifier on an unattended gate), re-dispatch the SAME verification one tier down and log the fallback — an unattended gate must never stall.

## Verdict → action

- `PASS` → proceed to reconcile.
- `DEVIATES` / `BROKEN` → block downstream consumption; return deviations to the implementation agent (resume it — don't fix in the verifier, don't fix in main). Re-verify after the fix round-trip.
- Any touch of a Locked item → surface to the human regardless of verdict.
