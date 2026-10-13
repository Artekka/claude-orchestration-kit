#!/usr/bin/env bash
# Tests for the live-work refusal in scripts/recycle-sibling.sh: a session whose claude still has a live
# shell child (a background gate run, a loop) is NOT recycled without --force; MCP-style non-shell children
# never count; --dry-run lists what is live. The self-recycle path (the recycle running inside the seat's
# own tool shell) is covered by tests/recycle-inplace.test.sh, which must stay green with this check on.
# Run: bash tests/recycle-safety.test.sh   Linux only (SKIP elsewhere). Every `claude` is a stand-in process.
SUITE=recycle-safety
. "$(dirname "$0")/inplace-harness.sh"
FORBID=(FAKE_TERM_MODE=forbid)
launches_ge() { [ "$(nlaunch)" -ge "$1" ]; }
file_has() { grep -Eq -- "$2" "$1" 2>/dev/null; }

# A stand-in claude named <Name> whose child is <kind>: "shell" = a live `bash -c` (what the Bash tool leaves
# running), "plain" = a sleep (what an MCP server looks like to this check: not a shell). Records every pid.
fake_claude() {  # <name> <shell|plain>
  local body
  if [ "$2" = shell ]; then body='bash -c "sleep 120; true" & wait'; else body='sleep 120 & wait'; fi
  ( exec -a "claude --name $1 x" bash -c "$body" ) </dev/null >/dev/null 2>&1 &
  FC=$!; disown "$FC"; PIDS+=("$FC")
  wait_for "fake claude $1" pgrep -f "^claude --name ${1}( |\$)"
  wait_for "its child" pgrep -P "$FC"
  local c; for c in $(pgrep -P "$FC"); do PIDS+=("$c"); CHILD=$c; done
}
stop_fake() {  # kill the exact recorded pids of this fake and wait until its name is gone
  kill -KILL "$CHILD" "$FC" 2>/dev/null
  wait_for "fake claude gone" bash -c "! pgrep -f '^claude --name ${1}( |\$)'"
}

# S1. a live shell child: dry-run lists it; a real run refuses with exit 3 and touches nothing
sandbox; n=$(nameFor S1)
fake_claude "$n" shell
recycle "${FORBID[@]}" -- --dry-run "$n"
rematch "S1 dry run lists the live shell" "^live work +${CHILD} " "$OUT"
has "S1 dry run says a real run refuses" "refuses (exit 3) without --force" "$OUT"
recycle "${FORBID[@]}" -- "$n"
eq "S1 real run exits 3" 3 "$RC"
has "S1 says why" "still has live shells" "$ERR"
has "S1 names the pid" "pid ${CHILD} " "$ERR"
has "S1 says how to override" "--force" "$ERR"
alive "$FC" && ok || bad "S1 the old claude was killed"
alive "$CHILD" && ok || bad "S1 the live shell was killed"
eq "S1 nothing launched" 0 "$(nlaunch)"
absent "S1 the terminal was never called" "$SB/TERM-WAS-CALLED"

# S2. --force: the dry run says so, and a real run gets past the check (the forbidden terminal then stops it)
recycle "${FORBID[@]}" -- --dry-run --force "$n"
has "S2 dry run notes --force" "--force: a real run recycles anyway" "$OUT"
recycle "${FORBID[@]}" -- --force "$n"
ne "S2 --force does not refuse" 3 "$RC"
hasnt "S2 --force: no refusal text" "still has live shells" "$ERR"
stop_fake "$n"

# S3. a non-shell child (an MCP server, a sleep) is not live work
sandbox; n=$(nameFor S3)
fake_claude "$n" plain
recycle "${FORBID[@]}" -- --dry-run "$n"
rematch "S3 non-shell child: live work none" '^live work +none$' "$OUT"
stop_fake "$n"

# S4. no old process at all: live work none, no refusal
sandbox; n=$(nameFor S4)
recycle "${FORBID[@]}" -- --dry-run "$n"
rematch "S4 no old process: live work none" '^live work +none$' "$OUT"

# S5. The seat's self-recycle while its own tool shell is still alive. The seat runs the recycle from a shell
#     that is its claude's child; that shell is the recycle's ANCESTOR, so the first check skips it. The
#     detached copy is no longer below it, and in real use the tool shell can outlive the call by a moment
#     (here: `; sleep 3`), so the copy must not check again (the parent already did) or the seat would
#     refuse to recycle itself on its own tool call.
sandbox; n=$(nameFor S5)
printf self-recycle > "$SB/stub/mode.1"; printf term-trap > "$SB/stub/mode.2"
# The harness redirects the LAST command of SELF_RECYCLE_CMD (here the sleep), so the recycle writes its own files.
start_wrapper "$n" "SELF_RECYCLE_CMD=bash $RECYCLE --repo $SB/repo --terminal linux-xterm $n go --model haiku > $SB/stub/s5.out 2> $SB/stub/s5.err; sleep 3" \
  FAKE_TERM_MODE=forbid RECYCLE_DETACH_DELAY=1
OLD="$(launch_pid 1)"
wait_for "the seat's recycle call to print its log" file_has "$SB/stub/s5.out" 'log:'
logp="$(sed -n 's/.*log: //p' "$SB/stub/s5.out" | head -1)"
hasnt "S5 the seat's own call did not refuse" "still has live shells" "$(cat "$SB/stub/s5.err" 2>/dev/null)"
wait_for "the fresh claude" launches_ge 2
wait_for "old claude gone" not_alive "$OLD"
eq "S5 the old seat was SIGTERMed" "TERM" "$(cat "$SB/stub/sigterm.$OLD" 2>/dev/null)"
hasnt "S5 the detached copy did not refuse" "still has live shells" "$(cat "$logp" 2>/dev/null)"

finish
