---
name: don't trust code comments — trace the actual implementation
description: A code comment describing what a function does is intent, not necessarily implementation. For any "X is rebuilt from Y" claim on a critical path, verify by tracing the load before relying on the invariant.
type: feedback
originSessionId: 3e9750fb-e8f7-4022-8b83-9a818bfe3fd6
modified: 2026-08-20T12:59:38.873Z
---
The Day-15c co-op bug took four deploys to land because I read this comment in `BattleSession.ts` and trusted it:

```
// Held in memory so the intent gate doesn't hit the DB per submitIntent.
// The DB row in battle_unit_controllers is the persisted source of truth;
// this map is rebuilt from it during BattleSession bootstrap.
```

The implementation didn't actually do the rebuild — the constructor just defaulted to `unit.ownerId` for every unit. I assumed the in-memory map was correct (because the comment said so) and spent three iterations fixing downstream symptoms (resumeSession gates, snapshot shipping, client awareness). All three fixes were correct in spirit but couldn't fire because the underlying data the comment promised was actually missing.

**How to apply:**
- For any claim of the form "X is rebuilt from Y", "X is synced with Y", "X is the source of truth and Z is derived" — verify the load/sync path actually exists. Grep for the field name + a SELECT/load/sync verb.
- Pay special attention to constructors that pre-populate fields. "Default" values can quietly mask "should have been loaded from persistent state" intent.
- If a comment describes a non-obvious invariant, the invariant should have a test. If there's no test, the invariant is probably aspirational, not enforced.
- When debugging persistence-related bugs, ALWAYS verify the in-memory representation matches the DB row before assuming the in-memory side is correct.
- The same skepticism applies to **design docs / ADRs**, not just code comments. ADR 0008's recon asserted "no `injuries.ts` data file exists" — but it did (`packages/shared/src/town/injuries.ts`, shipped with the aging subsystem). A build agent that trusts a "not built yet / does not exist" claim will ship a DUPLICATE module. Before creating anything an ADR says is missing, grep for it first (by filename AND by an export/symbol name). "Does not exist yet" is as fallible as "is rebuilt from Y".
- Update or delete misleading comments as you find them. The cost of fixing the comment is small; the cost of a future agent making the same trust mistake is large.

**A HALF-TRUE comment is worse than a false one — 2026-08-19, and it burned two sessions in opposite directions on the same day.**

- `shared/src/tutorial/steps.ts:97` said the `"returned-home"` event was *"already wired in `lib/tutorialEvents.ts`'s `diffToEvents`/`isEventStepAlreadySatisfied`"*. **That is TRUE** — the client emits and handles it. What it does not say, and what I inferred, is that the **server** had no matching gate. I read the comment as proof that the whole mechanism was enforced, and told Art a soft-lock was impossible. It was not.
- The **opposite** error, same file family, same day: a sibling read the *absence* of `STEP_PREREQ["return-home"]` as a bug and proposed adding one — without reading `client/src/components/tutorial/tutorialStepDef.ts:611`, which explicitly authorises it: *"No server prereq blocks any of these steps from a client Next/event — return-home/promote-units/equip-skill are the real event gates."* Their "fix" would have been a design change against documented intent.

**Rule:** a false comment gets caught, because reality contradicts it everywhere. A half-true one is confirmed by every check you happen to run and silent about the half you didn't. So verify the **specific claim you are about to rely on**, not the sentence's general vicinity — and check for a comment authorising an absence before treating that absence as a defect. Both directions are the same mistake: substituting prose for a trace.

Related: `feedback_tests_that_ratify_the_defect` — the same substitution, but in a test rather than a comment.
