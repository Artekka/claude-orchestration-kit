---
name: feedback_deployed_but_not_visible_check_bundle
description: "'I deployed but my change doesn't show' → curl the LIVE bundle for a marker string before assuming a deploy/code bug; usually browser cache (nginx index.html now no-store)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c4febdde-a9d3-4e36-ab4c-ed0325651d23
  modified: 2026-08-13T15:13:11.471Z
---

When Art reports a shipped change isn't visible ("I don't see the toggle"), DON'T assume the deploy or code is broken. **First verify the live bundle actually contains the change**: `curl -s https://the project.artekkaos.com/ | grep -oE '/assets/[^"]+\.js'` to find the hashed bundle, then `curl` it and `grep` for a unique marker from your change (a string literal, localStorage key, label). If the marker is present, the deploy worked and it's **browser cache** — Art (esp. on mobile Chrome) needs one hard refresh / clear-site-data, OR open in Incognito to confirm instantly.

**Why:** 2026-06-15 the stat-potential dev toggle "didn't show up" for Art; the bundle was live and correct — his mobile Chrome had cached a stale `index.html` that still pointed at the old hashed JS. Root cause: nginx served `index.html` with NO cache header (a comment claimed it shouldn't be cached, but nothing enforced it), so browsers heuristically cached the entrypoint and never fetched the new bundle. **FIXED (commit 0cf2067):** `infrastructure/nginx/nginx.prod.conf` now serves `index.html` with `Cache-Control: no-store, must-revalidate` (hashed assets stay `immutable`), so every load re-fetches the entrypoint and future deploys self-update — but a browser that already cached the old no-header index.html still needs ONE refresh to adopt the new policy.

**How to apply:** for any "deployed but not visible" report — (1) curl+grep the live bundle for the marker, (2) if present → cache, tell Art to hard-refresh/Incognito, (3) if absent → real deploy/build gap, investigate. Don't speculate-fix code for what is a cache miss. Related: [[reference_secure_context_browser_apis]], [[feedback_surface_errors_onscreen_no_devtools]].

**Marker-choice gotcha (2026-08-12, v0.272.0):** RUNTIME-DERIVED strings never appear as bundle literals — a Codex line assembled from live imports ("Tannery for leather" via BUILDING_CATALOG lookup, "any of Mend, …" via a join helper) greps EMPTY in the built chunk even though the feature is live. The better the live-sourcing discipline, the fewer greppable literals it leaves. Pick markers that are STATIC prose/labels from the change (section titles, hint copy, a distinctive sentence); an empty grep on a derived string is not evidence the deploy missed.

**2026-08-19 — TWO false-negative modes make bundle-grepping unreliable as a deploy check.** Both bit real sessions in one night:

1. **Minification renames source identifiers.** Grepping a prod bundle for `computeCameraTarget` / `presentedActiveUnitId` returns **zero hits on code that shipped fine**. Never verify with a function/variable name.
2. **Code-splitting puts strings in a chunk you did not fetch.** `v0.277.0` and the whole patch-note list live in `AppShell-*`, not the entry bundle; page copy lives in `WorldMapPage-*` / `TownPage-*`. I read four live things as "absent" purely from reading the entry.
3. **The chunk hash changes every build** — reusing an `AppShell-<hash>.js` name from an earlier check fetches nothing, and an empty file greps as 0. **Re-derive chunk names from the CURRENT entry bundle every time.**

**What actually works:** a **user-facing string** in the chunk that owns it, plus **build provenance** (`docker inspect <container> --format '{{.Created}}'` vs the HEAD commit time, on a clean synced tree). Make the check **two-sided** where a claim was corrected — assert the new copy is present AND the old wording returns 0 — and include one **pre-existing** marker as a regression check, so a build that ships your change while dropping someone else's cannot read as success.

Related: [[reference_stale_chunk_after_deploy]], [[feedback_a_check_that_cannot_fail_is_not_a_check]], [[reference_multisession_reconcile_discipline]]

## ⚠ THE MARKER GREP HAS THREE FALSE-NEGATIVE MODES (added 2026-08-19, all three hit in ONE session by two sessions independently)

The advice above is right in spirit and **incomplete in practice**. A correct, healthy deploy reads as broken in three separate ways, and each one cost real time:

1. **Code-splitting.** The marker lives in a lazily-loaded chunk, not the entry bundle. `v0.277.0` sits in `AppShell-*.js`; the Codex shield list sits in `CodexPage-*.js`. Grepping `index-*.js` reports "missing" for content that shipped fine.
2. **Minification.** Source identifiers are RENAMED. `computeCameraTarget` / `presentedBuffSource` / `presentedActiveUnitId` return **zero hits despite shipping**. Never grep a function or variable name against a production bundle.
3. **Stale chunk hash.** Chunk filenames are content-hashed and change every build, so reusing an `AppShell-<hash>.js` name from an earlier check fetches nothing — and an empty body greps as 0, which is indistinguishable from a failed deploy.

**The recipe that survives all three (opus-6's, better than the original advice):**
- Grep the **container's asset directory**, not a single fetched file: `docker exec the project-web-prod grep -rl '<marker>' /usr/share/nginx/html/assets/`
- Use a **user-facing string** (or a `data-testid`, or an asset content hash) — never a source identifier.
- Make it **two-sided wherever copy was corrected**: assert the NEW wording is present AND the OLD wording returns 0. Presence alone does not prove the wrong claim is gone.
- Include **one PRE-EXISTING marker as a regression check**, so a build that ships YOUR change while dropping a sibling's cannot read as success. This is the clause most likely to be skipped and the only one that catches the shared-checkout failure mode.
- Cross-check with **build provenance**: `docker inspect -f '{{.Created}}' the project-web-prod` vs `git log -1 --format=%cI <commit>`, on a clean synced tree. This is the most reliable single check and needs no marker at all.

**Provenance caught a real miss:** a sibling's deploy at 06:02:48 UTC included a sprite commit at 05:52 and **missed a camera commit at 06:05 by three minutes**. Nothing in the bundle would have told you; the timestamps did.

See [[reference_deploy_builds_from_working_tree]] — the working-tree build is WHY a three-minute gap changes what ships.
