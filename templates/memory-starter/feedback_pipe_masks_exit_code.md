---
name: feedback_pipe_masks_exit_code
description: `cmd 2>&1 | tail; echo $?` reports TAIL's exit status, not the command's — use PIPESTATUS or drop the pipe when the exit code matters
metadata:
  type: feedback
---

`<typecheck> 2>&1 | tail -20; echo "EXIT=$?"` prints **tail's** exit code, which is
essentially always 0. Several "clean" typechecks in one session were actually failing;
only the project gate caught them.

**Why:** `$?` after a pipeline is the LAST command's status.

**How to apply:** when the exit code matters, use `echo "EXIT=${PIPESTATUS[0]}"`, or run the
command unpiped and let its own output speak. Better still, prefer the project's own gate
over ad-hoc piped checks — it asserts the printed pass summary rather than trusting exit
codes at all (see `feedback_verify_test_gate_yourself`).

Also: a gate that typechecks BEFORE rebuilding a shared package's build output can produce a
false RED from stale output — rebuild and re-run before diagnosing.
