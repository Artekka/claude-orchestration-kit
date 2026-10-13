#!/usr/bin/env bash
# Tests for the live-work refusal in scripts/recycle-sibling.sh: a session whose claude still has a live
# shell child (a background gate run, a loop) is NOT recycled without --force; MCP-style non-shell children
# never count; --dry-run lists what is live. The self-recycle path (the recycle running inside the seat's
# own tool shell) is covered by tests/recycle-inplace.test.sh, which must stay green with this check on.
# Run: bash tests/recycle-safety.test.sh   Linux only (SKIP elsewhere). Every `claude` is a stand-in process.
SUITE=recycle-safety
. "$(dirname "$0")/inplace-harness.sh"
FORBID=(FAKE_TERM_MODE=forbid)

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

finish
