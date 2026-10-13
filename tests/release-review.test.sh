#!/usr/bin/env bash
# Tests for release-review: lock.sh (lock and check the release tests) and the text pins that wire the
# lock check, the decisions log and the decision check into the other skills.
# Run: bash tests/release-review.test.sh   (temp git repos only; no network)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; LOCK="$ROOT/skills/release-review/lock.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok() { pass=$((pass+1)); }
no() { fail=$((fail+1)); echo "FAIL $1"; }
has() { case "$3" in *"$2"*) ok ;; *) no "$1: want '$2' in: $3" ;; esac; }
rc_is() { [ "$2" = "$3" ] && ok || no "$1: want exit $2, got $3"; }
pin() { grep -qF -- "$3" "$ROOT/$2" && ok || no "$1: '$3' not in $2"; }

R="$TMP/repo"; mkdir -p "$R/tests/release" "$R/src"
git -C "$R" init -q; git -C "$R" config user.email t@t; git -C "$R" config user.name t
printf 'assert 1\n' > "$R/tests/release/a.test.mjs"; printf 'assert 2\n' > "$R/tests/release/b.test.mjs"; printf 'x\n' > "$R/src/x.js"
git -C "$R" add -A; git -C "$R" commit -qm base
M="$TMP/LOCKED.sha256"
lock() { (cd "$R" && MODE=lock DIR=tests/release MANIFEST="$M" bash "$LOCK" 2>&1); }
check() { (cd "$R" && MODE=check MANIFEST="$M" bash "$LOCK" 2>&1); }

# 1. Lock, then check on an untouched tree: exit 0.
out="$(lock)"; rc=$?; rc_is "lock exit" 0 "$rc"; has "lock count" "locked 2 file(s)" "$out"
has "manifest header" "# dir: tests/release" "$(head -1 "$M")"
out="$(check)"; rc=$?; rc_is "clean check" 0 "$rc"; has "clean message" "locked tests unchanged (2 file(s)" "$out"
# 2. A change outside the dir is not the lock's business.
printf 'y\n' >> "$R/src/x.js"; out="$(check)"; rc=$?; rc_is "edit outside dir" 0 "$rc"
# 3. A changed locked test (uncommitted, then committed) fails.
printf 'assert 3\n' > "$R/tests/release/a.test.mjs"; out="$(check)"; rc=$?
rc_is "changed test" 1 "$rc"; has "changed line" "CHANGED tests/release/a.test.mjs" "$out"
git -C "$R" commit -qam "weaken"; out="$(check)"; rc=$?; rc_is "changed + committed" 1 "$rc"
git -C "$R" checkout -q HEAD~1 -- tests/release/a.test.mjs; out="$(check)"; rc=$?; rc_is "restored" 0 "$rc"
git -C "$R" commit -qam "restore"
# 4. A deleted locked test fails.
rm "$R/tests/release/b.test.mjs"; out="$(check)"; rc=$?
rc_is "missing test" 1 "$rc"; has "missing line" "MISSING tests/release/b.test.mjs" "$out"
git -C "$R" checkout -q -- tests/release/b.test.mjs
# 5. A new file under the dir (untracked or tracked) fails: the set is locked, not just the bytes.
printf 'skip all\n' > "$R/tests/release/c.test.mjs"; out="$(check)"; rc=$?
rc_is "added untracked" 1 "$rc"; has "added line" "ADDED   tests/release/c.test.mjs" "$out"
git -C "$R" add tests/release/c.test.mjs; out="$(check)"; rc=$?; rc_is "added tracked" 1 "$rc"
git -C "$R" rm -q --cached tests/release/c.test.mjs
# 6. Lock refuses untracked tests (commit first) and an empty dir.
out="$(lock)"; rc=$?; rc_is "lock with untracked" 1 "$rc"; has "untracked named" "c.test.mjs" "$out"
rm "$R/tests/release/c.test.mjs"
out="$(cd "$R" && MODE=lock DIR=tests/none MANIFEST="$TMP/x" bash "$LOCK" 2>&1)"; rc=$?; rc_is "empty dir" 1 "$rc"
# 7. TREE= checks another checkout (a builder's worktree) against the same manifest.
git -C "$R" worktree add -q "$TMP/wt" -b builder
out="$(MODE=check MANIFEST="$M" TREE="$TMP/wt" bash "$LOCK" 2>&1)"; rc=$?; rc_is "worktree clean" 0 "$rc"
printf 'assert 0\n' > "$TMP/wt/tests/release/b.test.mjs"
out="$(MODE=check MANIFEST="$M" TREE="$TMP/wt" bash "$LOCK" 2>&1)"; rc=$?; rc_is "worktree changed" 1 "$rc"
has "worktree changed line" "CHANGED tests/release/b.test.mjs" "$out"
# 8. Usage errors exit 2.
out="$(MODE=check bash "$LOCK" 2>&1)"; rc=$?; rc_is "no manifest var" 2 "$rc"
out="$(MODE=bogus MANIFEST="$M" bash "$LOCK" 2>&1)"; rc=$?; rc_is "bad mode" 2 "$rc"
out="$(cd "$R" && MODE=check MANIFEST="$TMP/absent" bash "$LOCK" 2>&1)"; rc=$?; rc_is "absent manifest" 2 "$rc"

# 9. Pins: the other skills and the templates carry the wiring.
pin "reconcile refuses on the lock check" skills/reconcile/SKILL.md "refuse the row on any non-zero exit"
pin "orchestrate records decisions" skills/orchestrate/SKILL.md "**Record the human's decisions as they are made.**"
pin "orchestrate decision check cadence" skills/orchestrate/SKILL.md "every 10 closed rows or 7 days, whichever comes first"
pin "kit-init copies the decisions log" skills/kit-init/SKILL.md "templates/DECISIONS.md:docs/orchestration/DECISIONS.md"
pin "overlay Release section" templates/ORCHESTRATION.md "release tests:  tests/release/"
pin "checklist never blocks" skills/release-review/SKILL.md "**The release never waits on it**"
pin "questions as plain text" skills/release-review/SKILL.md "Never a pop-up menu."
grep -q 'AskUserQuestion' "$ROOT/skills/release-review/SKILL.md" && no "release-review names AskUserQuestion" || ok

echo "release-review: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
