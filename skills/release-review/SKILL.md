---
name: release-review
description: Harden a project before a release, run by the SEAT once fast iteration is done — freeze features, review the human's decisions for staleness, check every request against the code, have a non-builder write LOCKED release tests from the decisions, prove each test can fail, attack the build, give every area a fresh-eyes code review, fix everything found through normal rows, refresh the README and docs, write an optional acceptance checklist for the human, then release. Runs ONLY when the human types /orchestration-kit:release-review — never on Claude's own judgment.
disable-model-invocation: true
---

# release-review

Iteration rows are judged by a reviewing session; a release is judged by **tests nobody who builds can edit**. This skill turns a fast-built project into a release the seat can stand behind. It starts only from the human's explicit `/orchestration-kit:release-review` (optionally with the version); a request in plain words ("are we ready to ship?") gets the command named back, not a review. It runs as a **train of rows** on the normal board: every step below is one or more rows, briefed, assigned, verified and reconciled exactly as `/orchestration-kit:orchestrate` says. Only the seat runs this skill.

Paths come from `docs/orchestration/ORCHESTRATION.md` → **Release** (defaults in brackets): the decisions log [`docs/orchestration/DECISIONS.md`], the release tests dir [`tests/release/`], the review dir [`docs/orchestration/release/<version>/`]. `H` below = this skill's base directory (printed above this text when it loads); `lock.sh` lives there and takes NAMED variables only.

## 0 · Freeze

1. Pick the version (`<version>`) and create the review dir. Post a **`RELEASE REVIEW <version> — feature freeze`** line in the seat banner and commit it (board-write recipe). From now on new feature asks are recorded for the next cycle, not built; only rows this review creates are assigned.
2. Write `<review dir>/REVIEW.md` with a heading per step below. It is the record: each step fills its section with what was checked, the counts, and the row ids it spawned.

## 1 · Decisions review

Read the decisions log. For every **active** entry, mark it:

| Mark | When |
|---|---|
| `ok` | confirmed within the decision-check window (§2 of the orchestrate skill: 10 closed rows or 7 days, whichever comes first) and nothing contradicts it |
| `stale` | not confirmed within the window |
| `contradicted` | the code does something else, or a later request or decision says otherwise |

Ask the human about every `stale` and `contradicted` entry **in plain text, numbered, at most four per message** ("D-007, 2026-09-02: 'refunds take 3 days'. Still right? yes / change to …"). Never a pop-up menu. With `questions: non-blocking`, carry on with the steps that don't depend on an open answer and park the rest under the banner's `HUMAN QUEUE`. A confirmed entry gets its `Last confirmed` date moved; a changed one gets a new superseding entry. No decisions log yet → build one first from the repo, the board archive and the log, mark every entry `(reconstructed)` and ask the human to confirm them as a batch.

## 2 · Scope check

One **verifier** row (never the seat, never a builder of this cycle): build `<review dir>/SCOPE.md` from scratch: one line per decision and per closed row's acceptance item → where it lives in the code (`file:line`) → `present` / `missing` / `changed` / `extra` (code that no request or decision asked for). The enumeration is the deliverable (LESSON 42). Every `missing` / `changed` line becomes a fix row; every `extra` line goes to the human as a keep-or-remove question.

## 3 · Locked release tests

1. One **test-author** row, assigned to a session that built nothing in this cycle: write tests under the release tests dir that pin each active decision and each `present` scope line to its required behavior. Expected values come from the decision text, never from running the code (a test that copies today's output ratifies today's bugs). Cite the decision id in each test's name or comment. Tests that fail on the current code are findings, not mistakes: leave them failing and list them.
2. Reconcile that row, then lock what landed and commit the manifest:
   ```bash
   MODE=lock DIR=tests/release MANIFEST=<review dir>/LOCKED.sha256 bash "$H/lock.sh"
   ```
3. From here **every row's acceptance includes the lock check**, and `/orchestration-kit:reconcile` refuses a row when it fails:
   ```bash
   MODE=check MANIFEST=<review dir>/LOCKED.sha256 TREE=<worktree> bash "$H/lock.sh"   # exit 0 = untouched
   ```
   A builder who believes a locked test is wrong stops and messages the seat. Only the human can approve changing one: the test-author fixes it in its own row, and the seat re-locks and records the change in REVIEW.md.

## 4 · Prove the tests can fail

One row per release test file (batch small files): `/orchestration-kit:falsify` with at least one mutant per test, wide first. A test that survives its mutants is a hole: back to the test-author. Record kill counts in REVIEW.md.

## 5 · Attack

One **attacker** row: try to break the build without reading the builders' reasoning. Bad and edge inputs, empty and huge data, malformed files, repeated and concurrent actions, interrupted saves, missing network or credentials, the first run on a clean machine. Every reproducible break becomes a failing test (test-author) plus a fix row. Report the non-findings too (LESSON 49).

## 6 · Code review

Split the code into areas (by directory or feature, each small enough for one session). One **fresh-eyes review** per area by a session that did not build it, with the contract only (decisions log + SCOPE.md + the area's files), using the `verifier` agent's four checks. Findings go to the seat, which turns real ones into fix rows; verdicts state DERIVED or CONSISTENCY-CHECKED.

## 7 · Fix

Every finding from steps 1–6 is a normal row: brief, fence, build, sibling verify, reconcile. Each row's acceptance: its finding fixed, the full gate green, **the lock check exit 0**, and the release tests it targets now pass. Loop until every release test passes and every finding is fixed or explicitly deferred by the human.

## 8 · Clean up and document

One cleanup row (dead code, stray debug output, leftover flags, unused files — no behavior change, gate and lock check unchanged). One docs row: the README (what it is and its state, how to run and release it, the layout, how work is done here, where decisions live, status), the changelog, the status doc. Docs claims are checked against the repo, like log entries (LESSON 23).

## 9 · Acceptance checklist (optional for the human)

Write `<review dir>/CHECKLIST.md`: numbered, plain-language things the human can try, one per active decision and per user-visible feature ("Open the app, add a refund, check the date shown is 3 days ahead — D-007"), each with what they should see. Send the human the path and say it is optional. **The release never waits on it**; if the human reports a problem from it, that is a new fix row.

## 10 · Release

When every release test passes, the lock check is clean, every finding is fixed or deferred, and the docs row has landed: bump the version, tag it, and deploy per ORCHESTRATION.md → Deploy (`deploy_policy`). Close REVIEW.md with a summary (rows run, findings fixed, findings deferred, tests locked and their kill counts, known risks), then **unlock**: remove the `RELEASE REVIEW` line from the banner (that is what switches off the lock check in reconcile and lifts the feature freeze) and keep `LOCKED.sha256` in the review dir only as the record. Tell the human in a few lines with the review dir's path.

## Rules

- No step is skipped silently: a skipped step is a line in REVIEW.md saying why and who agreed.
- Roles never mix within the review: the test-author does not fix, the attacker and reviewers do not fix, builders do not edit locked tests.
- The lock lasts for the review only. After release the code and the release tests are open again: the release tests stay in the normal gate, so later work must keep them passing, and changing one is an ordinary row whose brief says why (a release test pins a decision the human made). The next release review re-locks them.
