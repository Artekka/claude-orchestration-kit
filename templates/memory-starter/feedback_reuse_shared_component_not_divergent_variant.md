---
name: feedback_reuse_shared_component_not_divergent_variant
description: "When two screens should look/behave the same, feed the ONE shared component the same real data — do NOT add a read-only/variant prop path; Art hates multiple elements to change every time"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cf48ef7f-c710-4b18-af62-2c71ba5d6cdb
  modified: 2026-08-06T19:46:40.654Z
---

**Art's rule (2026-08-06):** "The expedition character panel should be IDENTICAL to the in town character panel. no clue why it isn't reflecting it 100% but we should be reusing the same code or pointing to the same thing so we don't have multiple elements that we have to change code for every time."

**The trap I nearly fell into:** the expedition card already used the SAME `UnitDetailModal` as Town, but was fed `inventory={[]}` + no-op handlers, so gear showed blank. My first instinct was to add a `readOnly`/`equipmentReadOnly` variant path to the shared component. **That is exactly the divergence Art doesn't want** — a second code path to maintain.

**The right fix:** feed the shared component the SAME real data the other caller does (real inventory + real handlers + real subWeaponId). If the component secretly reads from a store (coupling), make that an optional prop so a second caller can pass its own state — don't fork the component. Result: one component, one behavior, one place to change.

**How to apply:** before adding a `variant`/`mode`/`readOnly` prop to make two callers differ, ask "can I instead make them pass the same data?" Divergence in DATA at the call site is fine; divergence in the COMPONENT (new branches/props to look different) is the smell. See the M359 expedition-equipment fix. Related: `feedback_surface_all_state_changes`.
