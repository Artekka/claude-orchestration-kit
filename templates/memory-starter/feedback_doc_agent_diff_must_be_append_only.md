---
name: doc-agent-diff-must-be-append-only
description: A delegated doc agent can REPLACE a long append-only log with a stub instead of appending — check git diff --stat before committing its edits (any deletions on the log = clobber), verify the entry number against the file's real tail, and fact-check named commits/branches (fabrication risk)
metadata:
  type: feedback
---

Three separate incidents of the same failure (origin project, 2026-08: a ~30k-line build log replaced by an 80–100-line stub — once with the agent's completion report claiming "appended, lines 30630–30754" while the tree held only the stub). NEVER trust the report; only the diff. A concurrent-session variant also exists: two sessions briefing the same next entry number.

**Why:** an append-only log is institutional memory; a clobber or duplicate number silently destroys/forks it, and `git commit` makes it official.

**How to apply — prevention lines that belong in EVERY doc-agent dispatch brief:**
- "NEVER use Write on `<log path>`. Use Edit: Read only the final ~30 lines, then Edit with old_string = the exact final lines, new_string = those lines + your entry." (Structurally append-only — Write requires holding a file that never fits in a subagent's read.)
- "After the edit, run `git diff --stat` yourself and confirm insertions-only and the line count still ~matches; if anything looks off STOP and report, do not repair."

**Before committing ANY doc-agent edit:**
- `git diff` on the log must show only insertions (`git diff -- <log path> | grep -c '^-[^-]'` = 0). Deletions = clobber → restore from HEAD, re-append (the entry content survives in the agent's transcript).
- Verify the new entry number = the file's actual last number + 1 (grep the heading pattern, tail -1) — especially with sibling sessions active.
- Spot-check named commits/branches/counts in the entry against `git log` and reality — delegated writers fabricate specifics.
