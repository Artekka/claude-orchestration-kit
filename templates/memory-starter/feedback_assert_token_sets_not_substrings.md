---
name: feedback_assert_token_sets_not_substrings
description: "A className assertion written as toContain('h-4') cannot see a LATER utility overriding it — an added h-5 keeps the test green while changing the rendered height. Compare extracted token SETS between the two elements whose equality is the actual contract, plus a non-vacuity check."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c155d416-45da-4d77-9f08-6e80fd16df69
  modified: 2026-08-19T02:17:38.955Z
---

2026-08-14, MOB-7B Lane B. The contract was "the item-name chip is exactly as tall as a plain caption" — the fixed-height slot that stops a bottom-anchored action bar walking up the screen when a name appears. It was asserted as `expect(cls).toContain("h-4")`.

A verifier mutation added an **overriding `h-5`** to the name-chip branch. All 22 tests stayed green while the opened orb grew 4px — i.e. the exact user-reported defect the guard existed to prevent. `toContain` is blind to a later class winning the cascade.

**The fix, and the general shape:**
```ts
const heightTokens = (cls: string) =>
  [...new Set(cls.split(/\s+/).filter((t) => /^(h|leading|py|pt|pb)-/.test(t)))].sort();
expect(heightTokens(nameChip)).toEqual(heightTokens(plainCaption));   // the real contract
expect(heightTokens(plainCaption).some((t) => t.startsWith("h-"))).toBe(true); // non-vacuity
```

**Why the non-vacuity line matters:** without it, "both sides equally unconstrained" satisfies the equality. The verifier proved this by mutating `h-4` → `sm:h-4`, which keeps every `toContain("h-4")` substring green *and* would pass a bare set-equality.

**How to apply:** when the contract is "these two elements agree", assert the **agreement** (set equality on the relevant token family), not the presence of one token on one of them — and add the check that the compared thing is non-empty. Same reasoning as `feedback_assert_match_count_not_just_failure_count`: presence checks pass for reasons unrelated to the property you care about.

Related: `feedback_a_check_that_cannot_fail_is_not_a_check`, `reference_independent_verify_skill`.
