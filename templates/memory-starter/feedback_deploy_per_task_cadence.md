---
name: feedback_deploy_per_task_cadence
description: "Art's working cadence — ship each task the moment it's green (commit + /deploy, not batched). He playtests visual/UX changes himself; accepts logic/test-verified fixes without a manual playtest. Expect fast visual-tweak rounds."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ec67850d-a2f5-4f9e-888e-7da6c8c7e732
---

Art works the task board one item at a time and wants each shipped immediately: commit + **deploy to prod** as soon as it passes typecheck/build/tests — he tests on the live site, so don't batch deploys.

**Agent-run deploys AUTHORIZED (2026-06-06):** Art wants the agent to run `bash scripts/deploy.sh` directly, not hand it back. Attempt the deploy; only fall back to "you run `! bash scripts/deploy.sh`" if the auto-mode classifier denies it (it's a separate gate — see [[feedback_automode_blocks_self_deploy_and_permission]]).

**How to apply:**
- **Visual/UX changes** (markers, banners, keyboard feel, layouts, colors): keep the task `in_progress` until his own playtest thumbs-up, THEN finalize (patch notes + Felix build-log + mark done). He often tests "later / at home."
- **Logic/data fixes that are unit-test-verified** (e.g. replay combat-log, per-unit aggregation): he accepts these on test + framework-parity evidence without a manual playtest — close them out.
- Expect quick **visual-tweak rounds** ("make the navy darker", "arrow a bit bigger") — a small edit + redeploy is the loop, not a big redesign.

**Code-only deploys (no new art) can skip the asset rebuilds:** the `/deploy` skill always runs sprites:build/audio:build/maps:build, but for a pure code/schema change (no new sprite/audio/Tiled-map SOURCE) those are idempotent no-ops that only churn the manifest `generatedAt` timestamps → a pointless extra commit. For such a change, skip the asset steps and just `git push && bash scripts/deploy.sh` (deploy.sh pulls origin/main + reinstalls + rebuilds containers). Validated on the v0.42.0 armor deploy (pure TS/schema). Still run the full-suite gate + commit/push first; only the sprite/audio/map builds are what you skip.

**Why:** matches his real-time testing flow; batching or gating test-verified logic on manual playtest just slows him down. See [[branch_before_main_push]], [[reference_artekkaos_task_board_sync]].
