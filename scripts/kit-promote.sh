#!/usr/bin/env bash
# kit-promote.sh — move the workshop's kit into production, or bring production's into the workshop.
#
# Run it from the TEST copy of the kit. Production is the folder this copy was cloned from (its git
# remote `origin`, a folder on this machine) — the kit your projects load. Both use the same branch.
#
# Promote (the default) refuses unless every one of these holds, and says which did not:
#   - both trees have no uncommitted changes to tracked files (untracked private notes are fine)
#   - production's branch is an ancestor of this one (else run --sync first and re-test)
#   - this copy has commits production does not
#   - the suite passes here (bash tests/run.sh; KIT_PROMOTE_TEST overrides the command)
# Then production fast-forwards to this copy's branch. Nothing here touches a network remote.
# Projects carry copies of the kit's scripts; promote lists the kit projects whose copies now differ,
# so each can be re-copied (and its own gate run) on purpose, never silently.
#
# Usage: kit-promote.sh [--sync] [--dry-run]
#   --sync   merge production's branch into this copy (fast-forward when it can), for fixes made there
# Exit 0 done, 1 refused, 64 usage.
set -uo pipefail

TEST="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
mode=promote; dry=0
for a in "$@"; do
  case "$a" in --sync) mode=sync ;; --dry-run) dry=1 ;; *) sed -n '16,17p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64 ;; esac
done
PROD="$(git -C "$TEST" remote get-url origin 2>/dev/null)"
[ -n "$PROD" ] && [ -d "$PROD/.git" ] || { echo "kit-promote: origin is not a folder on this machine ('$PROD'); run this from the test copy of the kit" >&2; exit 1; }
PROD="$(cd "$PROD" && pwd)"
[ "$PROD" != "$TEST" ] || { echo "kit-promote: this IS production; run it from the test copy" >&2; exit 1; }
BR="$(git -C "$TEST" branch --show-current)"
[ "$(git -C "$PROD" branch --show-current)" = "$BR" ] || { echo "kit-promote: production is on '$(git -C "$PROD" branch --show-current)', this copy on '$BR'; they must match" >&2; exit 1; }
dirty() { [ -n "$(git -C "$1" status --porcelain --untracked-files=no)" ]; }
run() { if [ "$dry" = 1 ]; then echo "dry-run: $*"; else "$@"; fi; }

if [ "$mode" = sync ]; then
  dirty "$TEST" && { echo "kit-promote --sync: this copy has uncommitted changes; commit them first" >&2; exit 1; }
  run git -C "$TEST" fetch -q "$PROD" "$BR" && run git -C "$TEST" merge -q --no-edit FETCH_HEAD && echo "production's $BR merged into the test copy; run the suite before promoting"
  exit $?
fi

why=()
dirty "$TEST" && why+=("the test copy has uncommitted changes")
dirty "$PROD" && why+=("production has uncommitted changes")
git -C "$TEST" fetch -q "$PROD" "$BR" || why+=("cannot read production's $BR")
P_HEAD="$(git -C "$TEST" rev-parse FETCH_HEAD 2>/dev/null)"
git -C "$TEST" merge-base --is-ancestor "$P_HEAD" HEAD || why+=("production has commits the test copy lacks: run kit-promote.sh --sync, then re-test")
[ "$P_HEAD" != "$(git -C "$TEST" rev-parse HEAD)" ] || why+=("nothing to promote: production already has every commit")
if [ "${#why[@]}" -eq 0 ]; then
  echo "==> running the suite in the test copy"
  if ! (cd "$TEST" && eval "${KIT_PROMOTE_TEST:-bash tests/run.sh}") >"$TEST/.promote-suite.log" 2>&1; then
    why+=("the suite failed (last lines below; full log: $TEST/.promote-suite.log)")
    tail -15 "$TEST/.promote-suite.log" >&2
  fi
fi
if [ "${#why[@]}" -gt 0 ]; then
  echo "kit-promote: refused:" >&2; printf '  - %s\n' "${why[@]}" >&2; exit 1
fi
echo "==> promoting $(git -C "$TEST" log --oneline "$P_HEAD"..HEAD | wc -l | tr -d ' ') commit(s) into $PROD ($BR):"
git -C "$TEST" log --oneline "$P_HEAD"..HEAD | sed 's/^/      /'
run git -C "$PROD" fetch -q "$TEST" "$BR" && run git -C "$PROD" merge -q --ff-only FETCH_HEAD || { echo "kit-promote: the fast-forward failed" >&2; exit 1; }
rm -f "$TEST/.promote-suite.log"
echo "==> production is now at $(git -C "$PROD" rev-parse --short HEAD). New sessions load it; running ones keep the old kit until recycled."

# Projects whose copies of the kit's scripts now differ from production's.
conf="${KIT_STATE_DIR:-$HOME/.orchestration-kit}/launcher.conf"
projects="$(sed -n 's/^[[:space:]]*projects_dir[[:space:]]*=[[:space:]]*//p' "$conf" 2>/dev/null | tail -1)"
case "$projects" in "~"|"~/"*) projects="$HOME${projects#\~}" ;; esac
[ -d "$projects" ] || exit 0
for d in "$projects"/*/; do
  d="${d%/}"; [ -f "$d/docs/orchestration/ORCHESTRATION.md" ] && [ ! -f "$d/.git/kit-trial" ] || continue
  old=(); for f in "$d"/scripts/*; do [ -f "$PROD/scripts/$(basename "$f")" ] && ! cmp -s "$f" "$PROD/scripts/$(basename "$f")" && old+=("$(basename "$f")"); done
  [ "${#old[@]}" -eq 0 ] || echo "    $(basename "$d"): older copies of ${old[*]} (re-copy them and run its gate before committing)"
done
exit 0
