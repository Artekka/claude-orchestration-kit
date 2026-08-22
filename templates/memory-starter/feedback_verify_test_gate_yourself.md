---
name: feedback_verify_test_gate_yourself
description: "Don't trust piped or incomplete test-gate signals — run the real gate yourself before committing/deploying"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 979600c3-be55-459a-be89-9f706a797b8b
---

Two false-green traps hit the v0.36–0.38 marathon (2026-06-08); both could green-light a broken prod deploy.

1. **`pnpm test … | tail -N` masks the real exit code.** In a `run_in_background` Bash task, piping the suite through `tail`/`head` makes the task-completion **exit code = `tail`'s (0)**, NOT pnpm's — so a *failed* suite was reported as "exit code 0." The truncated tail also dropped the `Tests N passed | M failed` line. **How to apply:** never pipe the deploy gate through tail/head when you need the result. Redirect to a file and read both signals: `pnpm test --no-file-parallelism > /tmp/gate.log 2>&1; echo "exit=$?"` then `grep -E "Test Files|Tests |failed" /tmp/gate.log`. (When the masked failure surfaced, a clean re-run confirmed it was the known `reference_integration_tests_flake_under_concurrency` dev-complete/jsonb_merge_sum flake — but only because I re-ran without the pipe instead of trusting the "0".)

2. **Impl subagents that END by kicking off a full `pnpm test` via a background Monitor return a TRUNCATED report.** They come back mid-run ("Now I'll wait for the test-suite Monitor event…") with the done-criteria report absent or unverified — their "GREEN / N passing" claim is not yet real. Hit 2–3× (weapon fix, founder-aspect, persistent-HP impl). **How to apply:** the deploy gate is **mine** to run and read, not the subagent's. After any impl agent, re-verify the edits on disk (grep/read-back) AND run the full-suite gate myself in the main checkout before committing/deploying.

3. **A subagent's "it's a flake, passes in isolation" can be a STALE shared-dist false-failure.** During the v0.55.0 skills epic a subagent reported `townEconomy.test.ts` (two-farms food aggregation) failing in the full suite but "passing 7/7 in isolation — a serial state-bleed flake." It actually FAILED in isolation too (`result.creditedByResource.food` was `undefined`). Root cause: a **stale shared-package dist**. A consuming module resolves its deps through the shared package's BUILT dist, while the test imports the same things from shared SRC — after a multi-phase epic kept changing shared source, the dist lagged src and the two diverged. **Fix:** rebuild the shared package BEFORE the gate (always, but especially after multi-phase shared-source churn); it then passed 3/3 deterministically. So a fresh shared dist is *part of* a trustworthy gate — and when a subagent calls a failure a "flake," reproduce it yourself with a fresh dist before believing the label (here the *conclusion* "not a regression" held, but the *reasoning* was wrong).

**Why:** a bad gate signal → a broken prod deploy. The shared rule: a test-gate result is only trustworthy when *I* produced it, unpiped, with the real exit code + the pass/fail line in hand, on a freshly-built shared dist. Complements `feedback_verify_before_narrate` and `feedback_verify_subagent_failure_claims`.
