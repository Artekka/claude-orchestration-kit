---
name: feedback-silently-vacuous-tests
description: "A green test whose transcribed literals drifted can stop reaching the condition it names — derive test windows/thresholds from the live constant, not a hand-typed number"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3307dc45-f1ff-4542-b1d1-afc883743f6f
  modified: 2026-08-18T22:55:36.127Z
---

Found 2026-08-18 while un-rotting `tests/integration/v2/town/town-routes.test.ts`:
the **"food is capped" test had gone silently vacuous.** Its 3-hour accrual window was
a hand-typed literal; after the rates/cap were retuned it credits only 72 food against
a 150 cap — so it **never reaches the clamp it claims to test** and had quietly become
an accrual-arithmetic test wearing a cap test's name. It was GREEN the whole time.

Same file also had prose lying about a value: a blacksmith INT-gate comment still said
"the 15 threshold" after the gate was lowered 15 → 14 (test still passed).

**Why this is worse than red.** A failing test demands attention. A test that stopped
exercising its own premise reports success forever and removes the safety net silently.
Nothing draws the eye to it — you only find it by re-deriving what the numbers mean.

**How to apply:**
- **Derive, don't transcribe.** Compute the window/threshold from the live shared
  constant or helper (`resourceCap`, the LH storage formula, `constructionQueueSlots`,
  `FOUNDER_POT_FRAC`, …) so a retune moves the test instead of rotting it. Replacing a
  stale `50` with a hand-typed `150` only resets the clock on the same failure.
- **When a balance constant is retuned, grep the test suite for its old literal** — not
  just for compile errors.
- **A test asserting a boundary must be able to REACH the boundary.** Assert that the
  precondition held (e.g. accrual ≥ cap) before asserting the clamp, so drift turns it
  red instead of vacuous.
- Prose/comments in tests transcribe values too — de-transcribe those in the same pass.

**⚠ 2026-08-18/19, the counterpoint — LIVE-SOURCING CAN CAUSE THIS, not just cure it.**
Art zeroed every `builderIntRequirement` (board row O63). Three tutorial guards asserted
the step copy `toContain(`INT ${LIVE_VALUE}`)` — correctly live-sourced, exactly as the
advice above prescribes. But the copy rendered **"needs a builder with INT 0 or higher"**,
and `"INT " + 0` → `"INT 0"`, which the assertion **matches**. Every guard passed against
precisely the broken sentence it existed to prevent. A fourth guard added hours earlier by
another row had the same shape.

**The rule the first case did not capture:** deriving from the live constant protects
against the constant CHANGING; it does NOT protect against the constant reaching a
**degenerate value** — `0`, `""`, `[]`, `null` — where the rendered assertion is
trivially satisfiable or the claim itself stops being meaningful. Ask: *if this constant
went to zero/empty, would my assertion still pass, and would it still mean anything?*

**Fix shape:** when a value's absence is the meaningful state, assert **absence**, not a
formatted presence — and pin a phrase of real surrounding copy so the test cannot pass
against an empty body either. The replacements here assert `not.toMatch(/\bINT\b/)` plus
`toMatch(/Pick the Blacksmith/i)`, and were mutation-proven (re-inserting an INT clause
fails exactly 1 of 17 / 1 of 71, isolated to the right site).

Same trap generalizes past strings: a presence-only assertion on a DoT buff survives a
double-tick (the buff is still present, HP still dropped), so pin **count and magnitude**.

Related: [[feedback-assert-match-count-not-just-failure-count]],
[[feedback-multiagent-false-green-trace-semantics]], [[feedback-never-guess-stats-use-tables]],
[[reference-codex-guards-anchor-to-registry]].
