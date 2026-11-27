# MediaWiki + Semantic MediaWiki + Wikibase, SQLite only.
#
# Every input is pinned: the two images by digest, Wikibase by commit (which
# pins its submodules), the Composer packages by composer/composer.lock, and
# Debian's packages by a snapshot. offline/php's `zig build sbom` reads the
# pins from here, the lock, and image/inventory.csv.
# To move to a newer release, change the pin and regenerate the lock
# (README, "Upgrading").
ARG MEDIAWIKI_IMAGE=mediawiki:1.43.12@sha256:f552ec5c19f2d9e24b1a73eefebb899be30a5d82d0ec59837596021cecd977a1
FROM composer:2.10.3@sha256:2cf275428757e5435a667bfc0d038b14520ca02be2b1b70d44a05c8c19e2de48 AS composer

FROM ${MEDIAWIKI_IMAGE}

ARG WIKIBASE_COMMIT=4577d292df834d654814dbe9c42d5e1968235836
ARG WIKIBASE_BRANCH=REL1_43
ARG WIKIBASE_GIT_URL=https://gerrit.wikimedia.org/r/mediawiki/extensions/Wikibase
# 1 resolves the Composer packages afresh and writes a new lock into the image
# (/var/www/html/composer.lock), instead of installing the committed one
ARG COMPOSER_UPDATE=0

# Debian's packages come from snapshot.debian.org as it was at this time, so a
# later build installs the same versions; image/inventory.csv lists every
# package of the image. Set it to when the MediaWiki image was built, or after.
ARG DEBIAN_SNAPSHOT=20261126T120000Z

RUN set -eux; \
    sources=/etc/apt/sources.list.d/debian.sources; \
    cp "$sources" /tmp/debian.sources; \
    sed -i -E \
        -e "s|^URIs: https?://deb\.debian\.org/debian-security/?\$|URIs: https://snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT}|" \
        -e "s|^URIs: https?://deb\.debian\.org/debian/?\$|URIs: https://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}|" \
        "$sources"; \
    if grep '^URIs:' "$sources" | grep -qv "snapshot.debian.org/archive/.*/${DEBIAN_SNAPSHOT}\$"; then \
        echo "a source of $sources is not the snapshot:"; cat "$sources"; exit 1; \
    fi; \
    apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Retries=5 update; \
    apt-get -o Acquire::Retries=5 install -y --no-install-recommends unzip sqlite3; \
    mv /tmp/debian.sources "$sources"; \
    rm -rf /var/lib/apt/lists/*

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

# Wikibase: the JavaScript UI lives in git submodules, so they are required.
# Some submodules are hosted on Phabricator, which rate-limits (HTTP 429) and
# refuses shallow fetches, hence the full-depth submodule fetch with retries.
# Gerrit does not serve a commit by its hash, so the branch is cloned and the
# pinned commit checked out.
RUN set -eux; \
    git clone --single-branch --branch "${WIKIBASE_BRANCH}" "${WIKIBASE_GIT_URL}" extensions/Wikibase; \
    cd extensions/Wikibase; \
    git checkout -q --detach "${WIKIBASE_COMMIT}"; \
    [ "$(git rev-parse HEAD)" = "${WIKIBASE_COMMIT}" ]; \
    n=0; \
    until git submodule update --init --recursive --jobs 1; do \
        n=$((n + 1)); \
        [ "$n" -lt 6 ] || exit 1; \
        sleep $((n * 20)); \
    done; \
    git rev-parse HEAD > .build-commit; \
    find . -name .git -prune -exec rm -rf {} +

# SMW comes from Packagist; Wikibase's PHP dependencies are merged in through
# MediaWiki's composer merge plugin. The lock is resolved against MediaWiki's
# own composer.json, so it pins MediaWiki's PHP libraries too.
COPY composer/ /tmp/wiki-composer/
RUN set -eux; \
    cp /tmp/wiki-composer/composer.local.json composer.local.json; \
    export COMPOSER_ALLOW_SUPERUSER=1; \
    if [ "${COMPOSER_UPDATE}" = 1 ]; then \
        composer update --no-dev --no-interaction --no-progress --optimize-autoloader; \
    else \
        [ -f /tmp/wiki-composer/composer.lock ] || { echo "composer/composer.lock is missing: build with --build-arg COMPOSER_UPDATE=1 to write one"; exit 1; }; \
        cp /tmp/wiki-composer/composer.lock composer.lock; \
        composer install --no-dev --no-interaction --no-progress --optimize-autoloader; \
    fi; \
    composer clear-cache; \
    rm -rf /tmp/wiki-composer; \
    chown -R www-data:www-data extensions/SemanticMediaWiki

# Settings live outside the web root; MediaWiki 1.43 honors MW_CONFIG_FILE.
COPY LocalSettings.php /etc/mediawiki/LocalSettings.php
COPY docker-entrypoint.sh /usr/local/bin/wiki-entrypoint
RUN set -eux; \
    chmod 0755 /usr/local/bin/wiki-entrypoint; \
    mkdir -p /etc/mediawiki/conf.d /var/www/data; \
    chown www-data:www-data /var/www/data

ENV MW_CONFIG_FILE=/etc/mediawiki/LocalSettings.php \
    MW_DATA_DIR=/var/www/data

VOLUME ["/var/www/data", "/var/www/html/images"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=10m --retries=3 \
    CMD curl -fsS -o /dev/null "http://localhost${MW_SCRIPT_PATH:-}/api.php?action=query&meta=siteinfo&format=json" || exit 1

ENTRYPOINT ["wiki-entrypoint"]
CMD ["apache2-foreground"]
