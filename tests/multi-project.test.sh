#!/usr/bin/env bash
# Tests for several projects' teams on one machine: a session is placed by the repo it works in, so another
# project's session with the same name is never skipped as "ours", drawn from a name pool, or recycled.
# Run: bash tests/multi-project.test.sh   (dry runs and stand-in processes only)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; ST="$ROOT/scripts/start-team.sh"; RS="$ROOT/scripts/recycle-sibling.sh"
case "$ROOT" in *[[:space:]]*) echo "multi-project: SKIP (the kit's path has a space: $ROOT)"; exit 0 ;; esac
[ -r /proc/self/cwd ] || { echo "multi-project: SKIP (no /proc: sessions cannot be placed by repo here)"; exit 0; }
TMP="$(mktemp -d)"; pids=""
trap 'for p in $pids; do kill "$p" 2>/dev/null; done; rm -rf "$TMP"' EXIT
pass=0; fail=0
has() { case "$3" in *"$2"*) pass=$((pass+1)) ;; *) fail=$((fail+1)); echo "FAIL $1: want '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) fail=$((fail+1)); echo "FAIL $1: did not want '$2' in: $3" ;; *) pass=$((pass+1)) ;; esac; }
STUBS="$TMP/stubs"; mkdir -p "$STUBS"
for t in wt.exe powershell.exe cmd.exe osascript tmux; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\nexit 99\n' "$t" "$TMP/REAL-TOOL-CALLED" > "$STUBS/$t"; chmod +x "$STUBS/$t"
done
lrun() { env HOME="$TMP" WSL_DISTRO_NAME= WSL_INTEROP= TMUX= "PATH=$STUBS:$PATH" "$@"; }
A="$TMP/projA"; B="$TMP/projB"
for r in "$A" "$B"; do mkdir -p "$r/docs/orchestration"; : > "$r/docs/orchestration/ORCHESTRATION.md"; git -C "$r" init -q; git -C "$r" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base; done
# A stand-in session named $1, working in repo $2 (or in a linked worktree of it when $3 is given).
standin() {
  local dir="$2"
  if [ -n "${3:-}" ]; then git -C "$2" worktree add -q "$3" -b "wt-$1" 2>/dev/null; dir="$3"; fi
  (cd "$dir" && exec -a "claude --name $1" sleep 60) & pids="$pids $!"
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -f "^claude --name $1( |\$)" >/dev/null && break; sleep 0.2; done
}
standin ZzJup "$B"
standin ZzMars "$B"
standin ZzVenus "$A" "$TMP/projA-wt"   # project A's own sibling, inside its worktree

# 1. The seat's name is held by project B: starting A's team refuses and says how to name it.
out="$(lrun bash "$ST" --dry-run --terminal manual --repo "$A" --seat ZzJup --siblings 0 2>&1; echo "rc=$?")"
has "seat held elsewhere: refused" "rc=64" "$out"
has "seat held elsewhere: names the other project" "$B" "$out"
has "seat held elsewhere: suggests a per-project seat name" "ZzJup-projA" "$out"
# 2. The same name in THIS project is still skipped as running (the old behavior).
out="$(lrun bash "$ST" --dry-run --terminal manual --repo "$B" --seat ZzJup --siblings 0 2>&1; echo "rc=$?")"
has "seat running here: skipped" "SKIP   ZzJup" "$out"
has "seat running here: exit 0" "rc=0" "$out"
# 3. A pool name another project holds is never drawn; this project's own (in its worktree) is kept.
out="$(TEAM_NAMES_SHUFFLE=0 lrun bash "$ST" --dry-run --terminal manual --repo "$A" --seat ZzSeatA --siblings 2 --names ZzMars,ZzVenus,ZzCeres 2>&1; echo "rc=$?")"
hasnt "pool: B's Mars not used" "ZzMars" "$(printf '%s\n' "$out" | grep -E '^(LAUNCH|SKIP)')"
has "pool: A's own Venus kept (found through its worktree)" "SKIP   ZzVenus" "$out"
has "pool: a free name drawn" "LAUNCH ZzCeres" "$out"
# 3b. A same-named session working outside any kit project (a plain checkout) still counts as here.
P="$TMP/plain"; mkdir -p "$P"; git -C "$P" init -q; standin ZzLoose "$P"
out="$(lrun bash "$ST" --dry-run --terminal manual --repo "$A" --seat ZzLoose --siblings 0 2>&1; echo "rc=$?")"
has "outside any kit project: skipped as before" "SKIP   ZzLoose" "$out"
# 4. recycle-sibling never touches another project's session of the same name.
out="$(lrun bash "$RS" --dry-run --terminal manual --repo "$A" ZzMars --model haiku 2>&1; echo "rc=$?")"
has "recycle elsewhere: refused" "rc=64" "$out"
has "recycle elsewhere: says why" "belongs to another project" "$out"
out="$(lrun bash "$RS" --dry-run --terminal manual --repo "$B" ZzMars --model haiku 2>&1; echo "rc=$?")"
hasnt "recycle here: not refused" "belongs to another project" "$out"

if [ -e "$TMP/REAL-TOOL-CALLED" ]; then fail=$((fail+1)); echo "FAIL a real-tool stand-in was executed: $(cat "$TMP/REAL-TOOL-CALLED")"; else pass=$((pass+1)); fi
echo "multi-project: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
