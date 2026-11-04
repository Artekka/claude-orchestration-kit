#!/usr/bin/env bash
# gate-throttle.sh (orchestration-kit): run a heavy command (your gate, a whole test suite) only when one of
# N host-wide slots is free, so several sessions on one machine do not run N full gates at once and flake
# on load. Usage, from inside YOUR worktree:
#   bash scripts/gate-throttle.sh <command> [args...]        e.g. bash scripts/gate-throttle.sh npm test
#   bash scripts/gate-throttle.sh --log <file> <command> [args...]
# Exit code = the command's exit code.
# --log:     once the slot is held, the command's output (stdout and stderr) goes to <file>, which opens
#            with "SHA <full commit>" and "started <HH:MM:SS> dirty=<changed paths>" read at that moment
#            (not while waiting: a commit made in the queue would make the log name the wrong code) and
#            ends with "exit <code>". The slot line stays on stderr.
#
# Slots:     `gate_slots:` in the team block of docs/orchestration/ORCHESTRATION.md (default 2);
#            GATE_SLOTS overrides it.
# Priority:  one extra slot for release/train gates. A command may take it only if its working directory
#            starts with a line of "$RT/gate-priority.txt" (one path prefix per line; the seat owns it).
#            The priority slot ignores the queue and the load check.
# Fair order: each waiter takes a numbered ticket; only the oldest LIVE waiter may try for a normal slot
#            (polling alone is not first-come-first-served: a gate once waited 1.5 h while later arrivals
#            took freed slots). A dead waiter's ticket is skipped and deleted.
# Load:      the head of the line takes a normal slot only while the 1-minute load average is below
#            GATE_MAX_LOAD (default 0.9 x CPU count). Unreadable load = admit.
# Memory:    a normal slot beyond the first is admitted only while the system's available memory
#            (MemAvailable in /proc/meminfo, the "available" column of `free -m`) is at least
#            GATE_MIN_FREE_MB (default 3072). Below that, one normal slot at a time. Unreadable = admit.
#            KIT_MEMINFO_FILE points at a stand-in for /proc/meminfo (tests).
# Quiet mode: while "$RT/quiet-mode" exists (scripts/quiet-mode.sh on), no NEW command starts; running
#            ones finish. GATE_IGNORE_QUIET=1 is the seat's escape for a hotfix gate; while quiet
#            mode is on it also skips the line, because the waiters ahead of it are parked.
# Runtime dir: $KIT_RUNTIME_DIR, default ~/.orchestration-kit/runtime. Not /tmp: a reboot wipes /tmp.
#            A lock file that survives a reboot is harmless, because flock locks are held by the kernel,
#            not by the file: the holder died with the machine, so the next command simply takes it.
# Needs flock(1) (util-linux; macOS: `brew install flock`). Without it, it warns and runs unthrottled.
set -u
log=""
if [ "${1:-}" = --log ]; then
  [ $# -ge 3 ] && [ -n "$2" ] || { echo "usage: gate-throttle.sh [--log <file>] <command> [args...]" >&2; exit 64; }
  log="$2"; shift 2
  : > "$log" || { echo "gate-throttle: cannot write the log $log" >&2; exit 73; }
fi
[ $# -ge 1 ] || { echo "usage: gate-throttle.sh [--log <file>] <command> [args...]" >&2; exit 64; }
# The command, logged when --log was given: commit and dirty count first, read now, exit code last.
run() {
  [ -z "$log" ] && { "$@"; return $?; }
  local rc
  {
    echo "SHA $(git rev-parse HEAD 2>/dev/null || echo none)"
    echo "started $(date +%H:%M:%S) dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    "$@"; rc=$?
    echo "exit $rc"
    return $rc
  } > "$log" 2>&1
}
RT="${KIT_RUNTIME_DIR:-$HOME/.orchestration-kit/runtime}"
FLOCK="${KIT_FLOCK_BIN:-flock}"
if ! command -v "$FLOCK" >/dev/null 2>&1; then
  echo "gate-throttle: flock not found (Linux: util-linux; macOS: brew install flock); running UNTHROTTLED" >&2
  run "$@"; exit $?
fi
locks_dir="$RT/locks"; qdir="$RT/queue"; rdir="$RT/running"
mkdir -p "$locks_dir" "$qdir" "$rdir" || exit 1

# Slots: env > team block > 2. The overlay is read from the MAIN checkout, so a worktree gets the same value.
slots="${GATE_SLOTS:-}"
if [ -z "$slots" ]; then
  main="$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')"
  conf="${main:-.}/docs/orchestration/ORCHESTRATION.md"
  slots="$(sed -n 's/^[[:space:]]*gate_slots:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$conf" 2>/dev/null | head -n1)"
fi
case "$slots" in ''|*[!0-9]*|0) slots=2 ;; esac
poll="${GATE_POLL:-5}"

prio=0
if [ -f "$RT/gate-priority.txt" ]; then
  here="$(pwd -P)"
  while IFS= read -r p; do
    [ -n "$p" ] && case "$here" in "$p"*) prio=1 ;; esac
  done < "$RT/gate-priority.txt"
fi

alive() { kill -0 "$1" 2>/dev/null; }
# A process's start time ("Mon Oct 13 08:43:03 2026"): with the pid it names ONE process. A ticket whose
# pid now belongs to a different process (pid reuse, often after a reboot, since tickets survive one)
# has a different start time and counts as dead, instead of blocking the line forever.
proc_start() { ps -o lstart= -p "$1" 2>/dev/null | tr -s ' ' | sed 's/^ //;s/ $//'; }
ticket_alive() {  # <ticket file> <pid>
  local want; want="$(sed -n 2p "$1" 2>/dev/null)"
  [ -n "$want" ] && alive "$2" && [ "$(proc_start "$2")" = "$want" ]
}

quiet_told=0
quiet_wait() {
  [ "${GATE_IGNORE_QUIET:-}" = 1 ] && return 0
  while [ -f "$RT/quiet-mode" ]; do
    if [ "$quiet_told" = 0 ]; then echo "gate-throttle: QUIET MODE is on; waiting for it to turn off..." >&2; quiet_told=1; fi
    sleep "$poll"
  done
}

my_ticket=""
take_ticket() {
  local n
  exec 8>"$qdir/lock"; "$FLOCK" 8
  n="$(cat "$qdir/counter" 2>/dev/null || echo 0)"; n=$((n + 1)); echo "$n" > "$qdir/counter"
  my_ticket="$(printf '%010d.%d' "$n" "$$")"
  # line 1: the waiter's dir (for status), line 2: its start time (liveness). Written whole, then renamed
  # into place, so a reader never sees a ticket without its start time and takes it for dead.
  printf '%s\n%s\n' "$(pwd -P)" "$(proc_start $$)" > "$qdir/.new.$$" && mv -f "$qdir/.new.$$" "$qdir/$my_ticket"
  exec 8>&-
}
drop_ticket() { [ -n "$my_ticket" ] && rm -f "$qdir/$my_ticket"; my_ticket=""; }
am_head() {  # 0 = I am the oldest live waiter (dead waiters' tickets are deleted on the way)
  local f pid
  for f in $(ls "$qdir" 2>/dev/null | grep -E '^[0-9]{10}\.[0-9]+$' | sort); do
    [ "$f" = "$my_ticket" ] && return 0
    pid="${f#*.}"
    ticket_alive "$qdir/$f" "$pid" && return 1
    rm -f "$qdir/$f"
  done
  return 0
}

cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
max_load="${GATE_MAX_LOAD:-$(awk -v n="$cpus" 'BEGIN { printf "%.2f", n * 0.9 }')}"
load_now() {
  if [ -n "${KIT_LOADAVG_FILE:-}" ]; then cut -d' ' -f1 "$KIT_LOADAVG_FILE" 2>/dev/null
  elif [ -r /proc/loadavg ]; then cut -d' ' -f1 /proc/loadavg
  else sysctl -n vm.loadavg 2>/dev/null | tr -d '{}' | awk '{print $1}'; fi
}
load_ok() {
  local l; l="$(load_now)"
  [ -z "$l" ] && return 0
  awk -v l="$l" -v m="$max_load" 'BEGIN { exit !(l < m) }'
}

min_free_mb="${GATE_MIN_FREE_MB:-3072}"
case "$min_free_mb" in ''|*[!0-9]*) min_free_mb=3072 ;; esac
mem_avail_mb() {  # available memory in MB; empty when unreadable
  local f="${KIT_MEMINFO_FILE:-/proc/meminfo}"
  [ -r "$f" ] || return 0
  awk '/^MemAvailable:/ { printf "%d", $2 / 1024 }' "$f" 2>/dev/null
}
mem_ok() {  # 0 = a normal slot beyond the first may start
  local m; m="$(mem_avail_mb)"
  [ -z "$m" ] && return 0
  [ "$m" -ge "$min_free_mb" ]
}
running_normal() {  # how many normal-slot commands are running now (live pid, numeric slot)
  local f n=0 pid
  for f in "$rdir"/*; do
    [ -e "$f" ] || continue
    pid="${f##*/}"
    case "$(cut -f1 "$f" 2>/dev/null)" in ''|*[!0-9]*) continue ;; esac
    alive "$pid" && n=$((n + 1))
  done
  echo "$n"
}

take_ticket
trap 'drop_ticket; rm -f "$rdir/$$"' EXIT
load_told=0
mem_told=0
while :; do
  cands=""
  # The quiet-mode escape also skips the line: the waiters ahead are parked in quiet mode and would hold it forever.
  if am_head || { [ "${GATE_IGNORE_QUIET:-}" = 1 ] && [ -f "$RT/quiet-mode" ]; }; then
    if load_ok; then
      cands="$(seq 1 "$slots")"; load_told=0
      if [ "$slots" -gt 1 ] && ! mem_ok && [ "$(running_normal)" -ge 1 ]; then
        cands=""
        if [ "$mem_told" = 0 ]; then
          echo "gate-throttle: next in line, holding: $(mem_avail_mb) MB available < $min_free_mb MB (GATE_MIN_FREE_MB); one slot until memory frees" >&2; mem_told=1
        fi
      else mem_told=0; fi
    elif [ "$load_told" = 0 ]; then
      echo "gate-throttle: next in line, holding: load $(load_now) >= $max_load (GATE_MAX_LOAD)" >&2; load_told=1
    fi
  fi
  [ "$prio" = 1 ] && cands="prio $cands"
  for i in $cands; do
    quiet_wait
    exec 9>"$locks_dir/gate-slot-$i.lock"
    if "$FLOCK" -n 9; then
      drop_ticket
      printf '%s\t%s\t%s\n' "$i" "$(pwd -P)" "$*" > "$rdir/$$"
      echo "gate-throttle: slot $i acquired $(date +%H:%M:%S) in $(pwd -P)" >&2
      # 9>&-: the command does not inherit the lock fd, so a daemon it leaves behind (a dev server, a
      # watcher) cannot keep the slot after it returns. This shell's own fd 9 holds the lock until exit.
      run "$@" 9>&-; rc=$?
      exit $rc
    fi
    exec 9>&-
  done
  sleep "$poll"
done
