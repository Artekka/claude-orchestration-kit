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
echo "docs-pins: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
