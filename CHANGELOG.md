# Changelog — orchestration-kit

Newest first.

## 0.7.0 — unreleased

Recycling in place. A recycled session now restarts in the SAME terminal tab instead of opening a new
one. Ported from a project that has run this daily (its respawn wrapper, hand-off file, atomic revoke,
account writer, ancestor guard and the seat's detached self-recycle), generalized to the kit's backends and file layout.

### Recycle in the same tab

- **`scripts/sibling-shell.sh <Name> [--mode M] --model M [--effort E] [prompt]` (new):** the respawn
  loop a team tab runs. It starts `claude --name <Name> ...` as a child; when the child exits it looks
  for a hand-off file and, if `recycle-sibling.sh` left one, starts the next session in the same tab.
  No file = a plain `/exit`, and the tab closes as it always did. A crash-loop guard stops it when
  `claude` dies within 5 s twice in a row (a bad model id or a logged-out account), instead of
  respinning forever. The whole loop is parsed up front, so a plugin update that rewrites the file
  under a days-long wrapper cannot make bash resume in the middle of new text.
- **`recycle-sibling.sh` has two modes**, and `--dry-run` (or `DRY_RUN=1`) prints which one with a
  `mode:` line, and the final summary repeats it:
  - **in-place** when exactly one old `claude` exists and its parent is a `sibling-shell.sh` wrapper for
    the SAME name: write the hand-off file (model, effort, permission mode, account, and the prompt as
    one line of base64 so quotes, `;`, `$` and newlines survive), SIGTERM only the old `claude`, and
    wait for a fresh one that is a child of that very wrapper. No terminal is needed.
  - **new-tab** (the old behaviour, now starting the wrapper) when there is no old process, the old one
    was started by hand, several match, `--new-tab` is passed, the seat recycles itself on a machine
    without `setsid` (or its Claude adopts orphaned processes, see below), or an in-place attempt times
    out after 60 s (`RECYCLE_INPLACE_TIMEOUT`).
- **The seat recycles itself in place too.** When the seat runs `recycle-sibling.sh` from its own shell,
  the session it targets is an ancestor of the script, and killing it in place would cut the script's own
  process chain. The script now prints a log path, re-runs a copy of itself detached (`setsid -f`, so it
  is outside the old session's process tree), and exits; the copy waits `RECYCLE_DETACH_DELAY` (2 s) so
  the seat's own command can finish and its transcript flush, then does the normal in-place hand-off. The
  copy keeps the seat's account and writes everything it prints to `<state dir>/<Name>.recycle.log`, the
  path printed first, so a failure after the old session ends is still diagnosable. A copy never detaches
  again; if it cannot get out of the old session's tree within `RECYCLE_DETACH_WAIT` (10 s, e.g. that
  session adopts orphans), it falls back to the new-tab path, which opens the tab before it ends the old
  session. A session not under the wrapper, or a machine with no `setsid` (macOS), uses the new tab as
  before, and `--dry-run` prints `detach: yes|no` beside `mode:`.
- **Safe by construction:** the hand-off is written to a temp file and moved into place; the wrapper
  claims it with an atomic `mv` and the recycler revokes an unclaimed one the same way, so exactly one
  of them wins (a plain `rm` would let a tab open after the wrapper had already started a session, and
  leave two sessions under one name). A same-name `claude` that is not a child of the wrapper never counts
  as the fresh one. A wrapper started for a different name is never taken for yours. The permission mode
  and the account travel in the hand-off, so a recycle keeps both.
- **Every tab the kit opens now runs the wrapper** (`start-team.sh` and the recycle's new-tab path), on
  tmux, WSL, macOS, and Linux emulators, so a team started by the kit recycles in place from its first
  recycle. A session started by hand moves over at its next recycle. Git Bash (cmd.exe windows, no
  `pgrep`) and the `manual` backend keep a bare `claude`. `LAUNCH_NO_WRAPPER=1` turns it off.
- New env: `SIBLING_STATE_DIR` (hand-off dir, default `~/.orchestration-kit/sessions`),
  `RECYCLE_INPLACE_TIMEOUT`, `RECYCLE_CLAIMED_GRACE` (extra wait once the wrapper has claimed the
  hand-off, 30 s), `RECYCLE_POLL_SECS`, `RECYCLE_DETACH_DELAY` (2 s) and `RECYCLE_DETACH_WAIT` (10 s) for
  the seat's self-recycle, `LAUNCH_NO_PROC=1` (use `ps` instead of `/proc`; tests only).

### What is tested where

In-place recycling reads the process tree (`/proc`, else `ps`) and needs `pgrep`. The new suites run on
Linux (and WSL) and say SKIP elsewhere; the `ps` code path macOS would use is exercised by forcing it
(`LAUNCH_NO_PROC=1`), but it has **not been run on a real Mac or in Git Bash**. On WSL, a kit install path
containing a space cannot cross the `wt.exe` command line, so those tabs fall back to a bare `claude`.

### Tests

- `tests/sibling-shell.test.sh` (wrapper: argv order, hand-off relaunch and consumption, byte-exact
  prompt round trip, account per launch, permission mode, crash-loop guard incl. the no-`EPOCHREALTIME`
  clock, refusal of malformed hand-offs, bad arguments exit 64, survives being rewritten mid-run) and
  `tests/recycle-inplace.test.sh` (mode decision, end-to-end in-place, timeout fallback, decoy and
  wrong-name wrappers, the claimed-hand-off race, account inheritance, the self-recycle at depth 1 and 2,
  the `ps` parity path, the wrapper in every backend's tab command; plus the seat's real self-recycle
  with its account and delay, the old session adopting orphans, a slow launcher, no `setsid`, the
  no-detach-twice guard and a session not under the wrapper). Shared helpers in
  `tests/inplace-harness.sh`; every `claude` is a stub and cleanup kills only recorded pids. The test
  sandbox cannot reach a real terminal: it is pinned to non-WSL, non-tmux with `WT_EXE` pointing nowhere, and
  test R0 fails if auto-detect could resolve anything but the stub terminal.

## 0.6.0 — 2026-10-02

A model per lane, leaner builder starts, per-window context marks, and optional multi-account
teams. Ported from a project that ran the same package for a week (its launch flags, briefs,
lean orient and window-aware marks), generalized to the kit's backends and file layout.

### A model per lane

- **`--model M` and `--effort E` on `recycle-sibling.sh` and `start-team.sh`**, on every terminal
  backend (tmux, WSL, macOS, Git Bash/cmd.exe, Linux emulators), implemented once in `lib-launch.sh`
  (`launch_set_model`, `launch_model_flags`, `launch_resolve_model`). **A model is always passed
  explicitly**, so a fresh session never silently inherits whatever the old terminal or the account
  default happened to be; a recycle does not read the old session's model (its account, by contrast,
  is inherited on purpose). Default `opus[1m]`, configurable with `model:` / `effort:` in the
  `team:` block of `ORCHESTRATION.md`; flags override it. `--effort` is passed only when given.
  `--model` must look like `opus[1m]` / `sonnet[1m]` / `haiku` / a full model id and `--effort` is one
  of `low|medium|high|xhigh|max`; anything else exits 64 like `--account`, before anything launches.
  A bad value in the team block is ignored with a warning. `--dry-run` prints both.
  `start-team.sh --model` applies one model to the whole team; per-lane models go through recycle.
- **`skills/orchestrate` §3a, "Model per lane":** a lane table written by work type (heavy
  reasoning/verification → top tier, 1M; routine features/UI → mid tier, 1M; docs/mechanical → small
  tier, never writes facts), and the hybrid subagent policy (bounded jobs → subagents; long builds,
  every verification and user-facing work → sessions; subagents die with their parent). The recycle
  and seat-recycle commands in §9/§10 now carry `--model`.
- **`tests/lean-launch.test.sh`** (88 checks): default, explicit, `--flag=value`, six bad models and
  four bad efforts refused with exit 64, an `orient --brief <ROW>` prompt accepted on POSIX and WSL, no inheritance on recycle (a stand-in running on a different
  model), `start-team` reaching every window, all 16 backends and quoting families, team-block
  default/override/bad value. Mutation-checked: three mutants (default model not passed, validation
  off, model inherited on recycle) each turn it red.

### Leaner starts

- **`/orchestration-kit:orient --brief <ROW>`:** a lean mode for a builder assigned a row. It reads the
  row's brief file and the top of the board only, measures its fill, and sends READY. A full orient
  costs about 100K tokens of a fresh context; the brief already holds what the row needs.
- **READY now carries `model <id>` and `marks <prompt>/<handover>`** next to the fill, so the seat
  can see the lane got the model it asked for.
- **`templates/briefs/`:** `_TEMPLATE.md` (goal, numbered acceptance, fence, seam map, base, gate,
  model/effort, report protocol) and a README. Installed to `docs/orchestration/briefs/` by
  `bootstrap.sh` and kit-init. The seat commits and pushes the brief, then sends an assign message
  that only names the file. `orchestrate` §2 now points at it instead of an inline template.
- **Launch values are validated like input.** A model must start with a letter (`^[a-z][a-z0-9.-]*(\[1m\])?$`), so
  `--model --dangerously-skip-permissions`, `-x` and `.` are refused with exit 64 and never reach the
  `claude` command line, in both scripts and for `model:` / `effort:` in the team block (a bad block
  value now refuses to launch instead of warning and running the default). An empty or missing
  `--model` / `--effort` (`--model`, `--model ''`, `--model=`) is exit 64 too, tracked as "given" apart
  from "empty" so it cannot fall through to the block. `recycle-sibling.sh` refuses unknown flags, a
  `-`-led name or prompt, and a third positional.
- **Lean orient is runnable.** Step 1 is `git fetch` (one retry) then `git show origin/main:<brief>`,
  falling back to the working tree and then to the seat; step 2 extracts the current `ORCHESTRATOR
  ACTIVE` banner section only. READY names the seat and era the builder saw (`saw <seat [ref]> era-<N>`),
  and the brief template has a `seat` row. `tests/lean-orient.test.sh` extracts those commands from the
  skill and runs them against a bare origin, a stale clone and a live-shaped board.
- **Board, log and fact-writing lanes run on the mid model**, never the small one (the small model never
  writes facts). Nowhere does the kit tell a user to bare `/clear` to recycle: a bare `/clear` keeps the
  terminal's old model, so every fallback relaunches with an explicit `--model` (or `/model` first).
- **`templates/CLAUDE-slimness.md`:** why `CLAUDE.md` must stay slim (it is the startup floor, re-read
  every turn of every session) and how: rules in the file, narrative in a dated, linked archive;
  compress rationale, never the command, flag or guard. `CLAUDE-section.md` gains a short "Models"
  note and points at it. `bootstrap.sh` and kit-init install it to
  `docs/orchestration/CLAUDE-slimness.md`, the path the section names.

### Per-window context marks

- **`scripts/ctx-fill.py`:** `--window 1m|200k` (a token count still works). Marks: 1M window →
  350K/400K; **200K window → 120K/150K** (60%/75%; anything in between scales, capped at the 1M
  marks). A transcript naming a Haiku model proves a 200K window, the one model rule that can only
  lower it; Opus and Sonnet record the same string at 200K and 1M, so for them the window stays
  UNKNOWN, both sets of marks are printed, and the verdict is conditional until you pass `--window`.
- **The 200K marks moved from 140K/160K to 120K/150K** everywhere (ctx-fill, `statusline-ctx.sh`,
  the orchestrate table, CLAUDE-section, the ORCHESTRATION template, GETTING-STARTED, GLOSSARY,
  settings-snippets). Why: a seat on a ~200K window died at 175,725 tokens with no handover, so a 160K
  handover left too little room for the retro itself.
- **`tests/ctx-fill.test.sh`** (28 checks) and the extended statusline test (9) pin the marks. Mutation-checked:
  70%/80% marks, the Haiku rule off, and `--window` ignored each turn ctx-fill red.

### Multi-account (optional)

- **`docs/MULTI-ACCOUNT.md`:** run one team across several Claude Code accounts. Each account gets
  its own config dir via `CLAUDE_CONFIG_DIR` (`~/.claude-acctN` convention, a `claudeN` alias).
  Shared links for `sessions/` (the registry `ListAgents` reads, without which other-account
  sessions are invisible and unreachable), `projects/` (memories, transcripts, ctx-fill),
  `skills/` and `agents/`; `settings.json` is copied and `.credentials.json` is never shared.
  Covers the `ln -s`-into-an-existing-dir pitfall.
- **`--account N|DIR` on `recycle-sibling.sh` and `start-team.sh`.** A recycle with no flag
  inherits the old session's account from its process environment (`/proc/<pid>/environ`, or
  `ps eww` on macOS). Refused with exit 64: a missing dir, no login, or unsafe characters in the
  path. An optional `ACCOUNT` file labels the dir in dry-run and launch output. Implemented once
  in `lib-launch.sh` (`launch_set_account`, `launch_account_of_pid`, `_launch_env`) for every
  backend, including the cmd.exe `set VAR=...&&` form.
- **`tests/multi-account.test.sh`** (11 checks: default, explicit, inherit, override, three
  refusals, start-team). Mutation-checked: dropping inheritance turns it red.

## 0.5.0 — 2026-09-30

The public-release pass: an easier first path, one more guard, and the tests to back it.

- **Solo mode is the starting path.** README opens with a 5-minute "two terminals, one repo"
  quickstart; GETTING-STARTED §3 "Start small: solo mode" (board + cross-verification, no seat).
  Team mode (seat + siblings) is labelled Advanced. kit-init's "Not now" answer routes to solo.
- **Git guard hook (opt-in):** `hooks/git-guard.sh`, PreToolUse on Bash. With the `.kit-hooks`
  marker and `git_guard: on` in ORCHESTRATION.md it refuses `git stash` (except list/show),
  `git add -A` / `--all` / `.` / `:/` / `-u` without paths, `git commit -a` / `--all`, and
  `git pull --rebase`, with the reason and the safe command. Shell-style tokenizer in POSIX awk
  (quotes, comments, heredocs, `$(...)`, `bash -c`), so text that merely mentions these isn't
  blocked. **On by default in team mode, off in solo mode:** kit-init sets `git_guard: on` when
  it starts a team (seat + siblings) and `off` on "Not now"; the template default is `off`.
- **`falsify` skill:** mutation-prove a test or guard can fail — commit GREEN first, prediction
  written before the run, anchored + diff-verified mutant, red observed unfiltered, byte-clean
  restore, re-green; scoring and mutant-design tables. Stack-agnostic.
- **Context-fill statusline (optional):** `scripts/statusline-ctx.sh` shows the real fill against
  the 350K / 400K marks (70% / 80% under a 500K window); green / yellow "self-report" / red
  "hand over". Copied by kit-init and bootstrap; enable via `templates/settings-snippets.md`.
- **Tests:** `bash tests/run.sh` — git guard (55 command cases under every awk found + end-to-end
  opt-in gating), statusline (bands, 200K marks, overrides), bootstrap (dry-run touches nothing,
  second run is a no-op, live files never overwritten).
- **Ported from two never-published local releases** (their 0.4.0 / 0.4.1 numbers were reused
  above for other work): `docs/EXAMPLE-SESSION.md` (an annotated 12-hour seat + 3 siblings
  session, including the seat's six mistakes); LESSONS 42–60 (enumeration as deliverable,
  per-hit verdicts, restore = clean AND fix present, wrong-reason mutants, hedges, knobs over
  etiquette, train coupling, fail-open client guards …); verifier hardening (rebuild
  enumerations, reproduce mutants, authorized exceptions, count deltas, false signals, compile
  to prove "output unchanged", mirror assertions, delta re-verify); verify-feature's
  contract-items table; orchestrate brief rules, push verification and train coupling.
- **`LICENSE`** (MIT — plugin.json already declared it). **`docs/GLOSSARY.md`**.
- Leak sweep: internal row ids removed from lesson provenance. CHANGELOG is now newest-first.

## 0.4.5 — 2026-09-29

- **Cross-platform session launcher.** `lib-launch.sh` detects the OS and terminal and picks a
  backend: `tmux` (already inside tmux — first, even on WSL or a desktop), `wsl-wt` /
  `wsl-conhost` (Windows + WSL, unchanged), `tmux-detached` over SSH, `macos-iterm` /
  `macos-terminal` (osascript), `gitbash-cmd` (Git Bash: `cmd.exe /c start`), `linux-<emulator>`
  (`$TERMINAL`, x-terminal-emulator, gnome-terminal, konsole, xfce4-terminal, kitty, alacritty,
  wezterm, foot, xterm — each with its own "run this command" syntax), `tmux-detached` when
  headless, else `manual` (prints the per-window commands, exits 2 — the old non-WSL behavior).
- Override precedence: `--terminal <backend>` flag > `terminal:` in the ORCHESTRATION.md `team:`
  block (template default `auto`) > auto-detect. `--terminal list` prints every backend and
  whether it is available here. A forced backend that is not available refuses a real launch
  (exit 64); `--dry-run` still shows its command lines.
- Every backend runs the same `cd <repo> && [nvm] && claude --name <Name> [mode] <prompt>`;
  launch-first-then-SIGTERM and the `pgrep -f "^claude --name <Name>( |$)"` fresh-process wait
  are unchanged (the pattern is valid for BSD pgrep on macOS too). Without pgrep (Git Bash)
  launches are reported unverified and `recycle-sibling.sh` never kills the old session.
- One quoting function per backend family; the WSL no-`;`/`"`/`'` rule (and the no-spaces repo
  path rule) now applies to WSL only. `--dry-run` prints the backend, why it was chosen, and the
  exact command per session.
- `kit-init`: no new question — the setup summary says "Windows will open via: <backend>";
  on `manual` it shows the commands instead of launching.
- Docs: GETTING-STARTED covers Windows (WSL), macOS, Linux and SSH/headless/tmux; README
  "What's inside"; ORCHESTRATION template `terminal:` key; orchestrate recycle row; the stale
  `v0.4.0` in bootstrap-project's commit message is now `vX` (the installed version).
- GETTING-STARTED: SendMessage / ListAgents are built into Claude Code (nothing to install) —
  update first, a one-line "list the other Claude sessions" check, and the board-only fallback.

## 0.4.4 — 2026-09-29

- **Optional worktree enforcement.** New `worktrees: advised | enforced` key in the
  ORCHESTRATION.md `team:` block (default `advised` — today's behavior: every session is
  instructed to use its own worktree, nothing blocks it).
- New PreToolUse hook `hooks/worktree-guard.sh` (Edit|Write|MultiEdit|NotebookEdit): with
  `worktrees: enforced` and the `.kit-hooks` marker, denies edits whose target resolves inside the
  MAIN checkout (first `git worktree list` entry), with a reason telling Claude to create or use its
  own worktree. Always allowed: linked worktrees, `docs/orchestration/**`, the log and status doc
  (paths from ORCHESTRATION.md → Docs), anything outside the repo. Any parse error allows; no
  `set -e`; no network; two git calls.
- `kit-init` step 7 asks a third question in the same `AskUserQuestion` ("Separate worktrees per
  session?" — Advised (Recommended) / Enforced), persists it to the `team:` block, and the
  end-of-setup summary states which one is active.
- Docs: GETTING-STARTED "Worktrees: advised vs enforced" (incl. shared-tree workflows, how to
  switch); README hook row; CLAUDE-section (marker v0.4.4) and orient Step 0 note the rule is
  instructed by default, enforced only if the repo opted in.

## 0.4.3 — 2026-09-29

- No orientation doc? The seat (or `kit-init`, or a lone session) asks ONCE how to learn the project:
  search the repo, use an outline the human provides (path or paste), or both (outline checked
  against the repo — the repo wins on facts). The doc it then writes means the question never repeats.
  Siblings never ask; they flag it to the seat.

## 0.4.2 — 2026-09-29

- `kit-init` writes a real `AI_CONTEXT.md` by surveying the repo (README, CLAUDE.md, manifests,
  directory tree, git history, one gate run) plus one question to the human, and seeds the first
  build-log entry — no template left behind.
- `orient` bootstrap mode: if the status doc is missing or still a template, orient from the
  project itself; the seat (or a lone session) writes the doc, siblings flag it in READY instead.

## 0.4.1 — 2026-09-29

- Per-repo by default: install docs now use `claude plugin install … --scope project`
  (or `--scope local`), so the kit is active only in the repos it's installed into.
- The SessionStart hook is opt-in per repo: it runs only where `docs/orchestration/.kit-hooks`
  exists (written by `kit-init`). A repo with its own board but no marker is never nudged.

## 0.4.0 — 2026-09-29

The seat + siblings upgrade: everything a single-session user needs to run one orchestrator
and 2+ builder sessions on one repo (Windows + WSL first-class).

- **`orchestrate` rewritten** (≤200 lines): seat banner + handover block, single-allocator
  table, row brief template (briefs by message, board = status), DAG with disjoint fences,
  READY-signal rosters (`ListAgents` = liveness only), hand-off verification by a SIBLING
  SESSION (no self-reads, no mutual pairs, report to the seat, DERIVED vs
  CONSISTENCY-CHECKED), a recommended never-builds validator seat, one-at-a-time reconcile
  with push-merges-immediately, wave-train deploys via ORCHESTRATION.md's vehicle, LOG slot,
  sibling lifecycle via `recycle-sibling.sh`, seat context self-check (350K/400K on 1M
  windows; 70%/80% on 200K), all human approvals routed through the seat.
- **Zero-setup team:** `start-team.sh` opens the seat (`Orca`, `/orchestration-kit:orchestrate`)
  and N siblings (`Sib1`.., `/orchestration-kit:orient`) each in its own window; skips names
  already running; names/count from flags > the overlay's optional `team:` block > defaults;
  `--dry-run`. Shares `lib-launch.sh` with `recycle-sibling.sh` so the two cannot drift.
- **Plugin-shipped SessionStart hook** (`hooks/hooks.json`, startup|clear): tells a fresh
  session to run `/orchestration-kit:orient` and send READY to an active seat; silent no-op
  (exit 0, no output) in repos without `docs/orchestration/AGENT_BOARD.md`. The v0.3.0
  settings-snippet hook is retired (remove it if you copied it).
- **Namespaced skill names everywhere** (`/orchestration-kit:<skill>`) — launch prompts, docs
  and cross-references use the form that resolves for a plugin install.
- **Institutional-memory scaffolding:** kit-init/bootstrap create `docs/AI_CONTEXT.md` and
  `docs/timeline/build-log.md` from templates if absent (paths in ORCHESTRATION.md → Docs);
  orient reads them; retro/orchestrate append to the log with Edit, never Write; lessons go to
  Claude Code's auto-memory (never generated by the kit).
- **New scripts** (kit-init + bootstrap copy them into `scripts/`, never overwriting):
  `ctx-fill.py` — real context fill from the transcript's usage block, refuses to guess the
  session, `--window` scaling; `recycle-sibling.sh` — launch-first-then-SIGTERM on
  Windows+WSL, auto-detects distro / main checkout / wt.exe, conhost fallback when Windows
  Terminal is absent, `--dry-run`, exits 2 with manual instructions elsewhere.
- **orient:** Step 0 gains fetch+rebase (not `pull --rebase`), gate-from-own-worktree,
  archive grep, approvals-via-seat; Step 7 READY signal format.
- **board:** shared-checkout write recipe (HEAD guard, `git diff HEAD --quiet`, add+commit
  as one command, immediate push), status-not-narrative, verbatim dated archives past ~60 KB.
- **reconcile / retro / kit-init / bootstrap:** HEAD guard + push merges immediately;
  "retro complete · fill" reply to the seat; scripts copied idempotently.
- **Templates:** AGENT_BOARD gains archive table, banner, roster, READY and handover shapes;
  ORCHESTRATION gains run-from, deploy-vehicle-for-trains, session names/marks, validator
  seat; CLAUDE-section v0.4.0 non-negotiables + context lifecycle.
- **docs/GETTING-STARTED.md** (new): install (2 commands) → one CMD window → `wsl` → `claude`
  → `/orchestration-kit:kit-init` → `bash scripts/start-team.sh`; "what you get" table;
  manual `--name` launches under Advanced. **LESSONS 28–41.**
- **Team launch from setup:** kit-init ends with ONE `AskUserQuestion` (start the team now —
  seat + 2 siblings / choose how many / not now; permission mode — Normal / Auto / Accept
  edits), then runs `start-team.sh` itself only on a yes (the Bash prompt is the final OK).
- **Permission modes:** `start-team.sh` and `recycle-sibling.sh` take
  `--mode normal|accept-edits|auto` → no flag / `--permission-mode acceptEdits` /
  `--permission-mode auto`. `start-team --mode` saves `permission_mode:` in the `team:` block;
  recycles reuse it (the seat's too). Dry-run prints the exact `claude` command per session.
  A permission-bypassing mode is deliberately not offered by the scripts.
- **"Change it any time — just ask Claude"** lines in kit-init's question and summary, both
  script headers, the ORCHESTRATION team block, and a GETTING-STARTED "Changing things later"
  section with example asks.
- **Memory starter scrubbed:** 6 personal-preference memories dropped (session style, UI-mockup
  habit, deploy cadence, blanket approval, branch/push policy, link formatting); the other 25
  genericized (no project names, tools, people or channels); INDEX rewritten.
- `recycle-sibling.sh` defaults the seat's prompt to `/orchestration-kit:orchestrate` when the
  name is the configured seat.
- Version note: `0.3.0` was already tagged, so this release is `0.4.0`.

## 0.3.0 — 2026-08-21

The orchestrated-autonomy port (from the origin project's pilot, 2026-08-20/21) + the
`bootstrap-project` super-init. New: orchestrate, bootstrap-project (+ scripts/bootstrap.sh,
idempotent + --dry-run), post-feature, generic team-agent templates (optional,
install-only-if-missing, user-level precedence), agnostic memory starter (31: 30 ratified + 1 canonical merge,
trust grants excluded), extras/backfill, settings-snippets template (SessionStart hook +
auto-compact off, one approval step), LESSONS 16–27. Refreshed: orient, reconcile, retro,
verify-feature, board, CLAUDE-section (v0.3.0 marker), verifier (model-pinned;
bypassPermissions demoted to an opt-in comment — trust grants never ship as defaults).

## 0.2.0 — 2026-08-08

- New skill: `retro` — the write-back half of `orient` (board close-out, lesson
  distillation with upstream-to-kit propagation, status-doc refresh, clean-handoff
  check). Without it, LESSONS.md had no trigger to accrete — the upgrade payload
  only grows if session-end prompts the write. (the maintainer's observation, night one.)

## 0.1.0 — 2026-08-08

Initial release, extracted from the origin project's multi-session workflow
(the 2026-08-08 three-session evening: ~15 workstreams, zero collisions).

- Board template + claim protocol (fences, statuses, committed edits, session tags).
- Project overlay model (`ORCHESTRATION.md`: gate, change classes, deploy, locked, hazards).
- Skills: kit-init, board, verify-feature, reconcile, orient.
- Agent: `verifier` (contract-only, read-only, four checks, structured verdict).
- LESSONS.md v1: 15 incident-backed rules, including the two added the night of
  extraction — never `git stash` in worktree agents (shared stash refs), and
  exclusive DEPLOY-row claims.
