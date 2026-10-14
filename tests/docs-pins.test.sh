#!/usr/bin/env bash
# Pins for rules that live in skill/template text (no script to execute): the evidence dir, the question
# modes, permission asks as a command, the ToolSearch preload before ListAgents/SendMessage, the tested
# Claude Code version, and the troubleshooting rows for this release's mechanisms.
# Run: bash tests/docs-pins.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
pin() {  # <label> <file> <fixed string>
  grep -qF -- "$3" "$ROOT/$2" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL $1: '$3' not in $2"; }
}
T=templates/ORCHESTRATION.md; O=skills/orchestrate/SKILL.md; G=docs/GETTING-STARTED.md
pin "evidence dir in the overlay" $T "evidence dir:   ~/.orchestration-kit/scratch/<YYYY>/<Month>/<row>/"
grep -n 'evidence dir:' "$ROOT/$T" | grep -q '/tmp' && { fail=$((fail+1)); echo "FAIL the evidence dir names /tmp"; } || pass=$((pass+1))
pin "evidence dir in the brief template" templates/briefs/_TEMPLATE.md "the evidence dir (ORCHESTRATION.md), never \`/tmp\`"
pin "questions key, default blocking" $T "questions:      blocking"
pin "question modes table" $O "| \`blocking\` (default) |"
pin "non-blocking keeps a HUMAN QUEUE" $O "\`HUMAN QUEUE\` line"
pin "permission asks are a command" $O "Permission requests are a command, not prose."
for f in skills/orient/SKILL.md $O skills/orient-brief/SKILL.md skills/assemble-train/SKILL.md; do pin "ToolSearch preload in $f" "$f" "select:ListAgents,SendMessage"; done
pin "ToolSearch preload in retro" skills/retro/SKILL.md "select:SendMessage"
pin "tested Claude Code version" $G "Tested on Claude Code 2.1.296."
for row in "recycle-sibling.sh\` exits 3" "prints \`NO BANNER\`" "Gates never start" "The hooks do nothing" "SendMessage / ListAgents is not available"; do pin "troubleshooting: $row" $G "$row"; done
pin "kit-init platform check" skills/kit-init/SKILL.md "**Platform check"
pin "max_sessions in the overlay" $T "max_sessions:     8"
# Team mode is the default path (ORCA181-3); Solo is the practice mode. The start question's FIRST option must be
# the team start, and the last must be the practice option; the README must not call Solo the start.
K=skills/kit-init/SKILL.md; R=README.md
row="$(grep -F 'Start the team now?' "$ROOT/$K" | head -1)"
case "$row" in *"| **Seat + 2 siblings (Recommended)** ·"*) pass=$((pass+1));; *) fail=$((fail+1)); echo "FAIL kit-init start question: first option is not '**Seat + 2 siblings (Recommended)**'";; esac
last="${row##*"· **"}"   # the text after the LAST option separator: must be the practice option, by position
case "$last" in "Practice mode (Solo)**"*) pass=$((pass+1));; *) fail=$((fail+1)); echo "FAIL kit-init start question: the LAST option is not '**Practice mode (Solo)**'";; esac
pin "practice route keeps the guards off" $K "**Practice mode (Solo)** → both \`off\`"
for stale in "Solo** (start here)" "recommended first time" "recommended start" "Team** (Advanced)" "Not now" "The way to begin" "Start solo"; do
  for f in $R $G docs/GLOSSARY.md HOW-IT-WORKS.md docs/how-it-works.html .claude-plugin/plugin.json $K; do
    grep -qiF -- "$stale" "$ROOT/$f" && { fail=$((fail+1)); echo "FAIL stale default wording '$stale' still in $f"; } || pass=$((pass+1))
  done
done
pin "guide page #pick names Solo as practice" docs/how-it-works.html "<b>Solo (practice):</b> two terminals, no seat"
pin "guide page flavor table names Solo practice" docs/how-it-works.html "<td>Solo practice (two terminals)</td>"
pin "HOW-IT-WORKS.md names Solo as practice" HOW-IT-WORKS.md "- **Solo (practice):** two terminals, no seat"
pin "HOW-IT-WORKS.md flavor table names Solo practice" HOW-IT-WORKS.md "| Solo practice (two terminals) |"
t="$(grep -n '^| \*\*Team' "$ROOT/$R" | head -1 | cut -d: -f1)"; s="$(grep -n '^| \*\*Solo' "$ROOT/$R" | head -1 | cut -d: -f1)"
[ -n "$t" ] && [ -n "$s" ] && [ "$t" -lt "$s" ] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL README mode table: Team row must come before the Solo row"; }
echo "docs-pins: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
