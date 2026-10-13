#!/usr/bin/env bash
# hud-flag.sh (orchestration-kit): mark a session STUCK on the status HUD, or take the mark off.
#
#   bash scripts/hud-flag.sh <Name> "<reason>"     e.g. bash scripts/hud-flag.sh Mars "no reply to ping (20 min)"
#   bash scripts/hud-flag.sh <Name> --off
#
# Who calls it: a sibling that stops to wait on the seat ("blocked: <why>"), and the seat when a sibling it pinged
# has not answered (orchestrate skill §4). The HUD shows the session's activity as "STUCK · <reason>" in red until
# the session next makes progress (a tool call or a new prompt after the mark), so a stale mark lifts itself.
# Writes ${HUD_STATUS_DIR:-~/.claude-status-hud}/flags/<Name>.json ({"reason","at"}); nothing else. No network.
set -u
name="${1:-}"; reason="${2:-}"
[ -n "$name" ] && [ -n "$reason" ] || { echo "usage: hud-flag.sh <Name> \"<reason>\" | <Name> --off" >&2; exit 64; }
[[ "$name" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "hud-flag: '$name' is not a session name (letters, digits, _ and - only)" >&2; exit 64; }
dir="${HUD_STATUS_DIR:-$HOME/.claude-status-hud}/flags"
if [ "$reason" = "--off" ]; then rm -f "$dir/$name.json"; echo "unflagged $name"; exit 0; fi
mkdir -p "$dir" && chmod 700 "$dir" 2>/dev/null
# JSON-escape the reason (backslash, quote, control characters) and keep it short: it is one cell of a row.
esc="$(printf '%s' "${reason:0:60}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr -d '\000-\037')"
# Epoch milliseconds: seconds + nanoseconds cut to 13 digits (some `date`s ignore a %3N width); no %N = seconds only.
now_ms="$(date +%s%N 2>/dev/null)"; case "$now_ms" in *N|'') now_ms="$(( $(date +%s) * 1000 ))" ;; *) now_ms="${now_ms:0:13}" ;; esac
tmp="$dir/.$name.$$"
printf '{"reason":"%s","at":%s}\n' "$esc" "$now_ms" > "$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$dir/$name.json"
echo "flagged $name: ${reason:0:60}"
