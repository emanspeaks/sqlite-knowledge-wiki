# MediaWiki + Semantic MediaWiki + Wikibase, SQLite only.
ARG MEDIAWIKI_IMAGE=mediawiki:1.43
FROM composer:2 AS composer

FROM ${MEDIAWIKI_IMAGE}

ARG SMW_VERSION="~7.4"
ARG WIKIBASE_BRANCH=REL1_43
ARG WIKIBASE_GIT_URL=https://gerrit.wikimedia.org/r/mediawiki/extensions/Wikibase

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends unzip sqlite3; \
    rm -rf /var/lib/apt/lists/*

COPY --from=composer /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

# Wikibase: the JavaScript UI lives in git submodules, so they are required.
# Some submodules are hosted on Phabricator, which rate-limits (HTTP 429) and
# refuses shallow fetches, hence the full-depth submodule fetch with retries.
RUN set -eux; \
    git clone --depth 1 --branch "${WIKIBASE_BRANCH}" "${WIKIBASE_GIT_URL}" extensions/Wikibase; \
    cd extensions/Wikibase; \
    n=0; \
    until git submodule update --init --recursive --jobs 1; do \
        n=$((n + 1)); \
        [ "$n" -lt 6 ] || exit 1; \
        sleep $((n * 20)); \
    done; \
    git rev-parse HEAD > .build-commit; \
    find . -name .git -prune -exec rm -rf {} +

# SMW comes from Packagist; Wikibase's PHP dependencies are merged in through
# MediaWiki's composer merge plugin.
RUN set -eux; \
    printf '%s\n' \
        '{' \
        '  "require": { "mediawiki/semantic-media-wiki": "'"${SMW_VERSION}"'" },' \
        '  "extra": { "merge-plugin": { "include": [ "extensions/Wikibase/composer.json" ] } }' \
        '}' > composer.local.json; \
    export COMPOSER_ALLOW_SUPERUSER=1; \
    composer update --no-dev --no-interaction --no-progress --optimize-autoloader; \
    composer clear-cache; \
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
