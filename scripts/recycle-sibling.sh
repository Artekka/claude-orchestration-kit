#!/usr/bin/env bash
# recycle-sibling.sh — replace a named Claude Code session with a fresh one (orchestration-kit).
#
# Launch-first-then-kill: open a NEW window running `claude --name <Name> <prompt>`, wait until
# the fresh process exists, THEN SIGTERM the old one — so no seat is ever empty, and SIGTERM
# (not KILL) so the old transcript flushes. Run ONLY after the session replied "retro complete"
# (the retro-before-clear handshake). Terminal detection, quoting, nvm: see lib-launch.sh.
# Where no fresh process can be confirmed (Git Bash: no pgrep) the old one is never killed.
# With no usable terminal ('manual') it prints what to do by hand and exits 2.
# You can change the team's names, permission mode or terminal at any time — just ask Claude.
#
# Usage:
#   scripts/recycle-sibling.sh [--dry-run] [--mode normal|accept-edits|auto] [--account N|DIR]
#                              [--model M] [--effort E]
#                              [--terminal BACKEND|auto|list] [--repo DIR] <Name> [prompt]
#     prompt defaults to /orchestration-kit:orient, or /orchestration-kit:orchestrate for the seat.
#     mode / terminal default to the team block (ORCHESTRATION.md), else normal / auto-detect.
#     account: the fresh session INHERITS the old one's Claude Code account (its CLAUDE_CONFIG_DIR);
#     --account N|DIR moves it (1 = default ~/.claude, N = ~/.claude-acctN). docs/MULTI-ACCOUNT.md
#     model: ALWAYS passed to the fresh session, never inherited from the old one (the account is,
#     the model is not). --model M = opus[1m] | sonnet[1m] | haiku | a full model id; default = the
#     team block's `model:`, else opus[1m]. --effort low|medium|high|xhigh|max is passed only when
#     given. Bad values exit 64. The lane -> model table is in skills/orchestrate ("Model per lane").
#   scripts/recycle-sibling.sh Orca          # seat self-recycle
#   scripts/recycle-sibling.sh Sib2 --model 'sonnet[1m]' --effort high
#
# Env overrides: REPO_DIR (repo to open in), WT_EXE (full path to wt.exe).
set -euo pipefail
# shellcheck source-path=SCRIPTDIR source=lib-launch.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-launch.sh"

usage() { sed -n '12,27p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }

DRY=0; REPO=""; MODE=""; TERM_OPT=""; ACCOUNT=""; MODEL=""; EFFORT=""; MODEL_SET=0; EFFORT_SET=0; args=()
# A flag whose value is missing is exit 64 like a bad value (`${1:?}` would exit 1).
need_value() { [ "$1" -ge 2 ] || { echo "$2 needs a value: $3" >&2; exit 64; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --repo) shift; REPO="${1:?--repo needs a directory}" ;;
    --mode) shift; MODE="${1:?--mode needs normal|accept-edits|auto}" ;;
    --account) shift; ACCOUNT="${1:?--account needs a number (1, 2, 3...) or a config directory}" ;;
    # MODEL_SET / EFFORT_SET record "given", apart from "empty": `--model=` is a given, invalid value.
    --model) need_value $# --model "a model id, e.g. opus[1m]"; shift; MODEL="$1"; MODEL_SET=1 ;;
    --model=*) MODEL="${1#--model=}"; MODEL_SET=1 ;;
    --effort) need_value $# --effort "low|medium|high|xhigh|max"; shift; EFFORT="$1"; EFFORT_SET=1 ;;
    --effort=*) EFFORT="${1#--effort=}"; EFFORT_SET=1 ;;
    --terminal) shift; TERM_OPT="${1:?--terminal needs a backend, auto, or list}" ;;
    -h|--help) usage ;;
    -*) echo "unknown flag: $1" >&2; usage ;;
    *) args+=("$1") ;;
  esac
  shift
done
[ "${#args[@]}" -le 2 ] || { echo "too many arguments (<Name> [prompt] only; quote a prompt that has spaces): ${args[*]}" >&2; usage; }
REPO="$(launch_repo "$REPO")" || exit 64
if [ "$TERM_OPT" = list ]; then launch_list_backends; exit 0; fi
[ "${#args[@]}" -ge 1 ] || usage
name="${args[0]}"
launch_team_conf "$REPO"
default_prompt="/orchestration-kit:orient"
if [ "$name" = "${TEAM_SEAT:-Orca}" ]; then default_prompt="/orchestration-kit:orchestrate"; fi
prompt="${args[1]:-$default_prompt}"
launch_check_args "$name" "$prompt"
launch_set_mode "${MODE:-${TEAM_MODE:-normal}}"
launch_resolve_model "$MODEL" "$MODEL_SET" "$EFFORT" "$EFFORT_SET"
launch_init "$REPO" "${TERM_OPT:-${TEAM_TERMINAL:-}}"

manual_help() {
  cat >&2 <<HELP
No terminal this script can open windows in ($LAUNCH_REASON). Do it by hand:
  1. Open a new terminal.
  2. Run:  $(launch_manual_cmd "$name" "$prompt")
  3. Once the fresh session is up, close the old '${name}' terminal (or: pkill -TERM -f '$(launch_pattern "$name")').
HELP
}

old="$(launch_pids "$name")"
if [ -n "$ACCOUNT" ]; then
  launch_set_account "$ACCOUNT"
elif [ -n "$old" ]; then  # keep the session on the account it was running on
  launch_set_account "$(launch_account_of_pid "$(printf '%s\n' "$old" | head -1)")"
fi
if [ "$DRY" -eq 1 ]; then
  echo "[dry-run] nothing will be launched or killed"
  launch_describe_env
  launch_describe "$name" "$prompt"
  if [ "$LAUNCH_CAN_VERIFY" = 1 ]; then
    echo "old pids   ${old:-none} (matched: pgrep -f '$(launch_pattern "$name")') -> SIGTERM after the fresh one appears"
  else
    echo "old pids   unknown (no pgrep) -> nothing is killed; close the old '$name' window by hand"
  fi
  exit 0
fi

if [ "$LAUNCH_FORCED" = 1 ] && [ "$LAUNCH_AVAILABLE" = 0 ]; then
  echo "terminal '$LAUNCH_BACKEND' — $LAUNCH_REASON. See: scripts/recycle-sibling.sh --terminal list" >&2; exit 64
fi
if [ "$LAUNCH_BACKEND" = manual ]; then manual_help; exit 2; fi

if ! launch_open "$name" "$prompt" "$old"; then
  echo "no fresh '$name' process appeared; the old one is left running: ${old:-none}" >&2
  exit 1
fi
if [ "$LAUNCH_FRESH" = unverified ]; then
  echo "opened a fresh ${name} window (${LAUNCH_BACKEND}) but cannot confirm it here (no pgrep)."
  echo "Nothing was killed: once the new window is up, close the old '${name}' window yourself."
  exit 0
fi

# shellcheck disable=SC2086  # $old may hold several pids, one per line
if [ -n "$old" ]; then kill -TERM $old; fi
echo "fresh ${name}: ${LAUNCH_FRESH} · account $(launch_account_label) · model ${LAUNCH_MODEL} · SIGTERM old: ${old:-none} · via ${LAUNCH_BACKEND} · $(date '+%H:%M:%S %Z')"
if [ "$LAUNCH_BACKEND" = tmux-detached ]; then echo "attach with: tmux attach -t $(launch_tmux_session)"; fi
