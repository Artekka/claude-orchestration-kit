#!/usr/bin/env bash
# start-team.sh — open the seat + N sibling Claude sessions, each in its own window (orchestration-kit).
#
# Zero setup: with no flags and no config it opens `Orca` (/orchestration-kit:orchestrate) and
# `Sib1`..`Sib2` (/orchestration-kit:orient) in the repo's main checkout, in normal permission
# mode. Names already running are SKIPPED, so re-running only fills the gaps. Windows + WSL only
# (see lib-launch.sh); elsewhere it prints the commands to run by hand and exits 2.
# You can change the team size, names or permission mode at any time — just ask Claude to change it.
#
# Usage:
#   scripts/start-team.sh [--dry-run] [--siblings N] [--seat NAME] [--prefix PFX]
#                         [--mode normal|accept-edits|auto] [--repo DIR]
#
# Precedence: flags > the optional `team:` block in docs/orchestration/ORCHESTRATION.md > defaults.
# A --mode flag is saved into that block (permission_mode:) so recycles relaunch in the same mode.
#   team:
#     seat:             Orca
#     prefix:           Sib
#     siblings:         2
#     permission_mode:  normal
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib-launch.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-launch.sh"

usage() { sed -n '10,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }

SEAT_PROMPT="/orchestration-kit:orchestrate"
SIB_PROMPT="/orchestration-kit:orient"
DRY=0; REPO=""; f_seat=""; f_prefix=""; f_n=""; f_mode=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --siblings) shift; f_n="${1:?--siblings needs a number}" ;;
    --seat) shift; f_seat="${1:?--seat needs a name}" ;;
    --prefix) shift; f_prefix="${1:?--prefix needs a name prefix}" ;;
    --mode) shift; f_mode="${1:?--mode needs normal|accept-edits|auto}" ;;
    --repo) shift; REPO="${1:?--repo needs a directory}" ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
  shift
done

# Repo first (the config lives in it). Works outside WSL too, for the manual-instructions path.
REPO="$(launch_repo "$REPO")" || exit 64
launch_team_conf "$REPO"

seat="${f_seat:-${TEAM_SEAT:-Orca}}"
prefix="${f_prefix:-${TEAM_PREFIX:-Sib}}"
n="${f_n:-${TEAM_N:-2}}"
if ! [[ "$n" =~ ^[0-9]$ ]]; then echo "--siblings must be 0..9: '$n'" >&2; exit 64; fi
launch_set_mode "${f_mode:-${TEAM_MODE:-normal}}"

names=("$seat"); prompts=("$SEAT_PROMPT")
for i in $(seq 1 "$n"); do names+=("${prefix}${i}"); prompts+=("$SIB_PROMPT"); done
for i in "${!names[@]}"; do launch_check_args "${names[$i]}" "${prompts[$i]}"; done

if ! launch_is_wsl; then
  echo "start-team.sh only automates Windows + WSL. Open one terminal per session in $REPO and run:" >&2
  LAUNCH_NVM=""
  for i in "${!names[@]}"; do echo "  $(launch_cmd "${names[$i]}" "${prompts[$i]}")" >&2; done
  exit 2
fi
launch_init "$REPO"

if [ "$DRY" -eq 1 ]; then
  echo "[dry-run] nothing will be launched or saved"
  launch_describe_env
  src="none (built-in defaults)"
  if [ -n "$TEAM_SEAT$TEAM_PREFIX$TEAM_N$TEAM_MODE" ]; then src="team: block in ${TEAM_CONF#"$REPO"/}"; fi
  echo "team       seat=${seat} siblings=${n} prefix=${prefix} mode=${LAUNCH_MODE}   config: ${src}; flags override"
elif [ -n "$f_mode" ] && [ "$f_mode" != "$TEAM_MODE" ]; then
  launch_save_mode "$REPO" "$LAUNCH_MODE"
fi

failed=0
for i in "${!names[@]}"; do
  name="${names[$i]}"; prompt="${prompts[$i]}"
  running="$(launch_pids "$name")"
  if [ -n "$running" ]; then
    echo "SKIP   $name — already running (pid $(echo "$running" | tr '\n' ' ' | sed 's/ $//'))"
    continue
  fi
  if [ "$DRY" -eq 1 ]; then
    echo "LAUNCH $name"
    launch_describe "$name" "$prompt" | sed 's/^/       /'
    continue
  fi
  if launch_open "$name" "$prompt" ""; then
    echo "OPENED $name (pid $LAUNCH_FRESH)"
  else
    echo "FAILED $name — no process appeared; open a window and run: $(launch_cmd "$name" "$prompt")" >&2
    failed=1
  fi
done
if [ "$DRY" -eq 0 ] && [ "$failed" -eq 0 ]; then
  echo "Team up. Talk to the seat (${seat}); siblings report to it."
  echo "You can change the team size, names or permission mode any time — just ask Claude."
fi
exit "$failed"
