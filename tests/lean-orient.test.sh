#!/usr/bin/env bash
# Tests for the lean `/orchestration-kit:orient --brief <ROW>` steps and the model-per-lane / recycle
# wording (ORCA106-5b F3-F5). The lean steps are COMMANDS in a table in skills/orient/SKILL.md; this
# suite EXTRACTS them from the skill file and runs them against a real fixture, so editing the skill to
# something broken turns it red (a copy of the command in this file would stay green).
# Run: bash tests/lean-orient.test.sh      (needs bash, git, awk, python3; no network)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/orient/SKILL.md"; ORCH="$ROOT/skills/orchestrate/SKILL.md"
GS="$ROOT/docs/GETTING-STARTED.md"; BRIEF_T="$ROOT/templates/briefs/_TEMPLATE.md"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL $*"; }
has()   { case "$3" in *"$2"*) ok ;; *) bad "$1: want '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1: did not want '$2' in: $3" ;; *) ok ;; esac; }

# The backticked commands of one row of the lean-mode table, `\|` unescaped back to `|`, one per line.
cmds() {  # <step number>
  python3 - "$SKILL" "$1" <<'PY'
import re, sys
skill, step = sys.argv[1], sys.argv[2]
for line in open(skill, encoding="utf8"):
    if line.startswith(f"| {step} |"):
        for m in re.finditer(r"`([^`]+)`", line):
            print(m.group(1).replace("\\|", "|"))
        break
PY
}
first_with() {  # <prefix> — first line of stdin that starts with the prefix
  local p="$1" l
  while IFS= read -r l; do case "$l" in "$p"*) printf '%s\n' "$l"; return 0 ;; esac; done; return 1
}

# ---- fixture: bare origin, a seat clone that pushes, and a builder clone that is STALE ----------
ORIGIN="$TMP/origin.git"; SEAT="$TMP/seat"; BUILDER="$TMP/builder"
git init -q --bare -b main "$ORIGIN"
git clone -q "$ORIGIN" "$SEAT" 2>/dev/null
mkdir -p "$SEAT/docs/orchestration/briefs"
# A board shaped like a live one: an archive table, rules, `---` rulers, THEN the banner, THEN an
# older banner header that is superseded.
cat > "$SEAT/docs/orchestration/AGENT_BOARD.md" <<'BOARD'
# Agent Orchestration Board

## Archives
| archive | covers |
|---|---|
| a | b |

---

## Protocol
- rule one
---
## 🎛 ORCHESTRATOR ACTIVE — **era-9 · Zed `[abc123]`** · prefix `Z9-`
- row Z9-1 → Sib1
## (era-8 header, superseded) ORCHESTRATOR ACTIVE — **era-8 · Old `[000000]`**
- stale row
BOARD
(cd "$SEAT" && git add docs && git commit -q -m board && git push -q origin HEAD:main)
# The builder clones NOW, before the brief exists: its checkout is the stale one.
git clone -q "$ORIGIN" "$BUILDER" 2>/dev/null
printf '# Z9-1 — the brief\nSeat: Zed [abc123]\n' > "$SEAT/docs/orchestration/briefs/Z9-1.md"
(cd "$SEAT" && git add docs && git commit -q -m brief && git push -q origin HEAD:main)
run() { (cd "$BUILDER" && bash -c "$1" 2>"$TMP/err"); }

# ---- F3 step 1: the brief comes from origin (fetch with one retry, then `git show origin/main:`) ----
run "cat docs/orchestration/briefs/Z9-1.md" >/dev/null 2>&1 && bad "positive control: a plain cat of the stale checkout must NOT see the pushed brief" || ok
step1="$(cmds 1)"
fetch="$(printf '%s\n' "$step1" | first_with 'git fetch')"
show="$(printf '%s\n' "$step1" | first_with 'git show origin/main:docs/orchestration/briefs/')"
[ -n "$fetch" ] && ok || bad "step 1 has no 'git fetch' command: $step1"
[ -n "$show" ] && ok || bad "step 1 has no 'git show origin/main:docs/orchestration/briefs/' command: $step1"
has "step 1 retries the fetch once" "|| { sleep 2; git fetch origin; }" "$fetch"
if [ -n "$fetch" ] && [ -n "$show" ]; then
  out="$(run "$fetch
${show//<ROW>/Z9-1}")"
  [ "$out" = "$(printf '# Z9-1 — the brief\nSeat: Zed [abc123]')" ] && ok || bad "step 1 commands did not print the pushed brief: $out"
  hasnt "step 1 fetch is clean" "fatal" "$(cat "$TMP/err")"
fi
row1="$(grep '^| 1 |' "$SKILL" || true)"
has "step 1 falls back to the working tree" 'cat docs/orchestration/briefs/<ROW>.md' "$row1"
has "step 1 falls back to the seat" "seat" "$row1"

# ---- F3 step 2: the board extraction is anchored on the banner, not on the first `---` -----------
old="$(run "git fetch -q origin && git show origin/main:docs/orchestration/AGENT_BOARD.md | sed -n '1,/^---\$/p' | head -60")"
hasnt "positive control: the OLD 'first 60 lines up to the first ---' shows NO banner on this board" "ORCHESTRATOR ACTIVE" "$old"
board="$(cmds 2 | first_with 'git show origin/main:docs/orchestration/AGENT_BOARD.md')"
[ -n "$board" ] && ok || bad "step 2 has no board-extraction command: $(cmds 2)"
if [ -n "$board" ]; then
  out="$(run "git fetch -q origin
$board")"
  has "step 2 prints the CURRENT banner" 'ORCHESTRATOR ACTIVE — **era-9 · Zed `[abc123]`**' "$out"
  has "step 2 prints the banner's rows" "row Z9-1 → Sib1" "$out"
  hasnt "step 2 stops before the superseded header" "superseded" "$out"
  hasnt "step 2 stops before the superseded rows" "stale row" "$out"
  [ "$(printf '%s\n' "$out" | wc -l)" -le 60 ] && ok || bad "step 2 prints more than 60 lines"
  # No banner on the board prints nothing (the builder is told: no seat).
  pipeline="${board#git show origin/main:docs/orchestration/AGENT_BOARD.md | }"
  none="$(run "git show origin/main:docs/orchestration/AGENT_BOARD.md | sed '/ORCHESTRATOR ACTIVE/d' | $pipeline")"
  [ -z "$none" ] && ok || bad "a board without a banner must print nothing: $none"
fi

# ---- F3: READY names the seat + era the builder saw ---------------------------------------------
readies="$(grep '^READY <PREFIX>' "$SKILL" || true)"
[ -n "$readies" ] && ok || bad "no READY format line found in the orient skill"
while IFS= read -r r; do
  [ -z "$r" ] && continue
  has "READY format names the seat + era" 'saw <seat Name [ref]> era-<N>' "$r"
done <<EOF
$readies
EOF
# The other copies of the READY format (the board template the seat reads, the orchestrate skill's
# inline format) must agree with the skill, or a seat copies a stale one.
has "board template READY format names the seat + era" 'saw <seat Name [ref]> era-<N>' "$(grep '^READY <PREFIX>' "$ROOT/templates/AGENT_BOARD.md")"
has "board template READY format carries model + marks" 'model <id> · fill <current> · marks <prompt>/<handover>' "$(grep '^READY <PREFIX>' "$ROOT/templates/AGENT_BOARD.md")"
has "orchestrate READY format names the seat + era" 'saw <seat Name [ref]> era-<N>' "$(grep 'Wait for \*\*READY\*\*' "$ORCH")"
has "brief template names the seat" "| seat |" "$(cat "$BRIEF_T")"

# ---- F4: board/log/fact-writing lanes sit on the MID model, never the small one ------------------
table_rows() {  # <file> <heading regex> — the `|` rows under the heading, up to the next heading
  awk -v h="$2" '$0 ~ h {on=1; next} on && /^#/ {exit} on && /^\|/' "$1"
}
for spec in "$ORCH|^## 3a" "$GS|^### Model per lane"; do
  f="${spec%%|*}"; h="${spec#*|}"; t="$(table_rows "$f" "$h")"; n="$(basename "$(dirname "$f")")/$(basename "$f")"
  [ -n "$t" ] && ok || bad "$n: no model table under '$h'"
  fact_row="$(printf '%s\n' "$t" | grep -i 'board' | grep -i 'log' || true)"
  [ -n "$fact_row" ] && ok || bad "$n: no row for board/log lanes"
  has "$n: board/log lane is on sonnet[1m]" 'sonnet[1m]' "$fact_row"
  hasnt "$n: board/log lane is never on haiku as its model" '| `haiku`' "$fact_row"
  small="$(printf '%s\n' "$t" | grep '`haiku`' || true)"
  [ -n "$small" ] && ok || bad "$n: no haiku row"
  hasnt "$n: the haiku row does not take board/log edits" "board" "$small"
  hasnt "$n: the haiku row does not take docs/log edits" "Docs" "$small"
  case "$small" in *[Ff]acts*|*"never writes"*|*fabricat*|*invent*) ok ;; *) bad "$n: the haiku row must say the small model never writes facts: $small" ;; esac
done
has "orchestrate keeps the 'small model never writes facts' rule" "The small model never writes facts" "$(cat "$ORCH")"

# ---- F5: nowhere is a user told to bare `/clear` to recycle ---------------------------------------
# A bare /clear keeps the terminal's OLD model. Every line that mentions /clear must either be a
# non-recycling mention (allow-list below) or name the explicit relaunch: `--model` or `/model` first.
allow='uptime survives|evaporate on|destroys unpersisted|Retro-before-clear|retro-before-clear|Never pre-announce'
for f in skills/orchestrate/SKILL.md docs/GETTING-STARTED.md templates/CLAUDE-section.md docs/LESSONS.md \
         docs/EXAMPLE-SESSION.md docs/MULTI-ACCOUNT.md docs/GLOSSARY.md README.md skills/orient/SKILL.md \
         skills/retro/SKILL.md skills/bootstrap-project/SKILL.md skills/kit-init/SKILL.md skills/board/SKILL.md; do
  [ -f "$ROOT/$f" ] || continue
  while IFS= read -r l; do
    [ -z "$l" ] && continue
    if printf '%s' "$l" | grep -Eq "$allow"; then continue; fi
    if printf '%s' "$l" | grep -Eq -- '--model|/model'; then continue; fi
    bad "F5 $f mentions /clear without an explicit --model relaunch: $(printf '%s' "$l" | cut -c1-200)"
  done < <(grep -n '/clear' "$ROOT/$f" | cut -d: -f2-)
done
# The recycle row's line carries `--model` for the script, so the line check above cannot see its
# fallback clause; pin the old phrasings directly (a bare /clear keeps the terminal's OLD model).
hasnt "orchestrate no longer says a terminal is 'safe to /clear'" "safe to /clear" "$(cat "$ORCH")"
hasnt "orchestrate no longer says '/clear this terminal'" "/clear this terminal" "$(cat "$ORCH")"
has "orchestrate: recycle fallback relaunches with an explicit model" 'claude --name <Name> --model <lane model>' "$(cat "$ORCH")"
has "orchestrate: seat handover fallback relaunches with an explicit model" "claude --name Orca --model 'opus[1m]'" "$(cat "$ORCH")"
has "getting-started: by-hand section carries --model" "--model" "$(awk '/Opening a session by hand/{on=1} on{print} /^## /&&on&&!/Advanced/{exit}' "$GS" | head -20)"

echo "lean-orient: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
