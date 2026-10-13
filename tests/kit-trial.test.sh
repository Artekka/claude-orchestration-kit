#!/usr/bin/env bash
# Tests for scripts/kit-trial.sh (a trial copy of a project, on a test kit) and scripts/kit-promote.sh
# (test kit -> production). Run: bash tests/kit-trial.test.sh   (sandboxed: fake HOME and repos; the
# trial stops at the login step, so no claude and no terminal is ever started)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
has() { case "$3" in *"$2"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL $1: want '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) fail=$((fail+1)); echo "FAIL $1: did not want '$2' in: $3" ;; *) pass=$((pass+1)) ;; esac; }
rc_is() { [ "$2" = "$3" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL $1: want exit $2, got $3"; }; }
g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=live "$@"; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
H="$TMP/home"; mkdir -p "$H/.claude" "$H/.orchestration-kit"; P="$H/work"
printf '{"enabledPlugins":{"orchestration-kit@artekka-kits":true},"extraKnownMarketplaces":{"artekka-kits":{"source":{"source":"directory","path":"/prod"}}}}\n' > "$H/.claude/settings.json"
printf 'projects_dir=~/work\n' > "$H/.orchestration-kit/launcher.conf"

# A production kit and its test clone (only what the scripts touch).
PROD="$TMP/prod"; mkdir -p "$PROD/scripts" "$PROD/.claude-plugin" "$PROD/tests"
cp "$ROOT/scripts/kit-trial.sh" "$ROOT/scripts/kit-promote.sh" "$ROOT/scripts/start-team.sh" "$PROD/scripts/"
echo '{}' > "$PROD/.claude-plugin/plugin.json"; echo 'v1' > "$PROD/scripts/lib-launch.sh"
g init -q "$PROD"; g -C "$PROD" add -A; g -C "$PROD" commit -qm base
TEST="$TMP/test"; g clone -q "$PROD" "$TEST"
echo 'v2' > "$TEST/scripts/lib-launch.sh"; g -C "$TEST" commit -qam "kit change"

# A kit project with a live-service file and a remote.
mkdir -p "$P/My App/docs/orchestration" "$P/My App/scripts"
printf 'team:\n  seat:             Atlas-MA\n  prefix:           Sib\n  names:            Mars,Venus\n  tab_color:        #16a085\n' > "$P/My App/docs/orchestration/ORCHESTRATION.md"
echo 'v1' > "$P/My App/scripts/lib-launch.sh"; echo '{"scriptId":"live"}' > "$P/My App/.clasp.json"
g init -q "$P/My App"; g -C "$P/My App" add -A; g -C "$P/My App" commit -qm app; g -C "$P/My App" remote add origin https://example.invalid/app.git
trial() { env HOME="$H" bash "$TEST/scripts/kit-trial.sh" "$@" 2>&1; }

# --- kit-trial.sh
out="$(trial nope)"; rc_is "unknown project: refused" 1 $?
out="$(trial 'My App')"; rc_is "first run stops at the login step" 1 $?
has "says how to log in" "CLAUDE_CONFIG_DIR=$H/.orchestration-kit/trial-claude command claude /login" "$out"
C="$P/My App-Test"
[ -f "$C/.git/kit-trial" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL no trial marker"; }
rc_is "copy has no remotes" 0 "$(g -C "$C" remote | wc -l | tr -d ' ')"
[ ! -e "$C/.clasp.json" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL .clasp.json still in the copy"; }
[ -e "$P/My App/.clasp.json" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL the real project lost .clasp.json"; }
has "copy runs the test kit's scripts" "v2" "$(cat "$C/scripts/lib-launch.sh")"
has "the real project keeps its scripts" "v1" "$(cat "$P/My App/scripts/lib-launch.sh")"
o="$(cat "$C/docs/orchestration/ORCHESTRATION.md")"
has "seat renamed" "seat:             Atlas-MA-T" "$o"; has "names renamed" "Mars-T,Venus-T" "$o"; has "prefix renamed" "prefix:           SibT" "$o"
has "trial tabs are slate" "tab_color:        #455a64" "$o"
has "trial settings load the test kit" "\"path\": \"$TEST\"" "$(cat "$H/.orchestration-kit/trial-claude/settings.json")"
has "everyday settings untouched" '"path":"/prod"' "$(cat "$H/.claude/settings.json")"
out="$(trial 'My App')"
o="$(cat "$C/docs/orchestration/ORCHESTRATION.md")"; hasnt "re-run does not rename twice" "-T-T" "$o"
has "list" "My App-Test" "$(trial --list)"
mkdir -p "$P/Other-Test"; out="$(trial --remove Other)"; rc_is "remove refuses a folder it did not make" 1 $?
out="$(trial --remove 'My App')"; [ ! -e "$C" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL --remove left $C"; }

# --- kit-promote.sh
promote() { env HOME="$H" KIT_PROMOTE_TEST="${SUITE:-true}" bash "$TEST/scripts/kit-promote.sh" "$@" 2>&1; }
echo dirty >> "$TEST/scripts/lib-launch.sh"
out="$(promote)"; rc_is "dirty test copy: refused" 1 $?; has "says why" "uncommitted changes" "$out"
g -C "$TEST" checkout -q scripts/lib-launch.sh
out="$(SUITE=false promote)"; rc_is "failing suite: refused" 1 $?; has "says the suite failed" "the suite failed" "$out"
rc_is "production not moved by a refusal" 0 "$(g -C "$PROD" log --oneline | grep -c 'kit change')"
out="$(promote --dry-run)"; has "dry run says what it would do" "dry-run: git -C $PROD" "$out"
rc_is "dry run moves nothing" 0 "$(g -C "$PROD" log --oneline | grep -c 'kit change')"
out="$(promote)"; rc_is "promote: exit 0" 0 $?
has "production fast-forwarded" "v2" "$(cat "$PROD/scripts/lib-launch.sh")"
has "lists projects whose script copies are now older" "My App: older copies of lib-launch.sh" "$out"
out="$(promote)"; rc_is "nothing new: refused" 1 $?; has "says nothing to promote" "nothing to promote" "$out"
echo fix > "$PROD/hotfix"; g -C "$PROD" add hotfix; g -C "$PROD" commit -qm hotfix
echo v3 > "$TEST/scripts/lib-launch.sh"; g -C "$TEST" commit -qam v3
out="$(promote)"; rc_is "production ahead: refused" 1 $?; has "says to sync" "--sync" "$out"
out="$(promote --sync)"; rc_is "sync: exit 0" 0 $?
[ -f "$TEST/hotfix" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL --sync did not bring production's commit"; }
out="$(promote)"; rc_is "after sync: promote works" 0 $?
out="$(env HOME="$H" bash "$PROD/scripts/kit-promote.sh" 2>&1)"; rc_is "run from production: refused" 1 $?

echo "kit-trial: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
