#!/usr/bin/env bash
# lock.sh — lock a release review's tests, and check that nothing changed them (orchestration-kit).
#
# NAMED variables only (the skill loader replaces positional tokens in SKILL.md text):
#   MODE=lock  DIR=<tests dir> MANIFEST=<file> [TREE=<checkout>]
#       Writes MANIFEST: a `# dir: <DIR>` header, then `<sha256>  <path>` for every file git tracks
#       under DIR in TREE (default .). Refuses (exit 1) when DIR holds no tracked file, or an
#       untracked file (commit the tests first: an untracked test is not a locked test).
#   MODE=check MANIFEST=<file> [TREE=<checkout>]
#       Exit 0 when every file in MANIFEST is byte-identical in TREE AND no tracked file was added
#       under the manifest's dir. Exit 1 prints one line per difference: CHANGED / MISSING / ADDED.
# Exit 2 = usage. No network, no writes except MANIFEST in lock mode. Needs bash, git, sha256sum
# (or `shasum -a 256` on macOS).
set -uo pipefail

usage() { echo "usage: MODE=lock DIR=<dir> MANIFEST=<file> [TREE=<checkout>] bash lock.sh | MODE=check MANIFEST=<file> [TREE=<checkout>] bash lock.sh" >&2; exit 2; }
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

TREE="${TREE:-.}"
[ -n "${MANIFEST:-}" ] || usage
git -C "$TREE" rev-parse --show-toplevel >/dev/null 2>&1 || { echo "lock.sh: TREE '$TREE' is not a git checkout" >&2; exit 2; }
TOP="$(git -C "$TREE" rev-parse --show-toplevel)"

case "${MODE:-}" in
  lock)
    [ -n "${DIR:-}" ] || usage
    d="${DIR%/}"
    untracked="$(git -C "$TOP" ls-files --others --exclude-standard -- "$d")"
    if [ -n "$untracked" ]; then
      echo "lock.sh: untracked files under $d — commit the tests first:" >&2; printf '  %s\n' $untracked >&2; exit 1
    fi
    files="$(git -C "$TOP" ls-files -- "$d")"
    [ -n "$files" ] || { echo "lock.sh: no tracked file under $d — nothing to lock" >&2; exit 1; }
    tmp="$MANIFEST.tmp.$$"
    { echo "# dir: $d"; (cd "$TOP" && printf '%s\n' "$files" | while IFS= read -r f; do sha "$f"; done); } > "$tmp" && mv "$tmp" "$MANIFEST"
    echo "locked $(printf '%s\n' "$files" | wc -l | tr -d ' ') file(s) under $d -> $MANIFEST"
    ;;
  check)
    [ -f "$MANIFEST" ] || { echo "lock.sh: no manifest at $MANIFEST" >&2; exit 2; }
    d="$(sed -n '1s/^# dir: //p' "$MANIFEST")"
    [ -n "$d" ] || { echo "lock.sh: $MANIFEST has no '# dir:' header" >&2; exit 2; }
    bad=0
    while IFS= read -r line; do
      case "$line" in '#'*|'') continue ;; esac
      want="${line%%  *}"; f="${line#*  }"
      if [ ! -f "$TOP/$f" ]; then echo "MISSING $f"; bad=1; continue; fi
      got="$(cd "$TOP" && sha "$f")"; got="${got%%  *}"
      [ "$got" = "$want" ] || { echo "CHANGED $f"; bad=1; }
    done < "$MANIFEST"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      grep -qF -- "  $f" "$MANIFEST" || { echo "ADDED   $f"; bad=1; }
    done < <(git -C "$TOP" ls-files --cached --others --exclude-standard -- "$d")
    if [ "$bad" -eq 0 ]; then echo "locked tests unchanged ($(grep -vc '^#' "$MANIFEST") file(s) under $d)"; fi
    exit "$bad"
    ;;
  *) usage ;;
esac
