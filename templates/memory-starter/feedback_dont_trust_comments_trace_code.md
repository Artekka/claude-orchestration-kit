---
name: feedback_dont_trust_comments_trace_code
description: A code comment describing what a function does is intent, not necessarily implementation. For any "X is rebuilt from Y" claim on a critical path, verify by tracing the load before relying on the invariant.
metadata:
  type: feedback
---

A multiplayer bug took four deploys to fix because a comment said an in-memory map "is
rebuilt from the DB row during bootstrap". It wasn't — the constructor just filled in
defaults. Three rounds of downstream fixes were correct in spirit but could never fire,
because the data the comment promised was missing.

**How to apply:**
- For any claim of the form "X is rebuilt from Y", "X is synced with Y", "X is the source of
  truth and Z is derived" — verify the load/sync path exists. Grep for the field name plus a
  load/select/sync verb.
- Watch constructors that pre-populate fields: a default can quietly mask "should have been
  loaded from persistent state".
- A non-obvious invariant described in a comment should have a test. No test ⇒ probably
  aspirational, not enforced.
- The same skepticism applies to design docs: "X does not exist yet" is as fallible as "X is
  rebuilt from Y". Grep (by filename AND by exported symbol) before creating something a doc
  says is missing, or you ship a duplicate module.
- Fix or delete misleading comments when you find them.

**A HALF-TRUE comment is worse than a false one.** A comment said an event was "already wired"
— true on the client, silent about the server having no matching gate. Read as proof the
whole mechanism was enforced, it led to a wrong "this can't happen" answer. The opposite error
happened the same day: treating an *absence* as a bug when a comment elsewhere explicitly
authorised it.

**Rule:** verify the **specific claim you are about to rely on**, not the sentence's general
vicinity — and look for a comment authorising an absence before treating that absence as a
defect. Both directions are the same mistake: substituting prose for a trace.
