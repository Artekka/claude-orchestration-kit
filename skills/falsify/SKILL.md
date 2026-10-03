---
name: falsify
description: Prove a guard or test CAN fail, by mutation — commit GREEN first, apply a diff-verified mutant, write the prediction BEFORE the run, observe the predicted red unfiltered, restore byte-clean, re-green. Use whenever a new guard/test lands ("prove it red", "falsify the guard", "mutation-test this"), when a verifier asks for red proofs, or before calling any check load-bearing. A check that cannot fail is not a check.
---

# falsify

One pass per mutant. Test command = the project's gate from `docs/orchestration/ORCHESTRATION.md` (or the narrowest command that runs the guard). Mutants are transient: never committed, never left applied.

## Steps

```bash
# 0. COMMIT GREEN FIRST — refuse, don't just look. A restore to HEAD deletes uncommitted work.
git diff HEAD --quiet || { echo 'UNCOMMITTED — commit GREEN first'; exit 1; }

# 1. BASELINE — run the exact command you will use per mutant; read the pass COUNT, not "it passed".
<test command>            # same command, flags and directory for every mutant
#    Prove the instrument SEES the subject: the file is collected by the runner, derived artifacts
#    are built, the filter matches ≥1 test. A blind instrument scores every mutant as a survivor.

# 2. PREDICT — write it down BEFORE running (in the row, a scratch file, or your reply):
#    tests that must go RED (names + count) AND tests that must stay GREEN (incl. a positive control).

# 3. APPLY — anchored, with a match-count assert. Never a bare sed you hope matched.
python3 - <<'EOF'   # or any tool that can assert the count
P, OLD, NEW = "<file>", "<exact old text>", "<mutant text>"
s = open(P).read(); assert s.count(OLD) == 1, s.count(OLD); open(P, "w").write(s.replace(OLD, NEW))
EOF

# 4. DIFF-VERIFY — the mutant is exactly the intended change, nothing else.
git diff --numstat; git diff | grep '^[-+]' | grep -v '^[-+][-+]'

# 5. RUN + OBSERVE UNFILTERED — read the FAIL names and counts in the raw output.
<test command> 2>&1 | tail -40     # never grep-only; never infer from the exit code

# 6. RESTORE byte-clean + RE-GREEN
git checkout -- <file> && git diff HEAD --quiet && echo CLEAN
<test command>                     # back to the exact baseline count
```

## Scoring

| Check | Pass condition |
|---|---|
| Prediction | Written before the run. Reds match names + count AND predicted greens stay green. A red-only prediction can't tell a real kill from a broken build |
| Evidence | FAIL lines observed in output — never inferred from exit code or a filtered pipe |
| Applied | `git diff --numstat` non-empty before scoring. A pass with no applied diff is an UNAPPLIED mutant, never a survivor |
| Valid | Zero tests collected / parse error / anchor matched 0 or ≥2 times = broken mutant or ANCHOR MISS — fix it, don't score it |
| Breadth | Reds in tests that cannot depend on the mutated behavior = a broken mutant (e.g. it compiles but corrupts something unrelated). Fix, don't score |
| Restore | Tree clean (`git diff HEAD --quiet`) AND the fix still present AND suite back to the baseline count. Clean alone can't tell "restored" from "deleted" |
| Survivor | Indicts the INSTRUMENT before it exonerates the code: re-check baseline + visibility first. A confirmed survivor is a finding — a hole in the guard |
| Base already red | Score by SET, not exit: mutant's failing set minus the unmutated base's failing set |

## Mutant design

| Mutant | Purpose |
|---|---|
| **Wide first** — strip the whole mechanism | If the guard survives this, it's inert and every narrow mutant told you nothing |
| **Neuter the mechanism** (`false &&`, delete a registry entry) | The guard's core assertion must red |
| **Both directions** (make the condition always-true AND always-false) | Catches guards with an inert leg |
| **Mutate the writers, not just the readers** | Every site that SETS the value; a set scoped to where you were already looking re-tests your belief |
| **Mutate the guard's own machinery** (its collector, regex, scanner) | A guard green with a broken scanner isn't checking what you think |
| **Decompose, don't replay** — channel × population × layer × site | Replaying the spec's named mutants passes by construction |
| **Discriminating mutant** — kills the new test, old one stays green | Proves the new test earns its place, not just that it can fail |
| **Old-guard survival** — run the PRE-fix test against the same mutant | The only proof of a claim that "the old guard was blind" |

## Rules

- **Anchor by line or a unique block, never first grep match.** A wrong anchor gives a false survivor; an escaped char gives an unapplied mutant. Print the resolved line.
- **Probe the fixtures before predicting.** On the unmutated tree, count how many runs reach the mutated line with a non-trivial input; zero reach ⇒ predict SURVIVOR. Keep probes out of the tree (scratch dir) so they can't inflate counts.
- **Re-run the battery after adding any default/fallback.** A fixture whose value equals the fallback makes forwarding and defaulting indistinguishable.
- **A scan for undefined VALUES can't see ABSENT keys.** State the guard as an obligation: what each variant owes, asserted present, tied to the live registry.

## Batteries (3+ mutants)

- **Foreground, chunked to the command timeout. Never background** — a killed run skips the per-mutant restore and leaves a mutant applied.
- After ANY killed or timed-out battery, before trusting the tree: `git diff HEAD --stat`.
- Per mutant: print `git diff --numstat` BEFORE its run, write its result to disk as it completes, restore + assert clean before the next. A driver that writes results only at the end loses everything on a kill.
- Use a machine-readable reporter (JSON / verbose per-test) per mutant so both halves of the prediction are checkable by test id; first assert on the unmutated tree that every id resolves to exactly one test.
- Parameterize the driver's worktree path and echo it per mutant — a reused driver pointing at the old tree scores everything as a miss.
