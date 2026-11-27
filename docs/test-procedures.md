+++
document = "SW-STPR"
revision = "Draft"
item = "PRD-07"
maturity = "D"
+++

# Software test procedures

The test procedures and cases (%[SWE-065]), after handbook topic 5.14. Each is an item of the type `procedure`, `TST-001` and on, linked by `verifies` to the requirements it verifies; its results are recorded with `skein result` or a results file, and summarized in the [test report](test-report.md).

## Results

Both procedures record a result for each check they make, in Skein's TOML results format: `tests/result.sh` appends one, attributed to the test file (`offline/php/test/smoke.php` for TST-001, `tests/server/check.sh` for TST-002), so a result belongs to every requirement that file cites. `tests/smoke.sh` runs TST-001 and records it; `check.sh` records each of its checks when `RESULTS` names a file. CI's Results job gathers a run's results, and `skein coverage --results` gives the requirements they verified; a release publishes both as `test-results.toml` and `coverage.txt`. A result names the implementation `sqlite-knowledge-wiki` and the version in `VERSION`.

## Environment and schedule

Both procedures run in CI (`.github/workflows/ci.yml`) for every pull request into `main` and every push to it, on GitHub's hosted runners: TST-001 on Windows Server 2025 (`windows-2025`), TST-002 on Ubuntu 24.04 with Docker. `tools/agent/check.sh` runs TST-001 locally before a pull request into `dev`.

## Test cases

%procedure[TST-001 integration verifies=SRS-027 verifies=SRS-029 verifies=SRS-031 verifies=SRS-087] The offline viewer's PHP runtime, `offline/php/test/smoke.php`, run by the test program built for Windows (`php-embed-smoke.exe`), in a Debug build and a release build. Each line of its output is one check of an extension or of the engine: Lua called from PHP and back, its memory and CPU-time limits, thumbnails with GD, fibers switched by PHP's own routines, and the rest. It passes when the output is the same as `offline/php/test/smoke.expected`, line for line; the job fails otherwise, and on a crash the program prints a stack trace.

%procedure[TST-002 system verifies=SRS-001 verifies=SRS-002 verifies=SRS-003 verifies=SRS-004 verifies=SRS-005 verifies=SRS-006 verifies=SRS-008 verifies=SRS-009 verifies=SRS-010 verifies=SRS-011 verifies=SRS-032 verifies=SRS-072 verifies=SRS-095] The wiki service, `tests/server/check.sh`, against the image built from the `Dockerfile` and started with `docker compose`: a fresh install (the first run's setup, the admin login), then edits and the queries that must see them (a Semantic MediaWiki `#ask` on a numeric property after the jobrunner's jobs, a Wikibase property and item with a statement, `wbsearchentities`, `{{#statements}}`, a Lua module, a formula, full-text search), the data files and `PRAGMA integrity_check`; then a restart, after which the schema update has run, the same reads pass and nothing was installed again; then a restart with `MW_AUTO_UPDATE=false`, after which no update has run and the reads pass; then read-only mode, in which the reads pass and edits and logins are refused. It passes when every check passes (each prints `ok:`), the wiki becomes healthy within 15 minutes each time, and the image installs the committed Composer lock.
