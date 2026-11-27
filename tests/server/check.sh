#!/usr/bin/env bash
# check.sh: tests a running wiki service through its API, as ci.yml's Server
# job runs it after `docker compose up`. Needs curl and jq.
#   check.sh write      logs in, edits, and checks that queries see the edits
#   check.sh read       checks what `write` made is there (after a restart)
#   check.sh read-only  the same reads, and that edits are refused
# Environment: WIKI (base URL, default http://localhost:8080), ADMIN_USER,
# ADMIN_PASSWORD, and COMPOSE (the compose command, default `docker compose`).
#
# verifies: SRS-001 (MediaWiki 1.43, Semantic MediaWiki, Wikibase repo and client)
# verifies: SRS-002 (the SQLite files in the data directory)
# verifies: SRS-003 (the first-run install and its admin account)
# verifies: SRS-004 (the secret key kept in the data volume)
# verifies: SRS-005 (the staged update on a fresh database)
# verifies: SRS-008 (the jobrunner service runs the queue)
# verifies: SRS-009 (Wikibase properties outside SMW's Property namespace)
# verifies: SRS-010 (read-only mode)
# verifies: SRS-011 (the jobrunner's updates are seen by the web container)
# verifies: SRS-032 (Math renders formulas without a service)
# verifies: SRS-072 (the health check: the job waits for healthy)
# verifies: SRS-095 (the admin password from the secret file)
set -euo pipefail

WIKI=${WIKI:-http://localhost:8080}
COMPOSE=${COMPOSE:-docker compose}
API="$WIKI/api.php"
jar=$(mktemp)
trap 'rm -f "$jar"' EXIT
failures=0

fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "ok:   $*"; }
get() { curl -fsS -b "$jar" -c "$jar" -G "$API" --data-urlencode format=json "$@"; }
post() { curl -fsS -b "$jar" -c "$jar" "$API" --data-urlencode format=json "$@"; }

login() {
    local token result
    token=$(get --data-urlencode action=query --data-urlencode meta=tokens --data-urlencode type=login | jq -r .query.tokens.logintoken)
    result=$(post --data-urlencode action=clientlogin --data-urlencode "username=$ADMIN_USER" \
        --data-urlencode "password=$ADMIN_PASSWORD" --data-urlencode "logintoken=$token" \
        --data-urlencode "loginreturnurl=$WIKI/" | jq -r '.clientlogin.status // .error.code')
    [ "$result" = PASS ] && pass "login as $ADMIN_USER" || fail "login: $result"
}

csrf() { get --data-urlencode action=query --data-urlencode meta=tokens | jq -r .query.tokens.csrftoken; }

edit() {
    local title=$1 text=$2 token result
    token=$(csrf)
    result=$(post --data-urlencode action=edit --data-urlencode "title=$title" --data-urlencode "text=$text" \
        --data-urlencode "token=$token" | jq -r '.edit.result // .error.code')
    [ "$result" = Success ] && pass "edit $title" || fail "edit $title: $result"
}

parse() {
    get --data-urlencode action=parse --data-urlencode "text=$1" --data-urlencode contentmodel=wikitext \
        --data-urlencode prop=text --data-urlencode disablelimitreport=1 | jq -r '.parse.text["*"]'
}

# Jobs run in the jobrunner container, so the web container sees what another
# container's jobs changed (the shared main cache)
run_jobs() { $COMPOSE exec -T -u www-data jobrunner php maintenance/run.php runJobs > /dev/null; }

check_reads() {
    local ask q1 label value hits text
    ask=$(get --data-urlencode action=ask --data-urlencode 'query=[[Has mass::>30000]]|?Has mass')
    [ "$(jq -r '.query.results | keys | join(",")' <<< "$ask")" = "Falcon 9" ] \
        && [ "$(jq -r '.query.results["Falcon 9"].printouts["Has mass"][0]' <<< "$ask")" = 549054 ] \
        && pass "#ask finds Falcon 9 by a numeric property" || fail "#ask: $ask"

    q1=$(get --data-urlencode action=wbgetentities --data-urlencode ids=Q1)
    label=$(jq -r '.entities.Q1.labels.en.value' <<< "$q1")
    value=$(jq -r '.entities.Q1.claims.P1[0].mainsnak.datavalue.value.amount' <<< "$q1")
    [ "$label" = "Falcon 9" ] && [ "$value" = "+549054" ] && pass "wbgetentities Q1" || fail "wbgetentities: $label $value"
    [ "$(jq -r '.entities.Q1.title' <<< "$q1")" = Item:Q1 ] && pass "items in Item:" || fail "item title: $(jq -r '.entities.Q1.title' <<< "$q1")"
    [ "$(get --data-urlencode action=wbgetentities --data-urlencode ids=P1 | jq -r .entities.P1.title)" = WbProperty:P1 ] \
        && pass "Wikibase properties in WbProperty:, apart from SMW's Property:" || fail "property namespace"

    hits=$(get --data-urlencode action=wbsearchentities --data-urlencode search=Falc --data-urlencode language=en \
        --data-urlencode type=item | jq -r '[.search[].id] | join(",")')
    [ "$hits" = Q1 ] && pass "wbsearchentities" || fail "wbsearchentities: $hits"

    text=$(parse '{{#statements:P1|from=Q1}}')
    grep -q '549,054' <<< "$text" && pass "{{#statements}} in a client page" || fail "#statements: $text"

    text=$(parse '<math>E = mc^2 + \frac{a}{b}</math>')
    grep -q 'mwe-math-element' <<< "$text" && grep -q '<mfrac>' <<< "$text" && pass "Math renders MathML" || fail "Math: $text"

    text=$(parse '{{#invoke:Greeting|hello}}')
    grep -q 'hello from Lua' <<< "$text" && pass "Scribunto runs a Lua module" || fail "Scribunto: $text"

    [ "$(get --data-urlencode action=query --data-urlencode list=search --data-urlencode srsearch=rocket \
        --data-urlencode srwhat=text | jq -r .query.searchinfo.totalhits)" = 2 ] && pass "full-text search" || fail "search"
}

check_files() {
    local f
    for f in wiki.sqlite wiki_jobqueue.sqlite wiki_l10n_cache.sqlite wikicache.sqlite secret.key; do
        $COMPOSE exec -T wiki test -s "/var/www/data/$f" && pass "data/$f" || fail "no data/$f"
    done
    [ "$($COMPOSE exec -T -u www-data wiki sqlite3 /var/www/data/wiki.sqlite 'PRAGMA integrity_check;' | tr -d '\r')" = ok ] \
        && pass "integrity_check" || fail "integrity_check"
    [ -n "$($COMPOSE exec -T -u www-data wiki sqlite3 /var/www/data/wiki.sqlite "SELECT name FROM sqlite_master WHERE name = 'wb_items_per_site';")" ] \
        && pass "the Wikibase tables (staged update)" || fail "no Wikibase tables"
}

case "${1:-}" in
    write)
        login
        edit "Hello" "Hello world, '''first''' page."
        edit "Property:Has mass" "[[Has type::Number]]"
        edit "Falcon 9" "Rocket. [[Has mass::549054]]"
        edit "Electron" "Small rocket. [[Has mass::12500]]"
        edit "Module:Greeting" 'local p = {} function p.hello() return "hello from Lua" end return p'
        run_jobs
        token=$(csrf)
        pid=$(post --data-urlencode action=wbeditentity --data-urlencode new=property --data-urlencode "token=$token" \
            --data-urlencode 'data={"labels":{"en":{"language":"en","value":"mass"}},"datatype":"quantity"}' | jq -r '.entity.id // .error.code')
        [ "$pid" = P1 ] && pass "new Wikibase property" || fail "new property: $pid"
        qid=$(post --data-urlencode action=wbeditentity --data-urlencode new=item --data-urlencode "token=$token" \
            --data-urlencode 'data={"labels":{"en":{"language":"en","value":"Falcon 9"}},"claims":[{"mainsnak":{"snaktype":"value","property":"P1","datavalue":{"type":"quantity","value":{"amount":"+549054","unit":"1"}}},"type":"statement","rank":"normal"}]}' \
            | jq -r '.entity.id // .error.code')
        [ "$qid" = Q1 ] && pass "new Wikibase item with a statement" || fail "new item: $qid"
        run_jobs
        check_reads
        check_files
        ;;
    read)
        check_reads
        check_files
        ;;
    read-only)
        check_reads
        # read-only mode refuses logins through the API too (MediaWiki treats
        # them as writes), so the edit is tried anonymously: the read-only
        # check comes before the permission check
        result=$(post --data-urlencode action=clientlogin --data-urlencode "username=$ADMIN_USER"             --data-urlencode "password=$ADMIN_PASSWORD" --data-urlencode logintoken=x             --data-urlencode "loginreturnurl=$WIKI/" | jq -r '.error.code // .clientlogin.status')
        [ "$result" = readonly ] && pass "logins refused when read-only" || fail "read-only login: $result"
        token=$(csrf)
        result=$(post --data-urlencode action=edit --data-urlencode title=Refused --data-urlencode text=x \
            --data-urlencode "token=$token" | jq -r '.error.code // .edit.result')
        [ "$result" = readonly ] && pass "edits refused when read-only" || fail "read-only edit: $result"
        ;;
    *)
        echo "check.sh: write | read | read-only" >&2
        exit 2
        ;;
esac

if [ "$failures" -ne 0 ]; then
    echo "check.sh: $failures failed"
    exit 1
fi
echo "check.sh: all passed"
