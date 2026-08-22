---
name: deployed-but-not-visible-check-bundle
description: "'I deployed but my change doesn't show' → verify the LIVE artifact carries a marker from the change before assuming a deploy/code bug — and know the marker grep's false-negative modes (code-splitting, minification, stale chunk hashes); build provenance is the most reliable single check"
metadata:
  type: feedback
---

When the human reports a shipped change isn't visible, DON'T assume the deploy or code is broken. First verify the live artifact actually contains the change; if it does, the usual culprit is browser cache (serve the entrypoint `no-store`; hashed assets stay `immutable` — and a browser that cached the OLD no-header entrypoint still needs one hard refresh to adopt the new policy).

**The marker grep has three false-negative modes** (all three hit real sessions in one night):
1. **Code-splitting** — the marker lives in a lazily-loaded chunk, not the entry bundle; grepping the entry reports "missing" for content that shipped fine.
2. **Minification** — source identifiers are RENAMED; never grep a function/variable name against a production bundle.
3. **Stale chunk hashes** — chunk filenames change every build; reusing a hash from an earlier check fetches nothing, and an empty body greps 0, indistinguishable from a failed deploy. Re-derive chunk names from the CURRENT entry every time.

Runtime-DERIVED strings are a fourth trap: values assembled from live imports never appear as bundle literals — the better the live-sourcing discipline, the fewer greppable literals. Pick STATIC user-facing prose from the change.

**The recipe that survives all of it:**
- Grep the deployed artifact directory as a whole (e.g. `docker exec <web-container> grep -rl '<marker>' <assets dir>`), using a USER-FACING string, never an identifier.
- Two-sided where copy was corrected: assert the NEW wording present AND the OLD wording returns 0.
- Include one PRE-EXISTING marker as a regression check, so a build that ships your change while dropping a sibling's cannot read as success.
- Cross-check **build provenance**: container/artifact created-time vs the commit time, on a clean synced tree — the most reliable single check, needs no marker. (Provenance once caught a deploy that missed a commit by three minutes; nothing in the bundle would have said so.)
