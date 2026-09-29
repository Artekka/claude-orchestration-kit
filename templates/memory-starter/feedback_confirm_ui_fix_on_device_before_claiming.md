---
name: feedback_confirm_ui_fix_on_device_before_claiming
description: Don't claim a visual/UX fix is 'fixed' — especially publicly — before the user confirms it on a real device (desktop AND mobile). Ship, ask for confirmation, THEN post the shipped/fixed note.
metadata:
  type: feedback
---

For CSS / layout / scroll / animation fixes: **deploy, then ask the user to confirm on a real
device (desktop AND mobile) before claiming "fixed" — and hold any public "shipped" post until
they do.**

**Why:** a "✅ Fixed" was posted to a community thread before mobile was tested; mobile still had
a separate bug with a different mechanism, and it took a second deploy to be truly fixed. The
public claim was premature.

**How to apply:**
- These fixes are usually not verifiable by the agent: test DOMs do no real layout or scroll,
  and the agent can't drive the user's device. Tests *diagnose*; real-device eyes are the verdict.
- Flow: build → deploy → "please confirm on desktop + mobile" → confirmed → THEN log, release
  note, and any public post. Wrong → iterate before any public claim.
- After a premature claim, don't post a second "fixed" — fix it, then edit the earlier message.
