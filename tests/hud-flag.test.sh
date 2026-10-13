#!/usr/bin/env bash
# Tests for scripts/hud-flag.sh: mark a session STUCK for the status HUD, and take the mark off. Run: bash tests/hud-flag.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; F="$ROOT/scripts/hud-flag.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
has() { case "$3" in *"$2"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL $1: want '$2' in: $3" ;; esac; }
rc_is() { [ "$2" = "$3" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL $1: want exit $2, got $3"; }; }
run() { HUD_STATUS_DIR="$TMP" bash "$F" "$@" 2>&1; }
out="$(run Mars 'no reply to ping "20 min"')"; rc_is "flag: exit 0" 0 $?
j="$(cat "$TMP/flags/Mars.json")"
has "flag: reason, quotes escaped" '"reason":"no reply to ping \"20 min\""' "$j"
python3 -c 'import json,sys,time; d=json.loads(sys.argv[1]); assert abs(d["at"]-time.time()*1000) < 60000, d' "$j" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL flag: at is epoch milliseconds: $j"; }
[ "$(stat -c %a "$TMP/flags/Mars.json")" = 600 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL flag file is not 600"; }
long="$(printf 'x%.0s' $(seq 1 90))"; run Venus "$long" >/dev/null
has "flag: reason cut to 60" "\"reason\":\"$(printf 'x%.0s' $(seq 1 60))\"" "$(cat "$TMP/flags/Venus.json")"
out="$(run Mars --off)"; rc_is "off: exit 0" 0 $?
[ ! -e "$TMP/flags/Mars.json" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL --off left the file"; }
out="$(run 'Bad Name' x)"; rc_is "bad name: exit 64" 64 $?
out="$(run Mars)"; rc_is "missing reason: exit 64" 64 $?
echo "hud-flag: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
