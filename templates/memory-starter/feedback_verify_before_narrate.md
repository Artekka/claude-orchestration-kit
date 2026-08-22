---
name: verify-before-narrate
description: Confirm edits/results landed on disk before reporting them done; tool transport can fabricate or silently drop file ops
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a418bb8c-dcac-4f7a-8ac7-a7903a9e267b
---

Never report a file change, fix, or finding as done until it is confirmed on disk — read it back, or grep for a unique marker and check the count. In at least one session the tool transport was unreliable: local file reads / bash stdout / the Edit→Read loop intermittently returned **empty, duplicated, or even fabricated** content (e.g. a non-existent README "Documentation" section and a `docs/CONTRIBUTING.md` that didn't exist; bogus spreadsheet/stat tables during analysis). Two `Edit` calls silently failed ("string not found" from a stale view) and were caught ONLY by a follow-up grep-count verification.

**Why:** Narrating a fix as applied when it didn't land — or reasoning on fabricated reads — produces confidently wrong work. The cost of one extra verify call is tiny; the cost of a phantom fix shipping is a regression.

**How to apply:** After every Edit, grep the file for the new symbol and assert the count (e.g. `grep -c "import { CombatLog }"` == 1). For analysis, write results to a file and Read THAT, retrying on empty. Anchor-check numbers against known-good values before reporting (e.g. a known unit's stat line). Network/git/docker/pnpm were reliable even when file ops weren't — trust deploy/curl results, double-check disk edits. Related: `dont-trust-comments-trace-code` (verify claims against reality, not narration).
