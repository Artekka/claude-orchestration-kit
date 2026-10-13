#!/usr/bin/env bash
# Tests for repo paths with a space (or ; " ') on WSL: instead of refusing, the launcher opens the tab
# through a safe-name symlink and the tab's command `cd -P .`s into the real repo first.
# Run: bash tests/wsl-spaced-repo.test.sh   (dry runs only, in a sandbox like tests/lean-launch.test.sh)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "$ROOT" in *[[:space:]]*) echo "wsl-spaced-repo: SKIP (the kit's path has a space: $ROOT)"; exit 0 ;; esac
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
has() { case "$3" in *"$2"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL $1: want '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) fail=$((fail+1)); echo "FAIL $1: did not want '$2' in: $3" ;; *) pass=$((pass+1)) ;; esac; }
FAKE_WT="$TMP/fake-wt.exe"; : > "$FAKE_WT"
STUBS="$TMP/stubs"; mkdir -p "$STUBS"
for t in wt.exe powershell.exe cmd.exe osascript tmux; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\nexit 99\n' "$t" "$TMP/REAL-TOOL-CALLED" > "$STUBS/$t"; chmod +x "$STUBS/$t"
done
lrun() { env HOME="$TMP" WSL_DISTRO_NAME=TestDistro WSL_INTEROP= TMUX= "WT_EXE=$FAKE_WT" "PATH=$STUBS:$PATH" "$@"; }

# A repo whose path has a space, with the kit's scripts copied into it (as kit-init does).
R="$TMP/projects/My Band"; mkdir -p "$R"; git -C "$R" init -q; cp -R "$ROOT/scripts" "$R/scripts"
LINKS="$TMP/.orchestration-kit/runtime/repos"

# 1. start-team: no refusal; the tab opens through the link and lands in the real path.
out="$(lrun bash "$R/scripts/start-team.sh" --dry-run --terminal wsl-wt --repo "$R" --seat ZzSeat --siblings 1 --prefix ZzSib 2>&1; echo "rc=$?")"
has "spaced repo: exit 0" "rc=0" "$out"
hasnt "spaced repo: not refused" "must not contain spaces" "$out"
link="$(ls -d "$LINKS"/My-Band-* 2>/dev/null | head -1)"
if [ -n "$link" ] && [ -L "$link" ] && [ "$(readlink "$link")" = "$R" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL the link $LINKS/My-Band-* -> $R was not made (got '$link')"; fi
has "command enters through the link" "cd $link && cd -P . && " "$out"
has "wrapper reached through the link" "bash $link/scripts/sibling-shell.sh ZzSeat" "$out"
hasnt "no raw spaced path in the command" "My\\ Band" "$out"
has "--cd is the link" "--cd $link" "$out"

# 2. Re-running reuses the same link (no pile-up).
lrun bash "$R/scripts/start-team.sh" --dry-run --terminal wsl-wt --repo "$R" --seat ZzSeat --siblings 1 --prefix ZzSib >/dev/null 2>&1
n="$(ls -d "$LINKS"/My-Band-* | wc -l | tr -d ' ')"; [ "$n" = 1 ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL want 1 link after a re-run, got $n"; }

# 3. The link really lands in the real repo: cd link && cd -P . prints the real path.
got="$(cd "$link" && cd -P . && pwd)"; [ "$got" = "$R" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL cd -P through the link gave '$got', want '$R'"; }

# 4. The conhost backend uses the link too.
out="$(lrun bash "$R/scripts/start-team.sh" --dry-run --terminal wsl-conhost --repo "$R" --seat ZzSeat --siblings 1 --prefix ZzSib 2>&1; echo "rc=$?")"
has "conhost: exit 0" "rc=0" "$out"
has "conhost: --cd is the link" "--cd\\ $link" "$out"

# 5. A path without a space is unchanged: no link, no cd -P.
P="$TMP/projects/plain"; mkdir -p "$P"; git -C "$P" init -q
out="$(lrun bash "$ROOT/scripts/start-team.sh" --dry-run --terminal wsl-wt --repo "$P" --seat ZzSeat --siblings 1 --prefix ZzSib 2>&1)"
has "plain repo: cd to the repo itself" "cd $P && " "$out"
hasnt "plain repo: no cd -P" "cd -P ." "$out"

# 6. Off WSL nothing changes (tmux quotes the spaced path itself).
out="$(lrun bash "$R/scripts/start-team.sh" --dry-run --terminal tmux --repo "$R" --seat ZzSeat --siblings 1 --prefix ZzSib 2>&1)"
hasnt "tmux: no link used" "runtime/repos" "$out"

if [ -e "$TMP/REAL-TOOL-CALLED" ]; then fail=$((fail+1)); echo "FAIL a real-tool stand-in was executed: $(cat "$TMP/REAL-TOOL-CALLED")"; else pass=$((pass+1)); fi
echo "wsl-spaced-repo: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
