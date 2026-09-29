---
name: feedback_background_test_notification_masks_exit
description: A background test-run completion notification reports the LAST chained command's exit (the appended echo), NOT the test runner's — read the real exit + pass/fail from the redirected log
metadata:
  type: feedback
---

Running the gate in the background as
`<test cmd> > "$TMP/gate.log" 2>&1; echo "REAL EXIT: $?" >> "$TMP/gate.log"`, the completion
notification says "exit code 0" — that is the **echo's** exit, not the test runner's. The real
exit was captured INTO the log; the notification can't see it.

**Why:** the notification said 0 while the log said **1** — a genuine test failure. Trusting the
notification would have merged and deployed a red gate.

**How to apply:** keep the appended `REAL EXIT` pattern, but after a background gate completes,
ALWAYS grep the log for that line AND the `Tests N passed | M failed` summary, and gate the merge
on THAT — never on the notification's exit code.
