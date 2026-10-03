#!/usr/bin/env bash
# Tests for scripts/bootstrap.sh: dry-run touches nothing, a second run is a no-op, live files
# are never overwritten. HOME is sandboxed so the memory-starter step writes into the temp dir.
# Run: bash tests/bootstrap.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; BS="$ROOT/scripts/bootstrap.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; mkdir -p "$HOME"
pass=0; fail=0
ok()   { pass=$((pass+1)); }
bad()  { fail=$((fail+1)); echo "FAIL $*"; }
snap() { (cd "$1" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | xargs cksum); }
P="$TMP/proj/app"   # parent does not exist yet: the bare-directory case

out="$(bash "$BS" "$P" --dry-run 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok || bad "dry-run exit $rc"
[ ! -e "$TMP/proj" ] && ok || bad "dry-run created the target"
[ ! -e "$HOME/.claude" ] && ok || bad "dry-run created the memory dir"
echo "$out" | grep -q '^\[bootstrap\] CREATE docs/orchestration/AGENT_BOARD.md' && ok || bad "dry-run did not list the board"
echo "$out" | grep -q 'DONE' && ok || bad "dry-run plan truncated (no DONE line)"

out="$(bash "$BS" "$P" 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok || bad "first run exit $rc: $out"
for f in docs/orchestration/AGENT_BOARD.md docs/orchestration/ORCHESTRATION.md CLAUDE.md docs/AI_CONTEXT.md \
         docs/timeline/build-log.md scripts/ctx-fill.py scripts/statusline-ctx.sh .claude/agents/verifier.md \
         .claude/skills/orchestrate/SKILL.md .claude/skills/falsify/SKILL.md \
         docs/orchestration/briefs/README.md docs/orchestration/briefs/_TEMPLATE.md \
         docs/orchestration/CLAUDE-slimness.md; do
  [ -f "$P/$f" ] && ok || bad "first run did not create $f"
done
# F6 (ORCA106-5b): the CLAUDE.md section tells every adopter to keep the file slim and points at the
# slimness note, so the note must exist at the path the section names IN THE ADOPTING PROJECT.
ptr="$(grep -o 'docs/orchestration/CLAUDE-slimness.md' "$P/CLAUDE.md" | head -1)"
[ "$ptr" = docs/orchestration/CLAUDE-slimness.md ] && ok || bad "installed CLAUDE.md does not point at docs/orchestration/CLAUDE-slimness.md"
grep -q 'templates/CLAUDE-slimness.md' "$P/CLAUDE.md" && bad "installed CLAUDE.md points at the kit-only path templates/CLAUDE-slimness.md" || ok
# a dry run lists it, and kit-init's copy block installs it too
bash "$BS" "$TMP/dry2" --dry-run 2>&1 | grep -q '^\[bootstrap\] CREATE docs/orchestration/CLAUDE-slimness.md' && ok || bad "dry-run did not list CLAUDE-slimness.md"
grep -q 'CLAUDE-slimness.md' "$ROOT/skills/kit-init/SKILL.md" && ok || bad "kit-init does not install CLAUDE-slimness.md"
grep -q 'put "$K/templates/CLAUDE-slimness.md" *docs/orchestration/CLAUDE-slimness.md' "$ROOT/skills/kit-init/SKILL.md" && ok || bad "kit-init put line for CLAUDE-slimness.md missing or wrong destination"
# a live copy is never overwritten
echo "# my slimness note" > "$P/docs/orchestration/CLAUDE-slimness.md"
bash "$BS" "$P" >/dev/null 2>&1
[ "$(cat "$P/docs/orchestration/CLAUDE-slimness.md")" = "# my slimness note" ] && ok || bad "a live CLAUDE-slimness.md was overwritten"
cp "$ROOT/templates/CLAUDE-slimness.md" "$P/docs/orchestration/CLAUDE-slimness.md"
[ -x "$P/scripts/start-team.sh" ] && ok || bad "start-team.sh not executable"
[ -d "$P/.git" ] && ok || bad "no git repo"
ls "$HOME"/.claude/projects/*/memory/MEMORY.md >/dev/null 2>&1 && ok || bad "memory starter index not written"
[ ! -e "$P/.claude/agents/architect.md" ] && ok || bad "team agents installed without --with-team-agents"

before="$(snap "$P")"
out="$(bash "$BS" "$P" 2>&1)"; rc=$?
[ $rc -eq 0 ] && ok || bad "second run exit $rc"
echo "$out" | grep -q 'CREATE' && bad "second run created something: $(echo "$out" | grep CREATE | head -3)" || ok
[ "$before" = "$(snap "$P")" ] && ok || bad "second run changed files"

echo "# my live board" > "$P/docs/orchestration/AGENT_BOARD.md"
bash "$BS" "$P" >/dev/null 2>&1
[ "$(cat "$P/docs/orchestration/AGENT_BOARD.md")" = "# my live board" ] && ok || bad "a live file was overwritten"

before="$(snap "$P")"
bash "$BS" "$P" --dry-run --with-team-agents >/dev/null 2>&1
[ "$before" = "$(snap "$P")" ] && ok || bad "dry-run on an existing project changed files"

bash "$BS" "$P" --bogus >/dev/null 2>&1; rc=$?
[ $rc -eq 2 ] && ok || bad "unknown flag exit $rc (want 2)"

echo "bootstrap: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
