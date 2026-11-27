#!/usr/bin/env bash
# smoke.sh: TST-001, the offline PHP runtime's test script run by a test
# program, passing when its output is offline/php/test/smoke.expected. Run by
# ci.yml and tools/agent/check.sh from the repository root:
#   smoke.sh PROGRAM [BUILD RESULTS]
# With RESULTS, the outcome is appended to that Skein results file
# (tests/result.sh), as the result of the BUILD's run.
set -euo pipefail

program=$1 build=${2:-} results=${3:-}
script=offline/php/test/smoke.php
out=$(mktemp)
trap 'rm -f "$out"' EXIT

status=0
"$program" "$script" > "$out" || status=$?
result=pass note=
if [ "$status" -ne 0 ]; then
    result=fail note="$program exited with $status"
    echo "smoke.sh: $note; its output:"
    cat "$out"
elif ! diff -u --strip-trailing-cr offline/php/test/smoke.expected "$out"; then
    result=fail note="the output is not smoke.expected"
fi

[ -z "$results" ] || bash "$(dirname "$0")/result.sh" "$results" "smoke.php, $build" "$script" "$result" "$note"
[ "$result" = pass ] || exit 1
echo "smoke.sh: $script passed${build:+ ($build)}"
