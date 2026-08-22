---
name: feedback_a_check_that_cannot_fail_is_not_a_check
description: "Self-checks that silently match nothing report success on broken state — this shell's grep does NOT support \\| alternation, so a conflict-marker check returned 0 on a file that still had one and the markers got committed. Prove a check can fail before trusting its pass."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c155d416-45da-4d77-9f08-6e80fd16df69
  modified: 2026-08-19T02:17:02.100Z
---

2026-08-14, MOB-7B reconcile. After resolving two merge conflicts I ran what looked like a solid guard:

```bash
grep -rn "^<<<<<<< \|^>>>>>>> \|^=======$" fileA fileB | wc -l   # printed 0 → "clean!"
```

It printed `0`, so I staged and committed. The files **still contained an unresolved conflict block** — esbuild caught it minutes later (`Expected identifier but found "<"`), after a `tsc` typecheck had *also* passed it.

**Why:** the `grep` on this box is **ugrep**, which does not treat `\|` as alternation in its default mode. The pattern matched nothing *as a pattern* — not because the file was clean. A check whose failure mode is "silently matches nothing" reports success on exactly the state it exists to catch.

**How to apply:**
1. **Make the check fail once, on purpose,** before you trust its pass — the same discipline the verifier agents apply via mutation testing, applied to your own tooling.
2. Prefer **one plain pattern per file with a count you can sanity-read** over a clever combined pattern:
   `for f in …; do echo "$f: $(grep -c '^<<<<<<<' $f)"; done` — a per-file number you must look at, not a single `0` you can wave through.
3. Treat a **suspiciously clean** result on a step that usually finds something as a signal to re-test the check itself.
4. `tsc` passing is not proof a file parses for the bundler — esbuild and tsc disagreed here. See [[feedback_typecheck_passes_build_fails_predeploy]].

Same family as [[feedback_pipe_masks_exit_code]], [[feedback_assert_match_count_not_just_failure_count]] and [[feedback_verify_test_gate_yourself]]: the signal was structurally incapable of reporting failure. Related: [[reference_shared_tree_concurrent_git_ops_corrupt_test_runs]].
