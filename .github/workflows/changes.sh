# shellcheck shell=bash
# Which changed files can change what a release ships. Sourced (in bash, from
# the repository root) by ci.yml's "Changes" job, which decides whether a
# pull request needs the checks, and by its "Version" job, which decides
# whether a push to main is a release. From skein's changes.sh.

# patterns LIST...: the globs of the lists (one bash `case` glob per line;
# lines starting with # and blank lines are ignored)
patterns() { cat "$@" | grep -v '^\s*#' | grep -v '^\s*$'; }

# matches FILE GLOB...: whether FILE matches one of the globs
matches() {
    local f=$1 pat
    shift
    for pat in "$@"; do
        # shellcheck disable=SC2254
        case "$f" in $pat) return 0 ;; esac
    done
    return 1
}

# The files whose changes alone skip CI, and the files that cannot change
# what ships (used where this is sourced)
# shellcheck disable=SC2034
mapfile -t no_ci < <(patterns .github/workflows/no-ci.txt)
# shellcheck disable=SC2034
mapfile -t docs_only < <(patterns .github/workflows/docs-only.txt)
# shellcheck disable=SC2034
mapfile -t exempt < <(patterns .github/workflows/no-ci.txt .github/workflows/docs-only.txt .github/workflows/ci-only.txt)

# ships FILE: whether FILE is in a release whatever the lists say. The
# server package carries README.md, and both packages carry LICENSE.
ships() {
    case "$1" in README.md | LICENSE) return 0 ;; esac
    return 1
}

# shipped_changes TAG: the files changed since TAG that change what a
# release ships: the server files or the Windows program. A version begun on
# dev changes VERSION, which alone ships nothing new.
shipped_changes() {
    local f
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        [ "$f" = VERSION ] && continue
        if ! ships "$f" && matches "$f" "${exempt[@]}"; then continue; fi
        echo "$f"
    done <<< "$(git diff --name-only "$1" HEAD)"
}
