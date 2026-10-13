#!/usr/bin/env bash
# audit.sh (orchestration-kit, audit-train): sweep the first-parent commits BASE..TIP of a train, oldest first.
# Run as:  BASE=<train base> TIP=<train tip> [APPROVED=<file of approved rider SHAs, one per line>] bash audit.sh
# (in the train's repo). Named variables only: the skill loader eats positional parameters.
#   MERGE <sha> p2=<rider> [approved=YES|NO] mt_rc=<0 clean|1 conflict> tree_eq=<YES|NO> :: <subject>
#     tree_eq compares the landed tree with a fresh `git merge-tree --write-tree P1 P2`; on NO the differing
#     paths follow as "resolved:" lines, and they must be exactly the declared hand resolutions.
#   SINGLE <sha> :: <subject>, with its diffstat (a regen, a seal note, a seat-ordered flip: must be declared)
BASE=${BASE:?set BASE=<train base sha>}; TIP=${TIP:?set TIP=<train tip sha>}
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not inside a git repo" >&2; exit 2; }
for v in "$BASE" "$TIP"; do git rev-parse -q --verify "$v^{commit}" >/dev/null || { echo "$v is not a commit here" >&2; exit 2; }; done
for c in $(git rev-list --first-parent --reverse "$BASE..$TIP"); do
  read -r -a ps <<< "$(git rev-list --parents -n1 "$c")"; subj=$(git log -1 --format=%s "$c")
  if [ "${#ps[@]}" -eq 3 ]; then
    p1=${ps[1]}; p2=${ps[2]}; cl=""
    if [ -n "${APPROVED:-}" ]; then
      cl=" approved=NO"
      while read -r s _; do   # first word of each line = a SHA (short is fine); the rest is a note
        [ -n "$s" ] && [ "$(git rev-parse -q --verify "$s^{commit}" 2>/dev/null)" = "$p2" ] && { cl=" approved=YES"; break; }
      done < "$APPROVED"
    fi
    # keep the exit code: never `$(... | head)` here, a pipe inside $() reports head's status
    out=$(git merge-tree --write-tree "$p1" "$p2" 2>/dev/null); rc=$?
    mt=$(printf '%s\n' "$out" | head -1); act=$(git rev-parse "$c^{tree}")
    echo "MERGE ${c:0:9} p2=${p2:0:9}$cl mt_rc=$rc tree_eq=$([ "$mt" = "$act" ] && echo YES || echo NO) :: $subj"
    [ "$mt" != "$act" ] && git diff --name-only "$mt" "$act" | sed 's/^/    resolved: /'
  elif [ "${#ps[@]}" -eq 2 ]; then
    echo "SINGLE ${c:0:9} :: $subj"; git diff --stat=200 "${ps[1]}" "$c" | sed 's/^/    /'
  else
    echo "OCTOPUS ${c:0:9} parents=$(( ${#ps[@]} - 1 )) :: $subj   (audit by hand)"
  fi
done
