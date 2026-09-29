---
name: feedback_verify_before_narrate
description: Confirm edits/results landed on disk before reporting them done; tool transport can fabricate or silently drop file ops
metadata:
  type: feedback
---

Never report a file change, fix, or finding as done until it is confirmed on disk — read it
back, or grep for a unique marker and check the count. In at least one session the tool
transport was unreliable: file reads and command output intermittently came back **empty,
duplicated, or fabricated** (e.g. a README section and a doc file that didn't exist), and two
edits silently failed — caught ONLY by a follow-up grep-count check.

**Why:** narrating a fix as applied when it didn't land — or reasoning on fabricated reads —
produces confidently wrong work. One extra verify call is cheap; a phantom fix is a regression.

**How to apply:** after every edit, grep the file for the new symbol and assert the count. For
analysis, write results to a file and read THAT, retrying on empty. Anchor-check numbers against
known-good values before reporting.
