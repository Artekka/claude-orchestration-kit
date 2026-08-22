---
name: feedback_doc-agent_diff_must_be_append_only
description: "the doc agent/tech-writer subagents can REPLACE build-log.md with a stub instead of appending — always check git diff --stat before committing their edits: thousands of deletions on build-log.md = clobber; also verify milestone number against the file's real tail (two sessions briefed M384 concurrently)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6ca712aa-f5e7-4637-87dd-e3bb67427a15
  modified: 2026-08-12T20:32:30.207Z
---

Two the doc agent (tech-writer subagent) failure modes hit on 2026-08-09, both caught before commit. **RECURRED 2026-08-11 (M396, fable-M):** the doc agent again replaced the ~30.6k-line build-log with an 87-line stub — its own completion report even claimed "appended, lines 30630-30754" while the working tree held only the stub, so NEVER trust the report; only the diff. Salvage recipe that worked: `awk '/^## Milestone <N>/,0' build-log.md > scratch/entry.md` → `git checkout -- the project build log` → `printf '\n---\n\n' >> build-log.md && cat scratch/entry.md >> build-log.md` → re-check `git diff` shows pure + lines.

1. **Whole-file clobber:** fable-G's the doc agent replaced the entire ~29k-line `the project build log` with a placeholder stub containing only its new entry. Detected by the line-number smell (new milestone heading at line 7) — restored from HEAD and re-appended. Same subagent also fabricated a branch name (see [[feedback_subagent_docs_fabricate_specifics]]).
2. **Milestone-number race:** two concurrent sessions both briefed their the doc agent as "M384"; the second had to renumber to M385 mid-flight after a cross-session ping.

**Why:** the build log is the project's institutional memory; a clobbered log or duplicate milestone silently destroys/forks it, and `git commit` makes it official.

**RECURRED AGAIN 2026-08-12 (M401, fable-O)** — third strike: the doc agent overwrote the ~31k-line log with a 100-line fragment, but this time SELF-REPORTED the accident and the redo was made safe by PREVENTION MECHANICS in the resume message, which worked cleanly and should be in EVERY the doc agent dispatch brief from the start:
- **"NEVER use Write on build-log.md. Use Edit: Read only the final ~30 lines, then Edit with old_string = the exact final lines and new_string = those lines + your entry."** (Structurally append-only — Write requires holding a 31k-line file that never fits in a subagent's read.)
- **"After the edit, run `git diff --stat` yourself and confirm insertions-only + `wc -l` still ~31k; if anything looks off STOP and report, do not repair."**
Recovery when it happens anyway: nothing committed is ever lost — `git checkout -- the project build log` restores instantly; the entry content survives in the agent's transcript for the redo.

**How to apply:** put the two prevention lines above in every the doc agent dispatch brief; then after ANY the doc agent dispatch and BEFORE committing:
- `git diff --stat` — build-log.md must show ~only insertions. Hundreds+ of deletions = clobber → restore from HEAD, re-append.
- Verify the new heading's number = the file's actual last heading + 1 (`grep -oE '^## (Day|Milestone) [0-9]+' the project build log | tail -1`), especially when sibling sessions are active.
- Spot-check named commits/branches in the entry against `git log` (fabrication risk).
Related: [[feedback_commit_doc-agent_doc_edits]] · [[build_log_milestone_numbering]]
