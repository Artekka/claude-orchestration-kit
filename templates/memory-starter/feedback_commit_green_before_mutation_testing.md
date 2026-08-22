---
name: commit-green-before-mutation-testing
description: "Mutation-probe discipline, two failure modes from one night — commit GREEN before mutating (checkout-restore wipes uncommitted fixes), and verify the mutant actually APPLIED before trusting a green probe (a silently no-oped sed mutant is indistinguishable from a blind guard)."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9df33afd-48a9-4c91-825f-a3bec8430513
  modified: 2026-08-21T01:10:51.287Z
---

During O80 (2026-08-20, fable-V), the standard mutation pass — apply mutant via
sed, run suite, `git checkout <file>` to restore — was run while the GREEN
implementation was still uncommitted. The checkout restored HEAD, silently
deleting all eight call-site fixes along with the one-line mutant. The work was
re-applied from conversation context and re-verified, but only because every
edit was still in context; after a compaction it would have been a rebuild.

**Why:** `git checkout <path>` restores from HEAD/index, not "undo my last
edit". It cannot distinguish the mutant from the fix — both are just unstaged
changes. The mutation workflow's restore step is only safe when HEAD *is* the
GREEN state.

**How to apply:** the mutation sequence is COMMIT GREEN → mutate → run →
`git checkout` → re-run to confirm restored-green. If for some reason GREEN
cannot be committed yet, restore by re-applying the inverse edit (or sed the
mutant back), never by checkout. Related: [[a-check-that-cannot-fail-is-not-a-check]]
(mutation probes are that check), and the O71 pattern of restore-verifying
between mutants — this rule is its precondition.

**Second failure mode (same night, O7-pair roundtrip): a mutant that never
applied.** A chained-sed mutant (multiline pattern sed can't match) silently
no-oped; the probe ran green and read exactly like a blind guard — hours after
the verifier had caught a genuinely dead guard, the near-miss inverted:
almost condemning a working guard on a phantom mutant. **A green mutation run
proves nothing until you've confirmed the mutant is on disk** (grep for it, or
apply mutants with the Edit tool, which errors instead of no-oping). sed
chains piped through grep hide both the no-op and the evidence.
