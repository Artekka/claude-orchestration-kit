#!/usr/bin/env bash
# recycle-sibling.sh — replace a named Claude Code session with a fresh one (orchestration-kit).
#
# Launch-first-then-kill: open a NEW Windows console running `claude --name <Name> <prompt>`,
# wait until the fresh process exists, THEN SIGTERM the old one — so no seat is ever empty,
# and SIGTERM (not KILL) so the old transcript flushes. Run ONLY after the session replied
# "retro complete" (the retro-before-clear handshake).
#
# Supported: Windows + WSL. Linux / macOS without WSL: prints what to do by hand, exits 2.
# Launcher details (wt.exe / conhost fallback, quoting rules, nvm): see lib-launch.sh.
# You can change the team's names or permission mode at any time — just ask Claude to change it.
#
# Usage:
#   scripts/recycle-sibling.sh [--dry-run] [--mode normal|accept-edits|auto] [--repo DIR] <Name> [prompt]
#     prompt defaults to /orchestration-kit:orient, or /orchestration-kit:orchestrate for the seat.
#     mode defaults to the team block's permission_mode (ORCHESTRATION.md), else normal.
#   scripts/recycle-sibling.sh Orca          # seat self-recycle
#
# Env overrides: REPO_DIR (repo to open in), WT_EXE (full path to wt.exe).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib-launch.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-launch.sh"

usage() { sed -n '13,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }

DRY=0; REPO=""; MODE=""; args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --repo) shift; REPO="${1:?--repo needs a directory}" ;;
    --mode) shift; MODE="${1:?--mode needs normal|accept-edits|auto}" ;;
    -h|--help) usage ;;
    *) args+=("$1") ;;
  esac
  shift
done
[ "${#args[@]}" -ge 1 ] || usage
name="${args[0]}"
REPO="$(launch_repo "$REPO")" || exit 64
launch_team_conf "$REPO"
default_prompt="/orchestration-kit:orient"
if [ "$name" = "${TEAM_SEAT:-Orca}" ]; then default_prompt="/orchestration-kit:orchestrate"; fi
prompt="${args[1]:-$default_prompt}"
launch_check_args "$name" "$prompt"
launch_set_mode "${MODE:-${TEAM_MODE:-normal}}"

if ! launch_is_wsl; then
  cat >&2 <<EOF
recycle-sibling.sh only automates Windows + WSL. On this system, do it by hand:
  1. Open a new terminal in the repo.
  2. Run:  claude --name ${name} $(launch_mode_flags "$LAUNCH_MODE")'${prompt}'
  3. Once the fresh session is up, close the old '${name}' terminal (or: pkill -TERM -f '$(launch_pattern "$name")').
EOF
  exit 2
fi
launch_init "$REPO"
old="$(launch_pids "$name")"

if [ "$DRY" -eq 1 ]; then
  echo "[dry-run] nothing will be launched or killed"
  launch_describe_env
  launch_describe "$name" "$prompt"
  echo "old pids   ${old:-none} (matched: pgrep -f '$(launch_pattern "$name")') -> SIGTERM after the fresh one appears"
  exit 0
fi

if ! launch_open "$name" "$prompt" "$old"; then
  echo "no fresh '$name' process appeared; the old one is left running: ${old:-none}" >&2
  exit 1
fi

# shellcheck disable=SC2086  # $old may hold several pids, one per line
if [ -n "$old" ]; then kill -TERM $old; fi
echo "fresh ${name}: ${LAUNCH_FRESH} · SIGTERM old: ${old:-none} · $(date '+%H:%M:%S %Z')"
