#!/usr/bin/env bash
# kit-launch.sh — the project picker behind your trigger word (orchestration-kit).
#
# kit-word.sh install <word> makes <word> run this. It lists the projects in your projects folder;
# picking one with the kit set up (docs/orchestration/ORCHESTRATION.md) starts its team
# (scripts/start-team.sh: the seat plus siblings); picking one without it offers to set the kit up
# (/orchestration-kit:kit-init) or open a plain Claude chat there. [n] makes a new project.
# [t] opens the kit WORKSHOP when one is set: a chat that edits a test copy of the kit while running
# on the installed kit itself, so a broken change never breaks the session fixing it.
#
# Usage: kit-launch.sh [project]      a name in the projects folder skips the menu
#        kit-launch.sh --list         the projects and whether each has the kit, then exit
# Settings, in ${KIT_STATE_DIR:-~/.orchestration-kit}/launcher.conf (key=value; kit-word.sh writes it):
#   projects_dir=~/projects           where projects live (default ~/projects)
#   workshop=~/kit-test               optional: the test copy of the kit [t] opens
#   workshop_label=kit-test           optional: the name [t] shows
# Folders ending in -Test (trial copies), folders starting with _ (e.g. _archive) and the kit's own folder
# are not listed.
# Exit 0 done or quit, 1 no such project, 64 usage.
set -uo pipefail

KIT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
STATE="${KIT_STATE_DIR:-$HOME/.orchestration-kit}"
CONF="$STATE/launcher.conf"

conf() {  # <key> -> its value, ~ expanded; '' when unset
  [ -f "$CONF" ] || return 0
  local v; v="$(sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$CONF" | tail -1 | sed 's/[[:space:]]*$//')"
  case "$v" in "~"|"~/"*) v="$HOME${v#\~}" ;; esac
  printf '%s' "$v"
}
PROJECTS="$(conf projects_dir)"
if [ -z "$PROJECTS" ]; then PROJECTS="$HOME/projects"; fi
WORKSHOP="$(conf workshop)"; [ -z "$WORKSHOP" ] || [ -d "$WORKSHOP" ] || WORKSHOP=""
WLABEL="$(conf workshop_label)"; [ -n "$WLABEL" ] || WLABEL="${WORKSHOP:+$(basename "$WORKSHOP")}"
WORD="$(conf word)"; [ -n "$WORD" ] || WORD="kit"

has_kit() { [ -f "$1/docs/orchestration/ORCHESTRATION.md" ]; }

# run <dir> <command...>: start it in <dir>, in this terminal. KIT_LAUNCH_DRY=1 prints it instead (tests).
run() {
  local dir="$1"; shift
  if [ -n "${KIT_LAUNCH_DRY:-}" ]; then printf 'RUN in %s: %s\n' "$dir" "$*"; return 0; fi
  cd "$dir" || { echo "cannot enter $dir" >&2; return 1; }
  exec "$@"
}

start_team() {
  local p="$1" st="$1/scripts/start-team.sh"
  echo "==> $(basename "$p"): starting its team"
  # The project's own copy first: it is the version the project's gate was run against.
  if [ -f "$st" ]; then run "$p" bash "$st"; else run "$p" bash "$KIT/scripts/start-team.sh" --repo "$p"; fi
}

set_up_or_chat() {
  local p="$1" a=""
  echo "==> $(basename "$p") does not have the kit set up yet."
  read -r -p "    [s] set it up now   [c] just open a Claude chat there   [b] back : " a || return 1
  case "$a" in
    [sS]*) run "$p" claude "/orchestration-kit:kit-init" ;;
    [cC]*) run "$p" claude ;;
    *) return 2 ;;
  esac
}

open_project() { if has_kit "$1"; then start_team "$1"; else set_up_or_chat "$1"; fi; }

workshop() {
  echo "==> Workshop: editing the test kit at $WORKSHOP (this chat runs on the installed kit)"
  run "$WORKSHOP" claude "You are the kit WORKSHOP. You edit the TEST copy of the orchestration kit in this folder ($WORKSHOP); production is $KIT and is never edited here. You run on the production kit: never load this copy into your own session. Run its suite with: bash tests/run.sh. To see a change working, start a trial team with: bash scripts/kit-trial.sh <project> (a cut-off copy of the project, running this test kit). Promote only when the suite passes and the trial worked, with: bash scripts/kit-promote.sh. Start by reporting git status and the commits here that production does not have yet (git log --oneline @{upstream}..HEAD)."
}

new_project() {
  local name="" dir
  read -r -p "    New project name: " name || return 1
  case "$name" in ""|*/*|.*) echo "    Not a usable folder name: '$name'"; return 2 ;; esac
  dir="$PROJECTS/$name"
  [ ! -e "$dir" ] || { echo "    $dir already exists"; return 2; }
  mkdir -p "$dir" && git -C "$dir" init -q && echo "==> made $dir (a new git repo)"
  run "$dir" claude "/orchestration-kit:kit-init"
}

PROJ=()
list_projects() {
  PROJ=()
  local d
  [ -d "$PROJECTS" ] || return 0
  while IFS= read -r -d '' d; do
    case "$d" in *-Test) continue ;; esac
    [ "$(cd "$d" && pwd -P)" = "$(cd "$KIT" && pwd -P)" ] && continue
    PROJ+=("$d")
  done < <(find "$PROJECTS" -mindepth 1 -maxdepth 1 -type d ! -name '.*' ! -name '_*' -print0 | sort -z)
}

list_projects
case "${1:-}" in
  -h|--help) sed -n "2,20p" "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --list)
    for d in "${PROJ[@]+"${PROJ[@]}"}"; do if has_kit "$d"; then echo "kit  $(basename "$d")"; else echo "-    $(basename "$d")"; fi; done
    exit 0 ;;
  -*) echo "usage: kit-launch.sh [project] | --list" >&2; exit 64 ;;
  "") ;;
  *)
    [ -d "$PROJECTS/$1" ] || { echo "no project '$1' in $PROJECTS" >&2; exit 1; }
    open_project "$PROJECTS/$1"; exit $? ;;
esac

while :; do
  echo ""
  echo "  $WORD — pick a project   ($PROJECTS)"
  echo "  ------------------------------------------------"
  [ "${#PROJ[@]}" -gt 0 ] || echo "  (no projects yet)"
  for i in "${!PROJ[@]}"; do
    if has_kit "${PROJ[i]}"; then tag="team"; else tag="no kit yet"; fi
    printf '  [%d] %-28s %s\n' "$((i+1))" "$(basename "${PROJ[i]}")" "$tag"
  done
  echo "  ------------------------------------------------"
  [ -z "$WORKSHOP" ] || printf '  [t] %-28s %s\n' "$WLABEL" "workshop: edit the test kit"
  echo "  [n] new project   [q] quit"
  c=""
  read -r -p "  Select: " c || exit 0
  case "$c" in
    [qQ]) exit 0 ;;
    [nN]) new_project; rc=$?; [ "$rc" -eq 2 ] || exit "$rc" ;;
    [tT]) if [ -n "$WORKSHOP" ]; then workshop; exit $?; fi; echo "  No workshop set (workshop= in $CONF)." ;;
    *)
      if [[ "$c" =~ ^[0-9]+$ ]] && [ "$c" -ge 1 ] && [ "$c" -le "${#PROJ[@]}" ]; then
        open_project "${PROJ[$((c-1))]}"; rc=$?; [ "$rc" -eq 2 ] || exit "$rc"
      else
        echo "  Pick a number, n, or q."
      fi ;;
  esac
done
