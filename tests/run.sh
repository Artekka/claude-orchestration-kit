#!/usr/bin/env bash
# Run every kit test script: bash tests/run.sh   (no network; needs bash, git, awk; python3 for ctx tests)
cd "$(dirname "$0")" || exit 1
rc=0
for t in ./*.test.sh; do
  echo "== $t"
  bash "$t" || rc=1
done
[ "$rc" -eq 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit "$rc"
