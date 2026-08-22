---
name: feedback_confirm_ui_fix_on_device_before_claiming
description: "Don't claim a visual/UX fix is 'fixed' — especially in a public Discord reply — before Art confirms it on his real device. Ship, ask Art to verify on desktop AND mobile, THEN post the shipped/fixed note."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b161d6ee-a2ec-45b9-9659-ef4739f44507
  modified: 2026-08-05T21:01:22.774Z
---

For CSS / layout / scroll / animation fixes: **deploy, then ask Art to confirm on his real device (desktop AND mobile) before claiming "fixed" — and hold the public/community "shipped" post until he does.**

**Why:** 2026-08-05 — I posted "✅ Fixed in v0.242.1" to Numa's #suggestions thread for the resource-banner flicker *before* Art tested mobile. Mobile still had a *separate* slow-scroll "stuck" bug (a different mechanism: per-event-velocity anchor vs the flicker's scroll-anchoring loop). So the public "fixed" claim was premature; it took a second deploy (M358) to be truly fixed. Over-claimed to a real community member.

**How to apply:**
- These fixes are **not verifiable by the agent**: jsdom does no layout/scroll-anchoring, and the agent has no browser/login to drive prod. Unit tests + the `/analyze-attachment` pipeline *diagnose*, but **real-device eyes are the verdict**.
- Flow: build → deploy → "please confirm on desktop + mobile" → Art confirms → THEN Felix-log + patch note + community "shipped" post. If it's wrong, iterate before any public claim.
- A same-issue refinement after a premature claim: don't spam a second "fixed" — fix it, then the earlier claim becomes true (or edit it; Discord messages are editable).

See [[reference_town_layout_sticky_banner]] (the banner scroll bugs), [[reference_discord_bot_thread_read_write]] (posting), [[feedback_verify_before_narrate]].
