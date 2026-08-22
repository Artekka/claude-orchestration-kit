---
name: feedback_assert_match_count_not_just_failure_count
description: "When validating generated data/SQL by regex, assert how many rows MATCHED — a regex that matches nothing reports zero failures and looks identical to 'all clean'"
metadata:
  type: feedback
---

**A validation that finds nothing wrong and a validation that ran on nothing are indistinguishable unless you count the matches.**

2026-07-22, validating the ADR 0039 prod backfill: a script parsed 849 generated `UPDATE` statements with a regex and reported

```
slot-wasting in a loadout: 0
duplicate in a loadout   : 0
over LOADOUT_SIZE        : 0
```

which read as a clean bill of health. It had matched **zero lines** — the regex omitted the `updated_at = now()` clause sitting between `equipped_skills` and `WHERE`. Every counter was 0 because the loop body never executed.

**Why:** before mutating 849 prod rows, "all invariants hold" was the entire basis for proceeding. A vacuous check is worse than no check, because it manufactures confidence.

**How to apply:** every regex/filter-based validation prints the number of items it actually inspected, and asserts it equals the expected population (`expect(matched).toBe(849)`). If a line was expected to parse and didn't, print it rather than skipping silently. The corrected pass also added a positive control (`SKILLS LOST vs today: 0`) that could only be computed if parsing genuinely worked.

Generalises past SQL — same trap in any grep-the-output verification step.

Related: [[feedback_verify_before_narrate]], [[feedback_verify_test_gate_yourself]], [[reference_prod_sql_write_via_staged_file]]
