---
name: new-test-output-needs-real-gate-stage
description: A change that ADDS test output (new tests, new log lines through real loggers) needs one pass through the real gate stage, not just direct suite runs — gates that classify stage output by pattern make output part of the interface
metadata:
  type: feedback
---

A change that ADDS test output — new tests, or code whose tests route real log lines to the console — must get one pass through the project's REAL gate stage before hand-off, not just direct test-runner invocations of the affected suites.

**Why:** many gate scripts classify a stage by grepping its captured output for infra-error signatures. Test output is therefore part of the gate's interface. Origin incident (2026-08-21): a classifier unit test let a tolerated-error path's `console.warn` print a realistic fixture string; the string matched the gate's infra-error regex, and every concurrent session's gate false-REDed a PASSING stage, deterministically. The author had run the full gate BEFORE the delta that added the test, then re-ran only the affected suites directly — so the gate's grep never saw the new output until a sibling's gate did.

**How to apply:** after any delta that adds tests or test-visible log output, run the real gate (or at minimum pipe the suite output through the gate's classifier patterns) before hand-off. In tests that exercise warn/error paths through real loggers, spy-capture the logger AND assert it fired — output stays clean and the test proves more. Never reword a fixture away from the real message text just to dodge a classifier — that makes the classification test unreal; capture the output instead.
