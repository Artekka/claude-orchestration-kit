---
name: post-feature
description: Run the post-feature checklist after landing a meaningful chunk on a kit-adopted project — gate green, conventional commit, user-facing release note if visible, doc-agent log + status-doc refresh in one coupled pass, matching board row closed, deploy prompt. Use when the human says "ship this", "wrap up", "let's commit", "post-feature", or finishes a chunk and asks what's next.
---

# post-feature

A checklist so no step drops after meaningful work — the dropped step is always the log/status-doc refresh, and that staleness is the #1 cross-session friction. Names (gate command, doc agent, status doc, release-notes file) come from ORCHESTRATION.md.

## Steps

1. **Pre-flight.** Run the project gate for the change class; read the real pass line. Never ship red — fix first.
2. **Stage + commit.** `git status` + `git diff --stat` — show what ships. Explicit paths (never `git add -A`). Conventional type; body = WHY, not what. Messages with quotes/parens → write to `.git/CMSG`, `git commit -F .git/CMSG && rm .git/CMSG`.
3. **Release note (if user-visible).** Add an entry to the project's release-notes surface in USER language — no SHAs, no internal jargon (memory `patch_notes_player_language`). Bump the version per the project's rules. Not user-visible → skip.
4. **Doc agent: log + status doc, ONE pass.** Dispatch the project's doc agent to append the log entry AND refresh the status doc (version, test count, deferred list) in the SAME dispatch — coupling is what stops drift. Brief it with the SHA, one why-paragraph, new totals.
5. **Verify the refresh landed.** Grep the status doc for the new version + test count (verify-before-narrate); the doc agent's diff must be append-only for the log and fact-checked (LESSON 23). Commit the docs yourself.
6. **Close the matching board row** — only if its FULL scope is verifiably live (judge against code + log, not the row's description). Partial → stays open, flagged. No match → say so, don't invent a row.
7. **Deploy prompt.** Remind the human of the deploy vehicle — under an `ORCHESTRATOR ACTIVE` banner, hand the SHAs to the orchestrator instead (deploys are wave-train).

"Skip step N" → exit cleanly; the checklist prevents dropped steps, doesn't force them.
