#!/usr/bin/env bash
# Tests for scripts/recycle-sibling.sh in-place mode and the wrapper-aware tab commands (v0.7.0).
# Run: bash tests/recycle-inplace.test.sh   Linux only (SKIP elsewhere). Nothing real is launched: every
# `claude` is a stub on PATH and the terminal is a stand-in `xterm` (tests/inplace-harness.sh).
SUITE=recycle-inplace
. "$(dirname "$0")/inplace-harness.sh"
FORBID=(FAKE_TERM_MODE=forbid)          # a terminal that must never run: it leaves a marker if called
ORIENT="/orchestration-kit:orient"

# R1. --dry-run / DRY_RUN=1 name the mode they WOULD use: in-place only for a lone claude whose parent is
#     the wrapper; --new-tab forces the old behaviour; a dry run changes nothing.
sandbox; n=$(nameFor R1)
dry() { recycle "${FORBID[@]}" -- --dry-run "$@" "$n"; }
dry;                         rematch "R1 no old process" '^mode: new-tab$' "$OUT"
recycle "${FORBID[@]}" DRY_RUN=1 -- "$n"; rematch "R1 DRY_RUN=1 works like --dry-run" '^mode: new-tab$' "$OUT"
# an old claude that is NOT under a wrapper (a bare `claude`, parent = this test)
( exec -a "claude --name $n x" sleep 120 ) </dev/null >/dev/null 2>&1 &
LOOSE=$!; disown "$LOOSE"; PIDS+=("$LOOSE")
wait_for "loose claude" pgrep -f "^claude --name ${n}( |\$)"
dry;                         rematch "R1 old claude started by hand" '^mode: new-tab$' "$OUT"
kill -KILL "$LOOSE" 2>/dev/null
wait_for "loose claude gone" bash -c "! pgrep -f '^claude --name ${n}( |\$)'"
# an old claude under a real wrapper
start_wrapper "$n" STUB_MODE=term-trap; W1PID=$WPID
dry;                         rematch "R1 lone claude under the wrapper" '^mode: in-place$' "$OUT"
rematch "R1 names the old pid" '^old pids +[0-9]+' "$OUT"
dry --new-tab;               rematch "R1 --new-tab forces new-tab" '^mode: new-tab$' "$OUT"
eq "R1 a dry run launched nothing" 1 "$(nlaunch)"
alive "$W1PID" && ok || bad "R1 wrapper still alive"
absent "R1 the terminal was never called" "$SB/TERM-WAS-CALLED"
absent "R1 no hand-off written" "$SB/state/$n.next"

# R2. In place, end to end: same wrapper pid, new child pid, the old child got SIGTERM, the wrapper did NOT.
sandbox; n=$(nameFor R2)
start_wrapper "$n" STUB_MODE=term-trap; W2PID=$WPID; OLD="$(launch_pid 1)"
eq "R2 the stub's parent is the wrapper" "$W2PID" "$(launch_ppid 1)"
WCMD="$(cmdline "$W2PID")"
recycle "${FORBID[@]}" STUB_MODE=term-trap -- "$n" "$ORIENT --brief ROW-1" --model 'sonnet[1m]' --effort high --mode accept-edits
eq "R2 exit 0" 0 "$RC"; has "R2 summary says in-place" "mode: in-place" "$OUT"
absent "R2 no new tab in the in-place path" "$SB/TERM-WAS-CALLED"
eq "R2 exactly one relaunch" 2 "$(nlaunch)"
eq "R2 the fresh claude is a child of the SAME wrapper" "$W2PID" "$(launch_ppid 2)"
ne "R2 a new pid" "$OLD" "$(launch_pid 2)"
eq "R2 argv (model, effort, permission mode, prompt)" "--name|$n|--permission-mode|acceptEdits|--model|sonnet[1m]|--effort|high|$ORIENT --brief ROW-1|" "$(argv_of 2)"
wait_for "old claude's SIGTERM record" test -f "$SB/stub/sigterm.$OLD"
eq "R2 the old child received SIGTERM" "TERM" "$(cat "$SB/stub/sigterm.$OLD")"
wait_for "old claude gone" not_alive "$OLD"
alive "$W2PID" && ok || bad "R2 wrapper still alive (never signalled)"
eq "R2 wrapper is the same program" "$WCMD" "$(cmdline "$W2PID")"
alive "$(launch_pid 2)" && ok || bad "R2 fresh claude alive"
eq "R2 hand-off consumed, no tmp/revoked leftovers" "" "$(ls -A "$SB/state")"

# R3. Timeout fallback: no fresh child under the wrapper -> hand-off removed, new-tab path used, and said so.
sandbox; n=$(nameFor R3)
start_wrapper "$n" STUB_MODE=ignore-term; W3PID=$WPID; OLD="$(launch_pid 1)"
recycle RECYCLE_INPLACE_TIMEOUT=2 STUB_MODE=ignore-term -- "$n" go --model haiku
eq "R3 exit 0" 0 "$RC"; rematch "R3 says it fell back" 'falling back to a new tab' "$ERR"
has "R3 summary says new-tab" "mode: new-tab" "$OUT"
absent "R3 an unconsumed hand-off would make the wrapper launch a duplicate later" "$SB/state/$n.next"
alive "$OLD" && ok || bad "R3 the stubborn old claude was only asked to stop"
alive "$W3PID" && ok || bad "R3 wrapper alive"
eq "R3 the wrapper never relaunched (one stub launch under it, one under the tab's own wrapper)" 2 "$(nlaunch)"
has "R3 the new tab runs the WRAPPER" "sibling-shell.sh" "$(cat "$SB/fake-term.args")"

# R3b. A same-name claude that is NOT a child of the wrapper does not count as the in-place relaunch.
sandbox; n=$(nameFor R3b)
start_wrapper "$n" STUB_MODE=term-decoy
recycle RECYCLE_INPLACE_TIMEOUT=2 STUB_MODE=term-decoy -- "$n" go --model haiku
exists "R3b the decoy must have been spawned" "$SB/stub/decoy.pids"
eq "R3b exit 0" 0 "$RC"; rematch "R3b fell back to a new tab" 'falling back to a new tab' "$ERR"; has "R3b mode new-tab" "mode: new-tab" "$OUT"

# R5. A wrapper for a DIFFERENT Name is never taken for ours (positive control: same shape, same Name).
sandbox; mine=$(nameFor R5a); other=$(nameFor R5b); control=$(nameFor R5c)
start_wrapper "$other" STUB_MODE=term-trap; OTHERW=$WPID; OTHERC="$(launch_pid 1)"
stand_in_wrapper "$other" "$mine" ""; IMPC=$SCPID
stand_in_wrapper "$control" "$control" ""
recycle "${FORBID[@]}" -- --dry-run "$control"; rematch "R5 same shape + matching Name = in-place" '^mode: in-place$' "$OUT"
recycle "${FORBID[@]}" -- --dry-run "$mine";    rematch "R5 same shape + other Name = new-tab" '^mode: new-tab$' "$OUT"
recycle STUB_MODE=term-trap -- "$mine" go --model haiku
eq "R5 exit 0" 0 "$RC"; has "R5 took the new-tab path" "mode: new-tab" "$OUT"
absent "R5 no hand-off for the other sibling" "$SB/state/$other.next"; absent "R5 no hand-off for ours" "$SB/state/$mine.next"
alive "$OTHERW" && ok || bad "R5 other wrapper alive"; alive "$OTHERC" && ok || bad "R5 other claude alive"
absent "R5 other claude never signalled" "$SB/stub/sigterm.$OTHERC"

# R6a. Race: the wrapper already claimed the hand-off but its child is slow to appear -> keep waiting, no
#      second tab (an `rm -f` fallback opened one anyway and left TWO sessions under one name).
sandbox; n=$(nameFor R6a)
start_wrapper "$n" STUB_MODE=term-trap STUB_SLOW=2
recycle "${FORBID[@]}" RECYCLE_INPLACE_TIMEOUT=1 RECYCLE_CLAIMED_GRACE=20 -- "$n" go --model haiku
absent "R6a no tab: that would be a duplicate" "$SB/TERM-WAS-CALLED"
eq "R6a exit 0" 0 "$RC"; has "R6a in-place" "mode: in-place" "$OUT"
renomatch "R6a did not claim to remove a consumed hand-off" 'removed the (unclaimed )?hand-off' "$ERR"
eq "R6a two launches" 2 "$(nlaunch)"; last_arg_is 2 go && ok || bad "R6a prompt reached the relaunch"
# R6b. ... and a claimed hand-off whose child never appears stops WITHOUT opening a tab, and says so.
sandbox; n=$(nameFor R6b)
start_wrapper "$n" STUB_MODE=term-trap STUB_SLOW=2 STUB_SLOW_SECS=8
recycle "${FORBID[@]}" RECYCLE_INPLACE_TIMEOUT=1 RECYCLE_CLAIMED_GRACE=2 -- "$n" go --model haiku
eq "R6b exit 1" 1 "$RC"; rematch "R6b says it did not open a tab" 'NOT opening a tab' "$ERR"; rematch "R6b says claimed" 'claimed' "$ERR"
absent "R6b the terminal was never called" "$SB/TERM-WAS-CALLED"; absent "R6b hand-off consumed" "$SB/state/$n.next"

# R7. The hand-off carries the account: inherit the old claude's, then --account 2, then --account 1.
sandbox; n=$(nameFor R7)
for a in 2 3; do mkdir -p "$SB/home/.claude-acct$a"; echo '{}' > "$SB/home/.claude-acct$a/.credentials.json"; done
start_wrapper "$n" STUB_MODE=term-trap CLAUDE_CONFIG_DIR="$SB/home/.claude-acct3"
go() { recycle "${FORBID[@]}" -- "$n" go --model haiku "$@"; eq "R7 exit 0 [$*]" 0 "$RC"; has "R7 in-place [$*]" "mode: in-place" "$OUT"; }
go; go --account 2; go --account 1
A2="$SB/home/.claude-acct$((1+1))"; A3="$SB/home/.claude-acct$((1+2))"
eq "R7 account per launch: inherited, inherited, account 2, default" "$A3,$A3,$A2,unset" "$(cfgs)"
absent "R7 the terminal was never called" "$SB/TERM-WAS-CALLED"

# R8. Seat safety: a target claude that is an ANCESTOR of the running recycle never takes the in-place
#     path. Same process shape run from outside is in-place (the control), so the ancestry walk is the only
#     difference. R8d adds a shell layer: the walk is deeper than the direct parent.
sandbox; n=$(nameFor R8); control=$(nameFor R8c)
RUNIN="bash $RECYCLE --repo $SB/repo --terminal linux-xterm --dry-run"
stand_in_wrapper "$n" "$n" "$RUNIN $n > $SB/inside.out 2> $SB/inside.err
sleep 120" "${FORBID[@]}"
wait_for "recycle output from inside the old claude" grep -q '^mode:' "$SB/inside.out"
rematch "R8 from inside: new-tab" '^mode: new-tab$' "$(cat "$SB/inside.out")"
rematch "R8 says why" 'ancestor' "$(cat "$SB/inside.err")"
stand_in_wrapper "$control" "$control" ""
recycle "${FORBID[@]}" -- --dry-run "$control"
rematch "R8 control from outside: in-place" '^mode: in-place$' "$OUT"; renomatch "R8 control: no ancestor note" 'ancestor' "$ERR"
sandbox; n=$(nameFor R8d)
stand_in_wrapper "$n" "$n" "bash -c \"$RUNIN $n > $SB/d2.out 2> $SB/d2.err; true\"
sleep 120" "${FORBID[@]}"
wait_for "recycle output from two shells below the old claude" grep -q '^mode:' "$SB/d2.out"
rematch "R8d depth 2: new-tab" '^mode: new-tab$' "$(cat "$SB/d2.out")"; rematch "R8d says why" 'ancestor' "$(cat "$SB/d2.err")"

# R4. No old process: the new tab runs the WRAPPER with an explicit model, so every session moves over at
#     its next recycle. (Runs the real command through the stand-in terminal.)
sandbox; n=$(nameFor R4)
recycle STUB_MODE=term-trap -- "$n" "$ORIENT --brief X" --model 'sonnet[1m]' --effort low
eq "R4 exit 0" 0 "$RC"; has "R4 new-tab" "mode: new-tab" "$OUT"
tab="$(grep sibling-shell.sh "$SB/fake-term.args")"
has "R4 the tab command runs the wrapper with the explicit model" "$n --model sonnet\\[1m\\] --effort low" "$tab"
eq "R4 the wrapper started claude with that argv" "--name|$n|--model|sonnet[1m]|--effort|low|$ORIENT --brief X|" "$(argv_of 1)"
eq "R4 ...as a child of a sibling-shell.sh process" "sibling-shell.sh" "$(basename "$(cmdline "$(launch_ppid 1)" | awk '{print $2}')")"

# R9. Every tab command runs the wrapper, on every backend that can run it; bare claude elsewhere.
sandbox; n=$(nameFor R9)
cmds() { recycle -- --dry-run --terminal "$1" "$n" go --model haiku --mode auto; }
tabline() { printf '%s\n' "$OUT" | grep -E '^[[:space:]]*(command|by hand) '; }   # the command, not the pgrep note beside it
for b in tmux tmux-detached linux-xterm linux-kitty macos-terminal macos-iterm wsl-wt wsl-conhost; do
  run_in_sb -- bash "$RECYCLE" --repo "$SB/repo" --dry-run --terminal "$b" "$n" go --model haiku --mode auto
  has "R9 $b runs the wrapper" "sibling-shell.sh $n --mode auto --model haiku go" "$(tabline)"
  hasnt "R9 $b has no bare claude --name" "claude --name" "$(tabline)"
done
for b in manual gitbash-cmd; do
  run_in_sb -- bash "$RECYCLE" --repo "$SB/repo" --dry-run --terminal "$b" "$n" go --model haiku --mode auto
  has "R9 $b keeps a bare claude" "claude --name $n --permission-mode auto --model haiku go" "$(tabline)"
  hasnt "R9 $b does not use the wrapper" "sibling-shell.sh" "$(tabline)"
done
run_in_sb LAUNCH_NO_WRAPPER=1 -- bash "$RECYCLE" --repo "$SB/repo" --dry-run --terminal tmux "$n" go --model haiku
has "R9 LAUNCH_NO_WRAPPER=1 keeps a bare claude" "claude --name $n --model haiku go" "$(tabline)"; hasnt "R9 ...and no wrapper" "sibling-shell.sh" "$(tabline)"
# the tab command carries no bare `;` and no quote on WSL (wt.exe splits on `;`, quotes cross Windows argv)
run_in_sb -- bash "$RECYCLE" --repo "$SB/repo" --dry-run --terminal wsl-wt "$n" go --model 'sonnet[1m]'
line="$(tabline)"
renomatch "R9 wsl command has no bare ;" '(^|[^\\]);' "$line"; hasnt "R9 wsl command has no double quote" '"' "$line"
# a wrapper path with a space cannot cross the WSL command line: bare claude, and the user is told
mkdir -p "$SB/with space"; cp -R "$ROOT/scripts" "$SB/with space/scripts"
run_in_sb -- bash "$SB/with space/scripts/recycle-sibling.sh" --repo "$SB/repo" --dry-run --terminal wsl-wt "$n" go --model haiku
has "R9 spaced wrapper path on WSL: bare claude" "claude --name $n --model haiku go" "$(tabline)"; hasnt "R9 ...no wrapper" "sibling-shell.sh" "$(tabline)"
run_in_sb -- bash "$SB/with space/scripts/recycle-sibling.sh" --repo "$SB/repo" --dry-run --terminal tmux "$n" go --model haiku
has "R9 spaced wrapper path elsewhere is fine (quoted)" "sibling-shell.sh $n --model haiku go" "$(tabline)"
# start-team opens its tabs under the wrapper too
run_in_sb -- bash "$ROOT/scripts/start-team.sh" --repo "$SB/repo" --dry-run --terminal tmux --seat ZzSeat --prefix ZzSib --siblings 1
has "R9 start-team: tab command runs the wrapper" "sibling-shell.sh ZzSeat" "$(tabline)"

# R10. The ps fallback (macOS, BSD: no /proc) decides exactly as the /proc path does.
sandbox; mine=$(nameFor RAa); other=$(nameFor RAb); control=$(nameFor RAc); loose=$(nameFor RAd)
stand_in_wrapper "$other" "$mine" ""
stand_in_wrapper "$control" "$control" ""
( exec -a "claude --name $loose x" sleep 120 ) </dev/null >/dev/null 2>&1 &
LP=$!; disown "$LP"; PIDS+=("$LP"); wait_for "loose claude" pgrep -f "^claude --name ${loose}( |\$)"
for NOPROC in "" 1; do
  tag="${NOPROC:+ps}"; tag="${tag:-/proc}"
  recycle LAUNCH_NO_PROC=$NOPROC -- --dry-run "$control"; rematch "R10 [$tag] matching Name: in-place" '^mode: in-place$' "$OUT"
  recycle LAUNCH_NO_PROC=$NOPROC -- --dry-run "$mine";    rematch "R10 [$tag] other wrapper's Name: new-tab" '^mode: new-tab$' "$OUT"
  recycle LAUNCH_NO_PROC=$NOPROC -- --dry-run "$loose";   rematch "R10 [$tag] started by hand: new-tab" '^mode: new-tab$' "$OUT"
done
kill -KILL "$LP" 2>/dev/null
# the ancestor guard on the ps path
sandbox; n=$(nameFor RAe)
stand_in_wrapper "$n" "$n" "bash $RECYCLE --repo $SB/repo --terminal linux-xterm --dry-run $n > $SB/inside.out 2> $SB/inside.err
sleep 120" "${FORBID[@]}" LAUNCH_NO_PROC=1
wait_for "recycle output from inside (ps path)" grep -q '^mode:' "$SB/inside.out"
rematch "R10 [ps] ancestor guard: new-tab" '^mode: new-tab$' "$(cat "$SB/inside.out")"

finish
