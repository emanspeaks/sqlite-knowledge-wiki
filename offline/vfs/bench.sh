#!/bin/bash
# Start one benchmark scenario. Usage: bench.sh MODE PORT SCRATCH_DIR [extra ini lines...]
#   real      MediaWiki from the image's real directory
#   vfs       MediaWiki from the pack through the wikivfs extension, real tree hidden
#   userland  MediaWiki from a phar through a PHP-level wrapper (the first prototype)
# Needs: DATA (dir with wiki.sqlite), CONF (dir with offline.php), STUB (entry stubs),
#        STATUS (opstatus.php), and for userland PHAR and VFSPHP.
set -eu
mode=$1; port=$2; scratch=$3; shift 3
name=bench-$mode-$port
ini="opcache.memory_consumption=384
opcache.interned_strings_buffer=64
opcache.max_accelerated_files=30000"
for l in "$@"; do ini="$ini
$l"; done
common=(-d --name "$name" -p 127.0.0.1:$port:80 -v "$DATA":/var/www/data:ro -v "$scratch":/scratch
  -v "$CONF":/etc/mediawiki/conf.d:ro -e MW_OFFLINE_SCRATCH=/scratch -e MW_SERVER=http://localhost:$port
  -e MW_SECRET_KEY=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
  -e PHP_INI_SCAN_DIR=/usr/local/etc/php/conf.d:/opt/ini -e "BENCH_INI=$ini" --entrypoint sh)
start='mkdir -p /opt/ini && printf "%s\n" "$BENCH_INI" > /opt/ini/zz.ini && exec docker-php-entrypoint apache2-foreground'
docker rm -f "$name" >/dev/null 2>&1 || true
case $mode in
  real)
    docker run "${common[@]}" -v "$STATUS":/var/www/html/opstatus.php:ro wikivfs-bench -c "$start" ;;
  vfs)
    docker run "${common[@]}" -v "$STUB":/var/www/html -e MW_INSTALL_PATH=/mw \
      -e "BENCH_INI=$ini
extension=wikivfs
wikivfs.pack=/opt/mw.wvfs
wikivfs.root=/mw" wikivfs-bench -c "$start" ;;
  userland)
    docker run "${common[@]}" -v "$STUB":/var/www/html -v "$VFSPHP":/opt/vfs.php:ro -v "$PHAR":/opt/mw.phar:ro \
      -e MW_INSTALL_PATH=/mw -e "BENCH_INI=$ini
auto_prepend_file=/opt/vfs.php" wikivfs-bench -c "$start" ;;
esac >/dev/null
