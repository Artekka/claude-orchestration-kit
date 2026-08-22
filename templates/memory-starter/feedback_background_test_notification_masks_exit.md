---
name: feedback_background_test_notification_masks_exit
description: "a background pnpm-test completion notification reports the LAST chained command's exit (the appended echo), NOT pnpm's — always read the real exit + pass/fail from the redirected log before merging/deploying"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b30564c-8bc4-40cc-b59c-9445f46b8294
---

When you run the pre-deploy gate in the background as `pnpm test --no-file-parallelism > /tmp/gate.log 2>&1; echo "REAL EXIT: $?" >> /tmp/gate.log`, the `<task-notification>` that fires on completion says "exit code 0" — but that is the **`echo`'s** exit (always 0), NOT pnpm's. The real pnpm exit was correctly captured by `$?` and written INTO the log; the notification just can't see it.

**Why:** This bit me directly (2026-06-16, Battle Items P1). The notification said "exit code 0", but `grep "REAL EXIT" gate.log` showed **1** — a genuine `seed-tier-ladder` test failure. Trusting the notification would have merged + deployed a red gate.

**How to apply:** The appended `echo "REAL EXIT: $?" >> log` pattern is CORRECT — keep it. But after a background gate completes, ALWAYS `grep` the log for that REAL-EXIT line AND the `Tests N passed | M failed` summary, and gate the merge/deploy on THAT, never on the notification's exit code. Sharpens `feedback_verify_test_gate_yourself` for the background-bash case.
