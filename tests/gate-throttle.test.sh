#!/usr/bin/env bash
# Tests for scripts/gate-throttle.sh and scripts/quiet-mode.sh: exit code, slot limit, first-come order,
# dead tickets, quiet mode, the priority slot, load admission, stale locks, gate_slots from the team block,
# and the no-flock fallback. Every run uses a private runtime dir and a fast poll.
# Run: bash tests/gate-throttle.test.sh   (needs bash, git, flock, timeout; skips without flock)
# Every direct call carries a timeout, so a regression that blocks shows as a FAIL, not a hung suite.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; GT="$ROOT/scripts/gate-throttle.sh"; QM="$ROOT/scripts/quiet-mode.sh"
command -v flock >/dev/null 2>&1 || { echo "gate-throttle: skipped (no flock)"; exit 0; }
command -v timeout >/dev/null 2>&1 || { echo "gate-throttle: skipped (no timeout)"; exit 0; }
TMP="$(mktemp -d)"
PIDS=()
cleanup() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT
export KIT_RUNTIME_DIR="$TMP/rt" GATE_POLL=0.1 GATE_MAX_LOAD=1000000 LOG="$TMP/log"
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL $*"; }
has()   { case "$3" in *"$2"*) ok ;; *) bad "$1: want '$2' in: $3" ;; esac; }

# A payload that logs "start X", holds until $TMP/release-X exists, then logs "end X".
HOLD="$TMP/hold.sh"
cat > "$HOLD" <<'EOF'
#!/usr/bin/env bash
echo "start $1" >> "$LOG"
while [ ! -e "$(dirname "$LOG")/release-$1" ] && [ -d "$(dirname "$LOG")" ]; do sleep 0.05; done   # never outlive the sandbox
echo "end $1" >> "$LOG"
EOF
release() { : > "$TMP/release-$1"; }
waitfor() {  # <text> [seconds] — wait until the log has the line
  local i=0 n=$(( ${2:-10} * 20 ))
  while ! grep -qx "$1" "$LOG" 2>/dev/null; do i=$((i+1)); [ "$i" -gt "$n" ] && return 1; sleep 0.05; done
}
bg() {  # <name> [dir] — start a throttled HOLD in the background (from dir, default $TMP)
  (cd "${2:-$TMP}" && exec bash "$GT" bash "$HOLD" "$1" 2>>"$TMP/err") & PIDS+=($!)
}
order() { grep '^start' "$LOG" | cut -d' ' -f2 | tr '\n' ' '; }
reset() { for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; PIDS=(); rm -rf "$TMP/rt" "$LOG" "$TMP"/release-* "$TMP/err"; }

# 1. exit code passes through; usage error is 64
GATE_SLOTS=1 timeout 20 bash "$GT" bash -c 'exit 7' 2>/dev/null; [ $? -eq 7 ] && ok || bad "exit code of the command is not passed through"
timeout 20 bash "$GT" 2>/dev/null; [ $? -eq 64 ] && ok || bad "no command: want exit 64"

# 2. one slot: B waits for A; 3. first come, first served: B (queued first) runs before C
reset; export GATE_SLOTS=1
bg A; waitfor "start A" || bad "A never started"
bg B; sleep 0.4; bg C; sleep 0.4
has "one slot: only A runs while A holds it" "A " "$(order)"
[ "$(order)" = "A " ] && ok || bad "one slot: something started beside A: $(order)"
release A; waitfor "start B" || bad "B never started after A released"
sleep 0.4; [ "$(order)" = "A B " ] && ok || bad "first come: want 'A B ' while B holds, got '$(order)'"
release B; waitfor "start C" || bad "C never started"; release C; waitfor "end C"
[ "$(order)" = "A B C " ] && ok || bad "first come: want A B C, got $(order)"

# 4. a dead waiter's ticket is skipped (and deleted)
reset
bg A; waitfor "start A"
mkdir -p "$KIT_RUNTIME_DIR/queue"; : > "$KIT_RUNTIME_DIR/queue/0000000000.999999"   # ticket 0 of a dead pid
bg B; sleep 0.3; release A; waitfor "start B" 5 && ok || bad "a dead ticket ahead blocked the line"
[ ! -e "$KIT_RUNTIME_DIR/queue/0000000000.999999" ] && ok || bad "the dead ticket was not deleted"
release B; waitfor "end B"

# 5. quiet mode: no new start while on; starts after off; GATE_IGNORE_QUIET=1 bypasses
reset
out="$(bash "$QM" on)"; has "quiet-mode on: says ON" "quiet mode: ON" "$out"
bg A; sleep 0.6; ! grep -q "start A" "$LOG" 2>/dev/null && ok || bad "quiet mode: A started while quiet mode was on"
has "quiet mode: the waiter says why" "QUIET MODE is on" "$(cat "$TMP/err")"
out="$(bash "$QM" status)"; has "quiet-mode status lists the waiter" "#1 pid" "$out"
GATE_IGNORE_QUIET=1 timeout 20 bash "$GT" bash -c 'echo bypass >> "$LOG"' 2>/dev/null
grep -qx bypass "$LOG" && ok || bad "GATE_IGNORE_QUIET=1 did not bypass quiet mode"
bash "$QM" off >/dev/null; waitfor "start A" 5 && ok || bad "A did not start after quiet mode turned off"
out="$(bash "$QM" status)"; has "quiet-mode status shows the running command" "hold.sh A" "$out"
release A; waitfor "end A"

# 6. the priority slot: a prio-listed dir runs while the normal slot is held and others queue
reset
mkdir -p "$TMP/train" "$KIT_RUNTIME_DIR"; printf '%s\n' "$(cd "$TMP/train" && pwd -P)" > "$KIT_RUNTIME_DIR/gate-priority.txt"
bg A; waitfor "start A"; bg B; sleep 0.3
bg P "$TMP/train"; waitfor "start P" 5 && ok || bad "priority: the train dir did not get the priority slot"
! grep -q "start B" "$LOG" && ok || bad "priority: B jumped the queue"
release A; release B; release P; waitfor "end B"; waitfor "end P"

# 7. load admission: the head waits while load is high; the priority slot ignores load
reset
echo "99.00 1 1 1/1 1" > "$TMP/loadavg"
KIT_LOADAVG_FILE="$TMP/loadavg" GATE_MAX_LOAD=4 bg A; sleep 0.6
! grep -q "start A" "$LOG" 2>/dev/null && ok || bad "load: A started at load 99 >= 4"
has "load: the waiter says why" "holding: load 99.00" "$(cat "$TMP/err")"
mkdir -p "$TMP/train"; printf '%s\n' "$(cd "$TMP/train" && pwd -P)" > "$KIT_RUNTIME_DIR/gate-priority.txt"
KIT_LOADAVG_FILE="$TMP/loadavg" GATE_MAX_LOAD=4 bg P "$TMP/train"; waitfor "start P" 5 && ok || bad "load: the priority slot waited on load"
echo "1.00 1 1 1/1 1" > "$TMP/loadavg"; waitfor "start A" 5 && ok || bad "load: A did not start once load dropped"
release A; release P; waitfor "end A"; waitfor "end P"

# 8. a lock FILE left by a dead holder (e.g. after a reboot) is not a held lock
reset; mkdir -p "$KIT_RUNTIME_DIR/locks"; : > "$KIT_RUNTIME_DIR/locks/gate-slot-1.lock"
timeout 20 bash "$GT" bash -c 'echo stale-ok >> "$LOG"' 2>/dev/null; grep -qx stale-ok "$LOG" && ok || bad "a leftover lock file blocked the slot"

# 9. gate_slots from the team block (read from the main checkout, also from a worktree); GATE_SLOTS overrides
reset; unset GATE_SLOTS
R="$TMP/repo"; git init -q -b main "$R"; mkdir -p "$R/docs/orchestration"
printf 'team:\n  seat: Orca\n  gate_slots:       2\n' > "$R/docs/orchestration/ORCHESTRATION.md"
git -C "$R" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
git -C "$R" worktree add -q "$TMP/wt" -b wt 2>/dev/null
bg A "$TMP/wt"; bg B "$TMP/wt"; waitfor "start A" && waitfor "start B" && ok || bad "gate_slots: 2 did not give two slots"
bg C "$TMP/wt"; sleep 0.5; ! grep -q "start C" "$LOG" && ok || bad "gate_slots: 2 ran a third"
release A; waitfor "start C" 5 && ok || bad "gate_slots: C did not take the freed slot"
release B; release C; waitfor "end C"
reset; (cd "$R" && GATE_SLOTS=1 timeout 20 bash "$GT" bash -c 'echo env-ok >> "$LOG"' 2>/dev/null); grep -qx env-ok "$LOG" && ok || bad "GATE_SLOTS env did not run"

# 10. no flock: warns and runs unthrottled
out="$(KIT_FLOCK_BIN=/nonexistent/flock timeout 20 bash "$GT" bash -c 'echo ran' 2>&1)"
has "no flock: still runs the command" "ran" "$out"; has "no flock: says it is unthrottled" "UNTHROTTLED" "$out"

echo "gate-throttle: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
