#!/bin/sh
# Regenerates smoke.expected from a Linux PHP 8.3, for the lines that do not
# depend on how this build is configured. Lines that do are fixed up below;
# check any change to them by reading the CI output.
set -eu
cd "$(dirname "$0")"
tmp=$(mktemp)
sed 's/^echo .bcmath .*$/echo "bcmath 111111111011111111100 0.3333333333\\n";/' smoke.php > "$tmp"
php "$tmp" | sed \
    -e '1s/.*/version 8.3.37 Windows embed 64-bit/' \
    -e 's/^extensions .*/extensions bcmath,calendar,core,ctype,date,dom,fileinfo,filter,hash,json,libxml,mbstring,pcre,pdo,pdo_sqlite,random,reflection,session,simplexml,spl,sqlite3,standard,tokenizer,xml,xmlreader,xmlwriter,zlib/' \
    -e 's/^pdo .*/pdo sqlite/' \
    -e 's/^\(dom .*\) [0-9.]*$/\1 2.15.4/' \
    -e 's/^\(sqlite3 .*\) old$/\1 current/' > smoke.expected
rm -f "$tmp"
