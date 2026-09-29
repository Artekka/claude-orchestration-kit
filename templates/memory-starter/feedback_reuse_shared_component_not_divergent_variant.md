---
name: feedback_reuse_shared_component_not_divergent_variant
description: When two screens should look/behave the same, feed the ONE shared component the same real data — do NOT add a read-only/variant prop path that must be maintained separately
metadata:
  type: feedback
---

The ask: "screen B's panel should be IDENTICAL to screen A's — reuse the same code so we don't
have multiple elements to change every time."

**The trap:** screen B already used the same component, but was fed empty data and no-op
handlers, so it rendered blank. The first instinct was to add a `readOnly` variant path to the
shared component — exactly the divergence the ask was trying to prevent.

**The right fix:** feed the shared component the SAME real data the other caller does. If the
component secretly reads from a store, make that an optional prop so a second caller can pass
its own state — don't fork the component. One component, one behavior, one place to change.

**How to apply:** before adding a `variant`/`mode`/`readOnly` prop to make two callers differ,
ask "can they pass the same data instead?" Divergence in DATA at the call site is fine;
divergence in the COMPONENT is the smell.
