---
name: feedback_patch_notes_player_language
description: "Art's ruling 2026-08-20 — patch notes must read in concise HUMAN language; dev jargon ('ack', 'NOTIFY', 'reconcile', 'worktree') is banned from player-facing copy"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3180df04-6528-4e84-8c6d-655efa30816c
  modified: 2026-08-20T20:29:59.255Z
---

Art, 2026-08-20, after reading the v0.279.0 note: *"in patch notes can we PLEASE be using concise, human readable verbiage? 'Ack' means nothing to a user. I know what it means because I'm a dev and PM but that's not something a human would say."* The offending line was "the ack is your receipt" — shipped live and hot-fixed same day.

**Why:** patch notes are the friendly summary players see in the lobby What's New modal; `the release-notes file`'s own header already says "Highlights only, no internal jargon" — the rule existed and was violated anyway, so it needs to be a checked habit, not a header.

**How to apply:** before shipping any `the release-notes file` entry, re-read it as a player who has never seen the codebase: no "ack", "NOTIFY", "queue row", "board", "reconcile", "worktree", "cron", "sweep" (as jargon), no internal row IDs. Say what the player sees and what changed for them, in full sentences. Discord-facing bot reply templates deserve the same read. Related: [[reference_patch_notes_one_time_popup]], [[feedback_parallel_agent_patchnotes_consolidation]].
