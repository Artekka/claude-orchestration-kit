---
name: feedback_pipe_masks_exit_code
description: `cmd 2>&1 | tail; echo $?` reports TAIL's exit status, not the command's — use PIPESTATUS or drop the pipe when the exit code matters
metadata:
  type: feedback
---

`pnpm typecheck 2>&1 | tail -20; echo "EXIT=$?"` prints **tail's** exit code, which
is essentially always 0. Several "clean" typechecks during the ADR 0040 session were
actually failing; only `pnpm gate` caught them.

**Why:** `$?` after a pipeline is the LAST command's status.

**How to apply:** when the exit code matters, use `echo "EXIT=${PIPESTATUS[0]}"`, or
run the command unpiped and let its own output speak. Better still, prefer the
project's own gate (`pnpm gate`) over ad-hoc piped checks — it asserts the printed
pass summary rather than trusting exit codes at all, which is exactly the discipline
[[feedback_verify_test_gate_yourself]] describes.

Also note the einherjar gate runs `typecheck` BEFORE `build shared`, so a stale
`packages/shared/dist` can produce a false RED in the client's typecheck — rebuild
shared and re-run before diagnosing ([[reference_gate_typecheck_before_shared_build]]).
