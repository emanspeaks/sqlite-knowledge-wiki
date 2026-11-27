#!/usr/bin/env bash
# result.sh: appends one test result to a Skein results file (TOML), for
# `skein coverage --results`. The result belongs to the requirements the test
# file cites (`verifies:`). Run by ci.yml's test steps and tests/server/check.sh.
#   result.sh OUT TEST FILE pass|fail|skip [NOTE]
# OUT is the results file, TEST the check's name, FILE the test's file from
# the repository root. The implementation is this project, at VERSION.
set -euo pipefail

[ $# -ge 4 ] && [ $# -le 5 ] || { echo "result.sh: OUT TEST FILE pass|fail|skip [NOTE]" >&2; exit 2; }
out=$1 test=$2 file=$3 result=$4 note=${5:-}
case "$result" in pass | fail | skip) ;; *) echo "result.sh: '$result' is not pass, fail or skip" >&2; exit 2 ;; esac

mkdir -p "$(dirname "$out")"
root=$(cd "$(dirname "$0")/.." && pwd)
version=$(tr -d '[:space:]' < "$root/VERSION")

# a TOML basic string: at most 300 characters, control characters as spaces,
# backslashes and quotes escaped
str() {
    local s=$1
    [ ${#s} -le 300 ] || s="${s:0:297}..."
    s=$(printf '%s' "$s" | tr '\000-\037\177' ' ')
    s=${s//\\/\\\\}
    printf '"%s"' "${s//\"/\\\"}"
}

{
    printf '[[result]]\n'
    printf 'test = %s\n' "$(str "$test")"
    printf 'file = %s\n' "$(str "$file")"
    printf 'result = "%s"\n' "$result"
    printf 'implementation = "sqlite-knowledge-wiki"\n'
    printf 'version = %s\n' "$(str "$version")"
    [ -z "$note" ] || printf 'note = %s\n' "$(str "$note")"
    printf '\n'
} >> "$out"
