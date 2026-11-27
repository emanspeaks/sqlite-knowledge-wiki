#!/usr/bin/env bash
# version.sh: the project's version, run from the repository root by ci.yml.
# VERSION is the one place that states it; a new place is added here.
#   version.sh           prints the version; fails when it is not MAJOR.MINOR.PATCH
#   version.sh set NEXT  sets it, as CI does when it begins the next version
set -euo pipefail

file=VERSION

check() {
  local version
  version=$(tr -d '[:space:]' < "$file")
  if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "version.sh: $file must hold MAJOR.MINOR.PATCH; found '$version'" >&2
    exit 1
  fi
  echo "$version"
}

set_version() {
  local next=$1
  [[ $next =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version.sh: '$next' is not MAJOR.MINOR.PATCH" >&2; exit 1; }
  printf '%s\n' "$next" > "$file"
}

case "${1:-}" in
  "") check ;;
  set) set_version "${2:?version.sh set NEXT}" ;;
  *) echo "version.sh: [set NEXT]" >&2; exit 1 ;;
esac
