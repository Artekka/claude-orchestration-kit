---
name: feedback_verify_test_gate_yourself
description: Don't trust piped or incomplete test-gate signals — run the real gate yourself before committing/deploying
metadata:
  type: feedback
---

Three false-green traps, each able to green-light a broken deploy:

1. **`<test cmd> | tail -N` masks the real exit code.** In a background task, the completion
   exit code becomes `tail`'s (0), and the truncated tail can drop the `Tests N passed | M
   failed` line. **How to apply:** redirect to a file and read both signals:
   `<test cmd> > "$TMP/gate.log" 2>&1; echo "exit=$?"`, then grep the log for the summary line.
2. **Subagents that END by starting a long background test run return a TRUNCATED report** —
   they come back mid-run, and their "GREEN / N passing" isn't real yet. **How to apply:** the
   gate is yours to run and read. After any implementation agent, re-verify its edits on disk
   and run the gate yourself before committing.
3. **"It's a flake, passes in isolation" can be a STALE build artifact.** A suite failed in
   the full run and — contrary to the report — in isolation too. Cause: a shared package's
   built output lagged its source, so a consumer and its test saw different code. **Fix:**
   rebuild shared artifacts before the gate, and reproduce any "flake" yourself on a fresh build
   before believing the label.

**Why:** a gate result is only trustworthy when YOU produced it, unpiped, with the real exit
code and the pass/fail line in hand, on freshly built artifacts.
