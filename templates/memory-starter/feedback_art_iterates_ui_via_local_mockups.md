---
name: feedback_art_iterates_ui_via_local_mockups
description: "For non-trivial UI/layout changes Art wants a faithful standalone HTML mockup FIRST (real palette/tokens), which he opens via Windows Explorer at the WSL scratchpad path — the terminal has no side panel so SendUserFile 'render' isn't visible inline. Iterate on the mockup, then build → deploy to review live."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7c6bcd6d-078d-492d-b925-4ef8daca1bfd
  modified: 2026-07-22T06:29:13.690Z
---

**Why:** For non-trivial layout/UI work Art prefers to SEE a mockup before I implement. He runs Claude Code in a WSL terminal (NO side panel), so `SendUserFile` with `display:'render'` does NOT show inline — he opens the file via **Windows Explorer** at the WSL `/tmp/claude-.../scratchpad/…html` path instead. He iterates fast and concretely (the Town layout mockup ran ~5 rounds: 1-col→2-col, everything collapsible, warehouse grid→single-col→thin sticky banner, Rest→header-button+modal).

**How to apply:**
1. Build a SELF-CONTAINED HTML mockup that faithfully matches the LIVE palette/tokens — grep `packages/client/src/index.css` for the CSS vars (parchment `#f5ead6`, parchment-dark `#e0ceaf`, oxblood `#8b1a1a`, ash `#7a7065`, gold `#b8860b`, Georgia headings) and reproduce the real panels. Include the light/dark toggle since Art uses dark mode.
2. Make it interactive (layout toggles, collapse-all, theme) so he can compare options.
3. **Overwrite the SAME scratchpad file** across iterations so his Explorer bookmark keeps working; give him the path in text (don't rely on the render card he can't see).
4. Once he approves, implement to match, then build → **deploy** so he reviews it LIVE (he can't preview the real React app any other way; he course-corrects from the live version).
Related: `feedback_marathon_session_style` · `feedback_visual_bug_triage` · `reference_town_layout_sticky_banner`
