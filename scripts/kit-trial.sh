#!/usr/bin/env bash
# kit-trial.sh — see a kit change working before it reaches your real projects (orchestration-kit).
#
# Run it from a TEST copy of the kit (the workshop). It starts a trial team that runs THIS copy of the
# kit, on "<project>-Test": a git clone of the project's local main with every way out cut, so nothing
# the trial does reaches the real project, its remote or a live service. The session that edits the kit
# keeps running on the installed kit, so a broken change cannot break the session judging it.
#
# What a trial is made of:
#   - <project>-Test beside the project: no git remotes, .clasp.json removed, the kit's scripts replaced
#     by this copy's, the team renamed (every name gets -T, so two seats of the same name never meet) and its tabs
#     slate grey (#455a64). Untracked files (.env, node_modules) are not copied. .git/kit-trial marks it.
#   - a Claude config folder of its own, ${KIT_STATE_DIR:-~/.orchestration-kit}/trial-claude, whose
#     settings load the kit from THIS folder. It needs its own login once (the script says how); your
#     everyday login is never shared, so a token refresh on one side cannot log the other out.
#   - start-team.sh --account <that folder>: recycles keep the folder, so the whole trial stays on it.
#
# Usage: kit-trial.sh <project> [--fresh] [--siblings N] [--dry-run]
#        kit-trial.sh --remove <project>      delete <project>-Test (only a folder this script made)
#        kit-trial.sh --list                  the trial copies
# Projects are found in launcher.conf's projects_dir (kit-launch.sh), else --projects DIR.
# Exit 0 done, 1 refused, 64 usage.
set -uo pipefail

KIT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
STATE="${KIT_STATE_DIR:-$HOME/.orchestration-kit}"
TRIAL_CFG="$STATE/trial-claude"
TRIAL_COLOR="#455a64"
SCRIPTS=(lib-launch.sh start-team.sh recycle-sibling.sh ctx-fill.py statusline-ctx.sh gate-throttle.sh quiet-mode.sh hud-flag.sh sibling-shell.sh pull-check.sh)

usage() { sed -n '18,22p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 64; }
die() { echo "kit-trial: $*" >&2; exit 1; }

mode=start; proj=""; fresh=0; sibs=""; dry=0; PROJECTS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --remove) mode=remove ;;
    --list) mode=list ;;
    --fresh) fresh=1 ;;
    --dry-run) dry=1 ;;
    --siblings) sibs="${2:?--siblings needs a number}"; shift ;;
    --projects) PROJECTS="${2:?--projects needs a folder}"; shift ;;
    -*) usage ;;
    *) [ -z "$proj" ] || usage; proj="$1" ;;
  esac
  shift
done
if [ -z "$PROJECTS" ] && [ -f "$STATE/launcher.conf" ]; then
  PROJECTS="$(sed -n 's/^[[:space:]]*projects_dir[[:space:]]*=[[:space:]]*//p' "$STATE/launcher.conf" | tail -1)"
  case "$PROJECTS" in "~"|"~/"*) PROJECTS="$HOME${PROJECTS#\~}" ;; esac
fi
[ -n "$PROJECTS" ] || PROJECTS="$HOME/projects"

is_trial() { [ -f "$1/.git/kit-trial" ]; }

if [ "$mode" = list ]; then
  for d in "$PROJECTS"/*-Test; do is_trial "$d" && echo "$(basename "$d")   $(head -1 "$d/.git/kit-trial")"; done
  exit 0
fi
[ -n "$proj" ] || usage
proj="${proj%-Test}"
SRC="$PROJECTS/$proj"; COPY="$PROJECTS/$proj-Test"

if [ "$mode" = remove ] || [ "$fresh" = 1 ]; then
  if [ -e "$COPY" ]; then
    is_trial "$COPY" || die "$COPY was not made by kit-trial.sh (no .git/kit-trial); not touching it"
    [ "$dry" = 1 ] && echo "would remove $COPY" || { rm -rf "$COPY" && echo "removed $COPY"; }
  fi
  [ "$mode" = remove ] && exit 0
fi

[ -f "$SRC/docs/orchestration/ORCHESTRATION.md" ] || die "no kit project '$proj' in $PROJECTS (it needs docs/orchestration/ORCHESTRATION.md)"
[ -f "$KIT/.claude-plugin/plugin.json" ] || die "$KIT is not a kit folder"
[ "$dry" = 1 ] && { echo "would make $COPY from $SRC (main), install $KIT's scripts, rename the team -T, and start it on $TRIAL_CFG"; exit 0; }

# 1. The copy. Made once; re-runs refresh its kit scripts and keep the trial's own work.
if [ ! -e "$COPY" ]; then
  git clone -q --no-local "$SRC" "$COPY" || die "git clone failed"
  for r in $(git -C "$COPY" remote); do git -C "$COPY" remote remove "$r"; done
  cut="remotes"
  if [ -f "$COPY/.clasp.json" ]; then git -C "$COPY" rm -q --cached .clasp.json 2>/dev/null; rm -f "$COPY/.clasp.json"; cut="$cut, .clasp.json"; fi
  printf 'trial of %s, made %s from %s; cut: %s\n' "$proj" "$(date '+%F %T')" "$(git -C "$SRC" rev-parse --short HEAD)" "$cut" > "$COPY/.git/kit-trial"
  echo "==> made $COPY (cut: $cut; untracked files such as .env were not copied)"
  if [ -n "$(git -C "$COPY" status --porcelain)" ]; then git -C "$COPY" commit -q -am "trial: cut $cut"; fi
fi
is_trial "$COPY" || die "$COPY exists but was not made by kit-trial.sh; not touching it"

# 2. This kit's scripts, and the team renamed and recoloured.
for f in "${SCRIPTS[@]}"; do [ -f "$KIT/scripts/$f" ] && cp "$KIT/scripts/$f" "$COPY/scripts/$f"; done
C="$COPY/docs/orchestration/ORCHESTRATION.md"
python3 - "$C" "$TRIAL_COLOR" <<'PY'
import re, sys
p, color = sys.argv[1], sys.argv[2]
s = open(p).read()
def val(k):
    m = re.search(r'^([ \t]+%s:[ \t]*)(\S+)' % k, s, re.M); return m
def put(k, v):
    global s
    if val(k): s = re.sub(r'^([ \t]+%s:[ \t]*)\S+' % k, lambda m: m.group(1) + v, s, count=1, flags=re.M)
    elif re.search(r'^team:[ \t]*$', s, re.M): s = re.sub(r'^team:[ \t]*$', 'team:\n  %s:        %s' % (k, v), s, count=1, flags=re.M)
    else: s += '\nteam:\n  %s:        %s\n' % (k, v)
seat = val('seat').group(2) if val('seat') else 'Orca'
if not seat.endswith('-T'): put('seat', seat + '-T')
if val('names'):
    names = val('names').group(2).split(',')
    put('names', ','.join(n if n.endswith('-T') else n + '-T' for n in names if n))
prefix = val('prefix').group(2) if val('prefix') else 'Sib'
if not prefix.endswith('T'): put('prefix', prefix + 'T')
put('tab_color', color)
open(p, 'w').write(s)
PY
git -C "$COPY" add scripts docs/orchestration/ORCHESTRATION.md
git -C "$COPY" diff --cached --quiet || git -C "$COPY" commit -q -m "trial: the test kit's scripts ($(git -C "$KIT" rev-parse --short HEAD)), team renamed -T"
echo "==> $COPY runs the kit from $KIT ($(git -C "$KIT" rev-parse --short HEAD))"

# 3. The trial's Claude config folder: your settings, with the kit loaded from this folder.
mkdir -p "$TRIAL_CFG"
[ -f "$TRIAL_CFG/.claude.json" ] || [ ! -f "$HOME/.claude.json" ] || cp "$HOME/.claude.json" "$TRIAL_CFG/.claude.json"
python3 - "$HOME/.claude/settings.json" "$TRIAL_CFG/settings.json" "$KIT" <<'PY'
import json, os, sys
src, dst, kit = sys.argv[1:4]
s = json.load(open(src)) if os.path.exists(src) else {}
s.setdefault('extraKnownMarketplaces', {})['artekka-kits'] = {'source': {'source': 'directory', 'path': kit}}
s.setdefault('enabledPlugins', {})['orchestration-kit@artekka-kits'] = True
json.dump(s, open(dst, 'w'), indent=2)
PY
if [ ! -e "$TRIAL_CFG/.credentials.json" ]; then
  echo "==> The trial's Claude folder needs its own login, once. Run this, log in, then /exit and run kit-trial.sh again:"
  echo "      CLAUDE_CONFIG_DIR=$TRIAL_CFG command claude /login"
  echo "    (\`command claude\` runs Claude Code itself, in this tab: a shell function or alias named claude may open"
  echo "     a new tab, and the folder setting would not reach it)"
  exit 1
fi
export CLAUDE_CONFIG_DIR="$TRIAL_CFG"
claude plugin marketplace add "$KIT" >/dev/null 2>&1 || true
for p in orchestration-kit status-hud; do
  if [ "$p" = status-hud ] && ! grep -q '"status-hud@' "$HOME/.claude/settings.json" 2>/dev/null; then continue; fi
  claude plugin list --json 2>/dev/null | grep -q "\"$p@artekka-kits\"" || claude plugin install "$p@artekka-kits" >/dev/null 2>&1 || echo "kit-trial: could not install $p into $TRIAL_CFG"
done
where="$(claude plugin list --json 2>/dev/null | python3 -c 'import json,sys; print(next((p.get("readFromFolder") or p.get("installPath") for p in json.load(sys.stdin) if p["id"].startswith("orchestration-kit@")), ""))')"
[ "$where" = "$KIT" ] || die "the trial's Claude folder loads the kit from '$where', not $KIT; not starting (claude plugin list under CLAUDE_CONFIG_DIR=$TRIAL_CFG)"
unset CLAUDE_CONFIG_DIR

# 4. The team.
echo "==> starting the trial team (tabs slate grey, names end in -T)"
cd "$COPY" || die "cannot enter $COPY"
exec bash scripts/start-team.sh --account "$TRIAL_CFG" ${sibs:+--siblings "$sibs"}
