---
name: release-notes-user-language
description: Release notes must read in concise HUMAN language — dev jargon ('ack', 'NOTIFY', 'reconcile', 'worktree', internal row IDs) is banned from user-facing copy; re-read every entry as a user who has never seen the codebase
metadata:
  type: feedback
---

The human's ruling (origin project, 2026-08-20), after a live note shipped "the ack is your receipt": *"can we PLEASE be using concise, human readable verbiage? 'Ack' means nothing to a user. I know what it means because I'm a dev and PM but that's not something a human would say."* Hot-fixed same day.

**Why:** release notes are the friendly summary users actually see. The origin file's own header already said "no internal jargon" — the rule existed and was violated anyway, so it must be a checked habit, not a header.

**How to apply:** before shipping any release-notes entry, re-read it as a user who has never seen the codebase: no "ack", "NOTIFY", "queue row", "board", "reconcile", "worktree", "cron", "sweep"-as-jargon, no internal row IDs. Say what the user sees and what changed for them, in full sentences. Any user-facing bot/notification templates deserve the same read.
