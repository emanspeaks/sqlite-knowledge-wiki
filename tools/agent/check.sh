#!/usr/bin/env bash
# check.sh: the checks to run before a pull request, as CI runs them, from the
# repository root. CI does not run on pull requests into dev, so these are what
# stands between a change and dev. Set ZIG and SKEIN when zig and skein are not
# on the PATH.
#   check.sh          everything, the PHP build and its tests included
#   check.sh --quick  everything but the build (minutes instead of tens)
set -euo pipefail
cd "$(dirname "$0")/../.."
Z=${ZIG:-zig}
K=${SKEIN:-skein}

bash .github/workflows/version.sh > /dev/null
(cd offline/php && "$Z" fmt --check build.zig build sources.zig icu_sources.zig components.zig)
npx --yes markdownlint-cli2@0.24.2 "**/*.md" 2>&1 | tail -1
"$K" check
if [ "${1:-}" != --quick ]; then
  # -j6: Windows runs out of process handles spawning clang for every core
  (cd offline/php && "$Z" build -j6 --summary none && "$Z" build licenses -j6)
  if [ -f composer/composer.lock ]; then
    (cd offline/php && "$Z" build sbom -j6)
  else
    echo "check.sh: composer/composer.lock is not committed; no SBOM (CI's Server job writes one)"
  fi
  out=$(mktemp)
  offline/php/zig-out/bin/php-embed-smoke.exe offline/php/test/smoke.php > "$out"
  diff --strip-trailing-cr offline/php/test/smoke.expected "$out"
  rm -f "$out"
fi
echo "check.sh: all checks passed"
