# shellcheck shell=sh
# inventory.sh: what the wiki service's image holds besides MediaWiki,
# Wikibase and the Composer packages, for the SBOM: its Debian packages, its
# PHP, and the PHP extensions installed from PECL. Run inside the image
# by ci.yml's Server job, which checks that image/inventory.tsv is its output:
#   docker run --rm -i --entrypoint sh IMAGE -s < image/inventory.sh
# offline/php/tools/sbom_image.zig reads it.
set -eu
. /etc/os-release

echo "# Written by image/inventory.sh inside the wiki service's image (ci.yml's Server job)."
echo "# Regenerated, never edited: commit the image-inventory artifact of a run whose image changed."
printf 'os\t%s\t%s\n' "$ID" "$VERSION_ID"
printf 'php\t%s\t%s\t%s\n' "$PHP_VERSION" "$PHP_URL" "$PHP_SHA256"
# the extensions installed from PECL (the rest are PHP's own); `pecl list`
# prints three lines of heading, then NAME VERSION STATE
pecl list | awk 'NR > 3 && NF == 3 { printf "php-ext\t%s\t%s\n", $1, $2 }' | LC_ALL=C sort
# shellcheck disable=SC2016
dpkg-query -W -f='deb\t${Package}\t${Version}\t${Architecture}\t${source:Package}\t${source:Version}\n' | LC_ALL=C sort
