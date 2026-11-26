#!/bin/bash
# Entrypoint for the wiki image.
#
#   apache2-foreground (default)  initialise or update the wiki, then serve it
#   jobrunner                     run the job queue in a loop; no initialisation
#   anything else                 run it as given (e.g. `php maintenance/run.php ...`)
set -euo pipefail

MW_ROOT=/var/www/html
export MW_DATA_DIR="${MW_DATA_DIR:-/var/www/data}"
export MW_DB_NAME="${MW_DB_NAME:-wiki}"
DB_FILE="${MW_DATA_DIR}/${MW_DB_NAME}.sqlite"
SECRET_FILE="${MW_DATA_DIR}/secret.key"

log() { echo "[wiki] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

is_true() {
    case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

# Run a command as www-data (maintenance must never create root-owned files in
# the data volume). If the container itself runs unprivileged, run directly.
as_www() {
    if [ "$(id -u)" = 0 ]; then
        runuser -u www-data -- "$@"
    else
        "$@"
    fi
}

maint() { ( cd "$MW_ROOT" && as_www php maintenance/run.php "$@" ); }

has_table() {
    [ -n "$(as_www sqlite3 "$DB_FILE" \
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$1';" 2>/dev/null)" ]
}

fix_ownership() {
    [ "$(id -u)" = 0 ] || return 0
    mkdir -p "$MW_DATA_DIR" "$MW_ROOT/images"
    chown -R www-data:www-data "$MW_DATA_DIR"
    # images/ can be large; only walk it when the top level is wrong.
    if [ "$(stat -c %U "$MW_ROOT/images")" != www-data ]; then
        chown -R www-data:www-data "$MW_ROOT/images"
    fi
}

ensure_secret() {
    if [ -n "${MW_SECRET_KEY:-}" ] || [ -s "$SECRET_FILE" ]; then
        return 0
    fi
    log "Generating secret key in $SECRET_FILE"
    ( umask 077 && php -r 'echo bin2hex(random_bytes(32)), "\n";' > "$SECRET_FILE" )
    [ "$(id -u)" != 0 ] || chown www-data:www-data "$SECRET_FILE"
}

install_wiki() {
    local password="${MW_ADMIN_PASSWORD:-}"
    if [ -z "$password" ] && [ -n "${MW_ADMIN_PASSWORD_FILE:-}" ]; then
        password="$(cat "$MW_ADMIN_PASSWORD_FILE")"
    fi
    [ -n "$password" ] || die "First run: set MW_ADMIN_PASSWORD (or MW_ADMIN_PASSWORD_FILE)."
    [ "${#password}" -ge 10 ] || die "First run: MW_ADMIN_PASSWORD must be at least 10 characters."

    log "No database at $DB_FILE: installing MediaWiki"
    local tmp
    tmp="$(mktemp -d)"
    ( umask 077 && printf '%s' "$password" > "$tmp/admin-password" )
    [ "$(id -u)" != 0 ] || chown -R www-data:www-data "$tmp"

    # install.php refuses to run when it finds an existing LocalSettings.php, so
    # hide MW_CONFIG_FILE and let it write its own to a throwaway directory.
    # Extensions are added afterwards by update.php, never by --with-extensions.
    if ! ( cd "$MW_ROOT" && as_www env -u MW_CONFIG_FILE php maintenance/run.php install \
            --dbtype sqlite \
            --dbpath "$MW_DATA_DIR" \
            --dbname "$MW_DB_NAME" \
            --server "$MW_SERVER" \
            --scriptpath "${MW_SCRIPT_PATH:-}" \
            --lang "${MW_LANG:-en}" \
            --passfile "$tmp/admin-password" \
            --confpath "$tmp" \
            "${MW_SITE_NAME:-Wiki}" "${MW_ADMIN_USER:-Admin}" ); then
        rm -rf "$tmp"
        # Leave nothing half-installed behind, so the next start retries cleanly.
        rm -f "$DB_FILE" "$DB_FILE"-wal "$DB_FILE"-shm
        die "install.php failed"
    fi
    rm -rf "$tmp"
}

# update.php, staged where necessary.
#
# With SMW and Wikibase both enabled on a database that has no Wikibase tables
# yet, a single update.php fails: SMW creates pages before Wikibase's tables
# exist and a Wikibase client hook queries the missing wb_items_per_site table.
# So run it once with SMW off, then again with everything on. Checking for the
# table (rather than "is this the first run") also recovers an interrupted
# first run and covers enabling Wikibase on an existing wiki.
update_wiki() {
    if is_true "${MW_ENABLE_WIKIBASE:-true}" && is_true "${MW_ENABLE_SMW:-true}" \
        && ! has_table wb_items_per_site; then
        log "Wikibase tables missing: running update.php with SMW disabled first"
        MW_ENABLE_SMW=false MW_READ_ONLY= maint update --quick
    fi
    log "Running update.php"
    MW_READ_ONLY= maint update --quick
}

configure_apache() {
    [ "$(id -u)" = 0 ] || return 0
    local path="${MW_SCRIPT_PATH:-}"
    path="${path%/}"
    if [ -n "$path" ]; then
        printf 'Alias "%s" "%s"\n' "$path" "$MW_ROOT" > /etc/apache2/conf-enabled/wiki-script-path.conf
    else
        rm -f /etc/apache2/conf-enabled/wiki-script-path.conf
    fi
}

init_wiki() {
    [ -n "${MW_SERVER:-}" ] || die "MW_SERVER is required (the public URL, e.g. https://wiki.example.org)."
    fix_ownership
    ensure_secret

    if [ ! -f "$DB_FILE" ]; then
        install_wiki
        update_wiki
        log "First-run setup complete"
    elif ! has_table user; then
        die "$DB_FILE exists but is not a MediaWiki database (interrupted install?). Move it away and restart."
    elif [ -n "${MW_READ_ONLY:-}" ]; then
        log "MW_READ_ONLY is set: skipping update.php"
    elif is_true "${MW_AUTO_UPDATE:-true}"; then
        update_wiki
    else
        log "MW_AUTO_UPDATE is off: skipping update.php"
    fi
    configure_apache
}

run_jobs() {
    local interval="${MW_JOB_INTERVAL:-10}"
    log "Job runner started (interval ${interval}s)"
    trap 'exit 0' TERM INT
    while true; do
        if [ -f "$DB_FILE" ] && [ -z "${MW_READ_ONLY:-}" ]; then
            maint runJobs --maxtime 300 --memory-limit 512M \
                || log "runJobs exited with status $?"
        fi
        sleep "$interval" &
        wait $!
    done
}

case "${1:-apache2-foreground}" in
    apache2-foreground|apache2*)
        init_wiki
        exec docker-php-entrypoint "$@"
        ;;
    jobrunner)
        run_jobs
        ;;
    *)
        exec "$@"
        ;;
esac
