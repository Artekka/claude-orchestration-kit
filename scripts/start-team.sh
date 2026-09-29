#!/usr/bin/env bash
# start-team.sh — open the seat + N sibling Claude sessions, each in its own window (orchestration-kit).
#
# Zero setup: with no flags and no config it opens `Orca` (/orchestration-kit:orchestrate) and
# `Sib1`..`Sib2` (/orchestration-kit:orient) in the repo's main checkout. Names already running are SKIPPED,
# so re-running only fills the gaps. Windows + WSL only (see lib-launch.sh); elsewhere it
# prints the commands to run by hand and exits 2.
#
# Usage:
#   scripts/start-team.sh [--dry-run] [--siblings N] [--seat NAME] [--prefix PFX] [--repo DIR]
#
# Precedence: flags > the optional `team:` block in docs/orchestration/ORCHESTRATION.md > defaults.
#   team:
#     seat:      Orca
#     prefix:    Sib
#     siblings:  2
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib-launch.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-launch.sh"

usage() { sed -n '9,16p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }

SEAT_PROMPT="/orchestration-kit:orchestrate"
SIB_PROMPT="/orchestration-kit:orient"
DRY=0; REPO=""; f_seat=""; f_prefix=""; f_n=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --siblings) shift; f_n="${1:?--siblings needs a number}" ;;
    --seat) shift; f_seat="${1:?--seat needs a name}" ;;
    --prefix) shift; f_prefix="${1:?--prefix needs a name prefix}" ;;
    --repo) shift; REPO="${1:?--repo needs a directory}" ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
  shift
done

# Repo first (the config lives in it). Works outside WSL too, for the manual-instructions path.
REPO="$(launch_repo "$REPO")" || exit 64

# Optional `team:` block: indented `key: value` lines under a line that is exactly `team:`.
c_seat=""; c_prefix=""; c_n=""
conf="$REPO/docs/orchestration/ORCHESTRATION.md"
if [ -f "$conf" ]; then
  while IFS='=' read -r k v; do
    case "$k" in seat) c_seat="$v" ;; prefix) c_prefix="$v" ;; siblings) c_n="$v" ;; esac
  done < <(awk '
    /^team:[[:space:]]*$/ { on=1; next }
    on && /^[[:space:]]+[a-z]+:/ { k=$1; sub(":", "", k); v=$2; print k "=" v; next }
    on { on=0 }' "$conf")
fi
# Config values that aren't valid (e.g. template placeholders like <Orca>) are ignored.
launch_valid_name "$c_seat" || c_seat=""
launch_valid_name "$c_prefix" || c_prefix=""
[[ "$c_n" =~ ^[0-9]+$ ]] || c_n=""

seat="${f_seat:-${c_seat:-Orca}}"
prefix="${f_prefix:-${c_prefix:-Sib}}"
n="${f_n:-${c_n:-2}}"
if ! [[ "$n" =~ ^[0-9]$ ]]; then echo "--siblings must be 0..9: '$n'" >&2; exit 64; fi

names=("$seat"); prompts=("$SEAT_PROMPT")
for i in $(seq 1 "$n"); do names+=("${prefix}${i}"); prompts+=("$SIB_PROMPT"); done
for i in "${!names[@]}"; do launch_check_args "${names[$i]}" "${prompts[$i]}"; done

if ! launch_is_wsl; then
  echo "start-team.sh only automates Windows + WSL. Open one terminal per session in $REPO and run:" >&2
  for i in "${!names[@]}"; do echo "  claude --name ${names[$i]} '${prompts[$i]}'" >&2; done
  exit 2
fi
launch_init "$REPO"

if [ "$DRY" -eq 1 ]; then
  echo "[dry-run] nothing will be launched"
  launch_describe_env
  src="none (built-in defaults)"; if [ -n "$c_seat$c_prefix$c_n" ]; then src="team: block in ${conf#"$REPO"/}"; fi
  echo "team       seat=${seat} siblings=${n} prefix=${prefix}   config: ${src}; flags override"
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
    echo "FAILED $name — no process appeared; open a window and run: claude --name $name '$prompt'" >&2
    failed=1
  fi
done
[ "$DRY" -eq 1 ] || [ "$failed" -eq 1 ] || echo "Team up. Talk to the seat (${seat}); siblings report to it."
exit "$failed"
