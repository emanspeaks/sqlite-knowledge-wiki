# shellcheck shell=sh
# inventory.sh: what the wiki service's image holds besides MediaWiki,
# Wikibase and the Composer packages, for the SBOM: its Debian packages, its
# PHP, and the PHP extensions that are not part of PHP. Run inside the image
# by ci.yml's Server job, which checks that image/inventory.tsv is its output:
#   docker run --rm -i --entrypoint sh IMAGE -s < image/inventory.sh
# offline/php/tools/sbom_image.zig reads it.
set -eu
. /etc/os-release

echo "# Written by image/inventory.sh inside the wiki service's image (ci.yml's Server job)."
echo "# Regenerated, never edited: commit the image-inventory artifact of a run whose image changed."
printf 'os\t%s\t%s\n' "$ID" "$VERSION_ID"
printf 'php\t%s\t%s\t%s\n' "$PHP_VERSION" "$PHP_URL" "$PHP_SHA256"
# shellcheck disable=SC2016
php -r 'foreach (get_loaded_extensions() as $e) { $v = phpversion($e); if ($v !== false && $v !== PHP_VERSION) printf("php-ext\t%s\t%s\n", $e, $v); }' | LC_ALL=C sort
# shellcheck disable=SC2016
dpkg-query -W -f='deb\t${Package}\t${Version}\t${Architecture}\t${source:Package}\t${source:Version}\n' | LC_ALL=C sort
