#!/bin/sh
# Regenerates smoke.expected from a Linux PHP 8.3, for the lines that do not
# depend on how this build is configured. Lines that do are fixed up below;
# check any change to them by reading the CI output. (GNU libiconv, unlike
# the C library's iconv on Linux, transliterates an accented letter to the
# accent followed by the letter.)
set -eu
cd "$(dirname "$0")"
tmp=$(mktemp)
# The local PHP has no bcmath or LuaSandbox and does not run OPcache on the
# command line; their expected lines are written here.
awk '/^\/\/ OPcache: compile/ { skip = 1; print "echo \"opcache true true true 42 false\\n\";" } /^\/\/ Lua the way Scribunto/ { skip = 1; print "echo \"luasandbox 2,4,6,8,10 ababab Lua 5.1 | from lua | memory limit\\n\";" } /^\/\/ Fibers switch stacks/ { skip = 0 } !skip' smoke.php | sed 's/^echo .bcmath .*$/echo "bcmath 111111111011111111100 0.3333333333\\n";/' > "$tmp"
php "$tmp" | sed \
    -e '1s/.*/version 8.3.37 Windows embed 64-bit/' \
    -e 's/^extensions .*/extensions bcmath,calendar,core,ctype,date,dom,fileinfo,filter,gd,hash,iconv,intl,json,libxml,luasandbox,mbstring,pcre,pdo,pdo_sqlite,random,reflection,session,simplexml,spl,sqlite3,standard,tokenizer,xml,xmlreader,xmlwriter,zend opcache,zlib/' \
    -e 's/^pdo .*/pdo sqlite/' \
    -e "s/^iconv e9 naive cafe /iconv e9 na\"ive caf'e /" \
    -e 's/^\(intl .*\) [0-9]* locales$/\1 79 locales/' \
    -e 's/^\(dom .*\) [0-9.]*$/\1 2.15.4/' \
    -e 's/^\(sqlite3 .*\) old$/\1 current/' > smoke.expected
rm -f "$tmp"
