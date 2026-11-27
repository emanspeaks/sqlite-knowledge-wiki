# shellcheck shell=sh
# inventory.sh: what the wiki service's image holds besides MediaWiki,
# Wikibase and the Composer packages, for the SBOM: its Debian packages, its
# PHP, and the PHP extensions installed from PECL. Run inside the image by
# ci.yml's Server job, which checks that image/inventory.csv is its output:
#   docker run --rm -i --entrypoint sh IMAGE -s < image/inventory.sh
# image/inventory.csv is regenerated this way, never edited (docs/maintenance-plan.md).
# offline/php/tools/sbom_image.zig reads it. CSV with a header and the same
# eight columns on every row; no field holds a comma (Debian names and
# versions cannot), so nothing is quoted.
set -eu
. /etc/os-release

echo 'kind,name,version,arch,source,source_version,url,sha256'
printf 'os,%s,%s,,,,,\n' "$ID" "$VERSION_ID"
printf 'php,php,%s,,,,%s,%s\n' "$PHP_VERSION" "$PHP_URL" "$PHP_SHA256"
# `pecl list` prints three lines of heading, then NAME VERSION STATE
pecl list | awk 'NR > 3 && NF == 3 { printf "php-ext,%s,%s,,,,,\n", $1, $2 }' | LC_ALL=C sort
# shellcheck disable=SC2016
dpkg-query -W -f='deb,${Package},${Version},${Architecture},${source:Package},${source:Version},,\n' | LC_ALL=C sort
