---
name: feedback_silently_vacuous_tests
description: A green test whose transcribed literals drifted can stop reaching the condition it names — derive test windows/thresholds from the live constant, and check the degenerate value too
metadata:
  type: feedback
---

A "value is capped" test had gone silently vacuous: its accrual window was a hand-typed
literal, and after the rates/cap were retuned it credited well below the cap — so it **never
reached the clamp it claimed to test**. It was GREEN the whole time. A comment in the same file
still quoted a threshold that had since changed.

**Why this is worse than red:** a failing test demands attention. A test that stopped
exercising its own premise reports success forever and removes the safety net silently.

**How to apply:**
- **Derive, don't transcribe.** Compute windows/thresholds from the live constant or helper so a
  retune moves the test instead of rotting it. Replacing a stale literal with a new hand-typed
  one only resets the clock.
- When a constant is retuned, grep the tests for its OLD literal — not just for compile errors.
- **A test asserting a boundary must be able to REACH it.** Assert the precondition (e.g. accrual
  ≥ cap) before asserting the clamp, so drift turns it red instead of vacuous.
- Comments and prose in tests transcribe values too — fix those in the same pass.

**The counterpoint — live-sourcing can CAUSE this.** A requirement value was set to 0. Guards
asserted the rendered copy `toContain(`LEVEL ${LIVE_VALUE}`)` — correctly live-sourced — but the
copy now read "needs level 0 or higher", which the assertion **matched**. Every guard passed
against exactly the broken sentence it existed to prevent.

**Rule:** deriving from the live constant protects against the constant CHANGING, not against it
reaching a **degenerate value** — `0`, `""`, `[]`, `null` — where the assertion is trivially
satisfied. Ask: *if this went to zero/empty, would my assertion still pass, and would it still
mean anything?* When absence is the meaningful state, assert absence, and pin a phrase of real
surrounding copy so the test can't pass against an empty body. Past strings: a presence-only
assertion survives a double application of an effect — pin **count and magnitude**.
