#!/usr/bin/env bash
# Tests for the model-per-lane launch flags (--model / --effort; docs/GETTING-STARTED.md "Model per lane").
# Run: bash tests/lean-launch.test.sh
# Nothing is launched: every call is --dry-run. LAUNCH_CMD_OVERRIDE (which replaces the whole
# `claude --name ...` part, flags included) is used ONLY for the inheritance test, where a stand-in
# process has to be findable; everything else reads the real command line the script would run.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; RS="$ROOT/scripts/recycle-sibling.sh"; ST="$ROOT/scripts/start-team.sh"
TMP="$(mktemp -d)"; pids=""
trap 'for p in $pids; do kill "$p" 2>/dev/null; done; rm -rf "$TMP"' EXIT
pass=0; fail=0
has() {  # <label> <want substring> <got>
  case "$3" in *"$2"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL $1: want '$2' in: $3" ;; esac
}
hasnt() {  # <label> <unwanted substring> <got>
  case "$3" in *"$2"*) fail=$((fail+1)); echo "FAIL $1: did not want '$2' in: $3" ;; *) pass=$((pass+1)) ;; esac
}
count() {  # <label> <want N> <needle> <got> — occurrences of a fixed string
  local n; n="$(printf '%s\n' "$4" | grep -oF -- "$3" | wc -l | tr -d ' ')"
  if [ "$n" = "$2" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL $1: want $2x '$3', got ${n}x in: $4"; fi
}
rs() { HOME="$TMP" bash "$RS" --dry-run --terminal manual --repo "$ROOT" "$@" 2>&1; }
# Unique names: start-team SKIPS a name that is already running, and a developer running this suite
# is usually inside a session called Orca / Sib1.
st() { HOME="$TMP" bash "$ST" --dry-run --terminal manual --repo "$ROOT" --seat ZzSeat --prefix ZzSib "$@" 2>&1; }

# 1. Default: a model is ALWAYS passed; effort only when given.
out="$(rs ZzNone)"
has "default model flag in the command" '--model opus\[1m\]' "$out"
has "default model named in the dry-run" "model      opus[1m] (default)" "$out"
hasnt "no --effort unless asked" "--effort" "$out"
has "effort line says not passed" "effort     default (not passed)" "$out"

# 2. Explicit: the flags land in the command, after --name, before the prompt.
out="$(rs --model 'sonnet[1m]' --effort high ZzNone)"
has "explicit model + effort in order" '--name ZzNone --model sonnet\[1m\] --effort high /orchestration-kit:orient' "$out"
has "explicit source shown" "model      sonnet[1m] (--model)" "$out"
out="$(rs --model haiku ZzNone)"
has "bare model id (haiku, no [1m])" '--model haiku' "$out"
out="$(rs --model=claude-sonnet-5-5 --effort=max ZzNone)"
has "--flag=value form" '--model claude-sonnet-5-5 --effort max' "$out"
out="$(rs --mode auto --model 'sonnet[1m]' ZzNone)"
has "mode flag and model flag coexist" '--permission-mode auto --model sonnet\[1m\]' "$out"

# A lean-start prompt (`orient --brief <ROW>`) passes launch validation on a POSIX and a WSL backend
# and reaches the command intact.
for b in manual wsl-wt; do
  out="$(HOME="$TMP" bash "$RS" --dry-run --terminal "$b" --repo "$ROOT" --model 'sonnet[1m]' ZzNone "/orchestration-kit:orient --brief ROW-12" 2>&1; echo "rc=$?")"
  has "brief prompt accepted on $b" "orient\\ --brief\\ ROW-12" "$out"
  has "brief prompt exits 0 on $b" "rc=0" "$out"
done

# 3. Refusals: exit 64 like --account, and nothing is printed as a plan.
for bad in 'x;y' 'opus 1m' "o'pus" 'Opus' 'opus[2m]' '$(id)'; do
  out="$(rs --model "$bad" ZzNone; echo "rc=$?")"
  has "model '$bad' refused rc 64" "rc=64" "$out"
  has "model '$bad' says why" "--model must look like" "$out"
  hasnt "model '$bad' prints no command" "claude --name" "$out"
done
for bad in ultra HIGH 'hi gh' 'high;x'; do
  out="$(rs --effort "$bad" ZzNone; echo "rc=$?")"
  has "effort '$bad' refused rc 64" "rc=64" "$out"
  has "effort '$bad' says why" "--effort must be one of" "$out"
done
out="$(st --model 'x;y' --siblings 1; echo "rc=$?")"
has "start-team refuses a bad model rc 64" "rc=64" "$out"
out="$(st --effort ultra --siblings 1; echo "rc=$?")"
has "start-team refuses a bad effort rc 64" "rc=64" "$out"

# 4. Recycle NEVER inherits the old session's model (unlike its account). A stand-in session that is
#    running on haiku is recycled with no flag and must come back on the default, not on haiku.
if command -v pgrep >/dev/null 2>&1; then
  export LAUNCH_CMD_OVERRIDE='bash -c sleep 30;: {name}'
  bash -c 'sleep 30;:' ZzOld --model haiku --effort low & pids="$pids $!"
  sleep 1
  out="$(rs ZzOld)"
  has "the stand-in is found as the old session" "old pids   " "$out"
  hasnt "old pids is not empty" "old pids   none" "$out"
  has "recycled with no flag -> default model" "model      opus[1m] (default)" "$out"
  hasnt "old model not inherited" "haiku" "$out"
  has "recycled with no flag -> effort not passed" "effort     default (not passed)" "$out"
  out="$(rs --model 'sonnet[1m]' ZzOld)"
  has "recycled with --model -> that model" "model      sonnet[1m] (--model)" "$out"
  unset LAUNCH_CMD_OVERRIDE
else
  echo "skip inheritance test: no pgrep"
fi

# 5. start-team: the one --model / --effort reaches EVERY window (seat + siblings).
out="$(st --siblings 2 --model 'sonnet[1m]' --effort low)"
count "start-team: 3 windows carry --model" 3 '--model sonnet\[1m\] --effort low' "$out"
out="$(st --siblings 2)"
count "start-team default: 3 windows carry the default model" 3 '--model opus\[1m\]' "$out"

# 6. Every backend, every quoting family (posix, WSL, cmd.exe, osascript argv, tmux). Forced and
#    unavailable here is fine for --dry-run: the command line is built regardless.
backends="tmux tmux-detached wsl-wt wsl-conhost macos-iterm macos-terminal gitbash-cmd linux-gnome-terminal linux-konsole linux-xfce4-terminal linux-kitty linux-alacritty linux-wezterm linux-foot linux-xterm linux-x-terminal-emulator"
for b in $backends; do
  for tool in rs st; do
    if [ "$tool" = rs ]; then out="$(HOME="$TMP" bash "$RS" --dry-run --terminal "$b" --repo "$ROOT" --model 'sonnet[1m]' --effort high ZzNone 2>&1)"
    else out="$(HOME="$TMP" bash "$ST" --dry-run --terminal "$b" --repo "$ROOT" --seat ZzSeat --prefix ZzSib --siblings 1 --model 'sonnet[1m]' --effort high 2>&1)"; fi
    case "$out" in
      *'--model sonnet\[1m\] --effort high'*|*'--model sonnet[1m] --effort high'*) pass=$((pass+1)) ;;  # posix-quoted | cmd.exe (unquoted)
      *) fail=$((fail+1)); echo "FAIL backend $b ($tool): model/effort missing from the launch command: $out" ;;
    esac
  done
done

# 7. The default model is configurable in the team block; flags override it; a bad block value is
#    ignored with a warning (the same leniency as permission_mode) and the built-in default stands.
R="$TMP/repo"; mkdir -p "$R/docs/orchestration"
printf 'team:\n  seat: Orca\n  model: sonnet[1m]\n  effort: medium\n' > "$R/docs/orchestration/ORCHESTRATION.md"
out="$(HOME="$TMP" bash "$RS" --dry-run --terminal manual --repo "$R" ZzNone 2>&1)"
has "team block model" "model      sonnet[1m] (team block)" "$out"
has "team block effort" "effort     medium (team block)" "$out"
has "team block reaches the command" '--model sonnet\[1m\] --effort medium' "$out"
out="$(HOME="$TMP" bash "$RS" --dry-run --terminal manual --repo "$R" --model haiku ZzNone 2>&1)"
has "flag beats the team block" "model      haiku (--model)" "$out"
printf 'team:\n  model: not;a;model\n  effort: ultra\n' > "$R/docs/orchestration/ORCHESTRATION.md"
out="$(HOME="$TMP" bash "$RS" --dry-run --terminal manual --repo "$R" ZzNone 2>&1)"
has "bad team model warns" "team block: model 'not;a;model' is not valid" "$out"
has "bad team model falls back to the default" "model      opus[1m] (default)" "$out"
has "bad team effort warns" "team block: effort 'ultra' is not valid" "$out"

echo "lean-launch: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
