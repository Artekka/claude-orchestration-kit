---
name: a blanket approval covers the whole task, not just one prompt
description: When Art gives a "proceed, don't ask me for each file write" approval, honor it for the duration of the current task rather than treating each subsequent permission gate as a fresh question
type: feedback
originSessionId: 3e9750fb-e8f7-4022-8b83-9a818bfe3fd6
---
Day-15 statusline-setup sequence: I delegated to a sub-agent which then hit a permission prompt for writing to `~/.claude/`. Art said "Proceed and please don't ask me for each file write. Just do it. Thanks!" After that, the harness still surfaced a per-Write prompt for the same files, and I treated the prompt as a fresh decision point rather than continuing under the blanket approval.

**Why:** mild but real friction — Art had to either re-approve each write or feel like he was being asked the same question twice. The fix isn't only on the harness side (which gates writes outside the project dir); it's also on me to acknowledge the blanket approval explicitly and execute under it rather than pausing on every gated tool call.

**How to apply:**
- When Art gives a blanket approval ("just do it", "stop asking", "proceed without prompting"), interpret it as scoped to the immediate task and any directly-required actions to complete it.
- If a permission system still surfaces a prompt, don't re-ask Art for confirmation — note the prompt is from the harness and proceed if the action is within the approved scope.
- Don't escalate sub-agent denial messages back to Art for re-approval if Art already approved the parent task. The sub-agent's gate is a different system; reaching back to Art for the same decision is the friction Art was trying to avoid.
- If the scope of what was approved is genuinely ambiguous (e.g., approval was for one file but the task now needs to touch a different one), THEN ask — but make it clear what the new ambiguity is, not just "should I write this file?"
- Blanket approvals don't extend across sessions. A new conversation resets the default.
