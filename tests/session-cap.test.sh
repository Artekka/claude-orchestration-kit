#!/usr/bin/env bash
# Tests for the session cap (team block `max_sessions:`): the parser, the warning, and both launchers
# warning before they pass it (never refusing). The count is every `claude` process on the host, so the
# cases use caps far below or far above whatever this machine runs.
# Run: bash tests/session-cap.test.sh   Linux only (SKIP elsewhere). Every `claude` is a stand-in process.
SUITE=session-cap
. "$(dirname "$0")/inplace-harness.sh"
START="$ROOT/scripts/start-team.sh"
conf() { mkdir -p "$SB/repo/docs/orchestration"; printf 'team:\n  seat:             CapSeat\n  siblings:         1\n%s\n' "$1" > "$SB/repo/docs/orchestration/ORCHESTRATION.md"; }
capfn() {  # <adding> → stderr of launch_cap_warn after parsing the sandbox repo's team block
  bash -c '. "$1"; launch_team_conf "$2"; launch_cap_warn "$3"' _ "$ROOT/scripts/lib-launch.sh" "$SB/repo" "$1" 2>&1
}

sandbox
conf ""; eq "no max_sessions: no warning" "" "$(capfn 5)"
conf "  max_sessions:     abc"; eq "invalid max_sessions: ignored" "" "$(capfn 5)"
conf "  max_sessions:     0"; eq "max_sessions 0: ignored" "" "$(capfn 5)"
conf "  max_sessions:     100000"; eq "far above the host count: no warning" "" "$(capfn 2)"
conf "  max_sessions:     1"; out="$(capfn 1)"
has "cap 1: warns" "passes max_sessions (1)" "$out"
has "cap 1: says what to do" "Retire one first" "$out"

# start-team dry run: warns, still plans the launches (a warning, never a refusal)
run_in_sb FAKE_TERM_MODE=forbid -- bash "$START" --repo "$SB/repo" --terminal linux-xterm --dry-run
eq "start-team over the cap: exit 0" 0 "$RC"
has "start-team over the cap: warns" "passes max_sessions (1)" "$ERR"
has "start-team over the cap: still plans the seat" "LAUNCH CapSeat" "$OUT"
conf "  max_sessions:     100000"
run_in_sb FAKE_TERM_MODE=forbid -- bash "$START" --repo "$SB/repo" --terminal linux-xterm --dry-run
hasnt "start-team under the cap: no warning" "max_sessions" "$ERR"

# recycle: a name with no old process adds one (warns); a name with an old process replaces it (no warning)
conf "  max_sessions:     1"; n=$(nameFor CAP)
recycle FAKE_TERM_MODE=forbid -- --dry-run "$n"
has "recycle of a new name over the cap: warns" "passes max_sessions (1)" "$ERR"
( exec -a "claude --name $n x" sleep 120 ) </dev/null >/dev/null 2>&1 &
LOOSE=$!; disown "$LOOSE"; PIDS+=("$LOOSE")
wait_for "loose claude" pgrep -f "^claude --name ${n}( |\$)"
recycle FAKE_TERM_MODE=forbid -- --dry-run "$n"
hasnt "recycle that replaces a session: no warning" "max_sessions" "$ERR"
kill -KILL "$LOOSE" 2>/dev/null

finish
