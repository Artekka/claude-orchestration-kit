---
name: new-test-output-needs-real-gate-stage
description: "A change that ADDS test output (new tests, new log lines through real loggers) needs one pass through the real gate.sh stage, not just direct suite runs — run_checked greps stage OUTPUT, so output is part of the interface"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2e45a8bb-b2e2-4cb6-81aa-e88b591b612e
  modified: 2026-08-21T19:00:43.352Z
---

A change that ADDS test output — new tests, or code whose tests route real log lines to the console — must get one pass through the **real `pnpm gate` stage**, not just direct `vitest run` invocations of the affected suites.

**Why:** `scripts/gate.sh`'s `run_checked` classifies stages by **grepping their captured output** for infra-error signatures (e.g. `removal of container .* is already in progress`). Test output is therefore part of the gate's interface. S1-3 (2026-08-21): FR-9's classifier unit test let `settleTeardownError`'s `console.warn` print a realistic 409 fixture string; the string matched the classifier regex, and every session's gate false-REDed at a PASSING repo-unit stage (1794+16, exit 0), deterministically. The author (S2) had gated fully BEFORE the delta that added the test, then re-ran only the affected suites directly — so the grep never saw the new output until a sibling's gate did.

**How to apply:** after any delta that adds tests or test-visible log output, run the real gate (or at minimum pipe the suite output through the classifier regex set from `run_checked`) before hand-off. In tests that exercise warn/error paths through real loggers, spy-capture the logger AND assert it fired — output stays clean and the test proves more. Never reword a fixture away from the real message text just to dodge a classifier — that makes the classification test unreal; capture the output instead. See [[fr9-liveness-aware-sweep]].
