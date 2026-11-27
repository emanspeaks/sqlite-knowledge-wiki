# Notes for coding agents

What a coding agent working on sqlite-knowledge-wiki needs to know besides the code, the [readme](README.md) and the requirements (`docs/`). Notes about one machine (paths, hosts, caches) go in `CLAUDE.local.md`, which is not committed. Mistakes made more than once are written down here so they are not made again.

The repository's setup follows skein (chasingdaylight/skein) and zfls (cesiumlang/zfls): when something here is missing, do it as they do.

## What this is

A team wiki (MediaWiki with Semantic MediaWiki and Wikibase) on SQLite, in two parts:

- **The wiki service**: the container image, its entrypoint, `LocalSettings.php` and the compose file, at the root. Built where it is deployed; CI does not build the image.
- **The offline viewer** (`offline/`): a single Windows executable that runs the same wiki in-process against a copy of the SQLite file, for when the server is down. `offline/php` builds PHP and every library it needs with Zig alone; `offline/vfs` is the Linux prototype of the virtual filesystem that serves MediaWiki's code from one file. The viewer itself is not written yet: the release's Windows program is the PHP runtime's test program.

## Requirements

- `docs/system-requirements.md` (`SYS-`) and `docs/srs.md` (`SRS-`) hold the requirements, in Skein's format, with the NPR 7150.2D template at Class C (`.skein/config.toml`); `AGENTS.md` explains the format. `standards/npr7150.2d/` is the standard's text, read-only.
- A change to what the software does changes its requirement in the same pull request. A requirement that goes away keeps its marker with the status `removed`; an ID is never changed or used again.
- A decision emanspeaks makes in a conversation that changes what the software must do becomes a requirement, or changes one, before the work it decides.
- `docs/maintenance-plan.md` lists every part of the PHP build kept by hand; a new one goes there in the same change.

## Rules

- Third-party code is built from the official release of a pinned version, fetched at build time and checked against the hash in `offline/php/build.zig.zon`; fetched sources are never committed. Each fetched component has an entry in `offline/php/components.zig` (the build refuses one without), which the SBOM and the license texts come from.
- Prebuilt binaries are accepted only from the software's official publisher.
- The wiki service's image is pinned the same way: images by digest and Wikibase by commit in the `Dockerfile`, Composer packages by `composer/composer.lock`, Debian packages by `DEBIAN_SNAPSHOT`. A new pin comes with a new lock and a new `image/inventory.tsv` (README, "Upgrading"); CI's Server job writes each as an artifact when it is missing or stale, since no machine here runs Docker.
- Zig, built with the pinned official release (0.17.1, `ZIG_VERSION` in `ci.yml`), for build steps and tools. Scratch scripts an agent writes to analyze something may be in any language and stay in its scratchpad, never committed.
- Never run a command that downloads or installs software without asking first, package managers included (markdownlint through `npx` excepted). The build's own fetch of the pinned releases is not such a command.
- The repository owner is `emanspeaks` in every file, issue and pull request; write `@emanspeaks` only to ask for his input.
- Licenses: this repository's own code is MIT. GPL and LGPL components are accepted where the wiki needs them (MediaWiki and its extensions; libmbfl and libbcmath inside PHP); anything else should be MIT-compatible.

## Git

- `main` and `dev`. Work goes on a branch from `dev` and reaches `dev` through a pull request; `main` only takes releases, through the standing `dev` to `main` pull request, which emanspeaks merges.
- A release is made by CI when `main` gets a version (`VERSION`) that has no tag and something a release ships has changed since the last tag (`.github/workflows/changes.sh`; not documentation, CI or editor settings alone: `docs-only.txt`, `ci-only.txt` and `no-ci.txt` beside it). It tags the commit, publishes the packages, and begins the next patch version on `dev`. `.github/workflows/version.sh` reads and sets the version. Never tag or publish by hand.
- This is emanspeaks's own repository: the GitHub Apps the agents use for chasingdaylight and cesiumlang repositories cannot act on it. Commits, pushes and pull requests are made with his own git and gh logins, and only when he says so; otherwise stage the change and write the commit message.
- Commit messages are one short line (about 50 characters), with no body; rationale and test results go in the pull request or the issue.
- Before a commit, check `git diff --cached` and `git status` so a commit takes only your own changes.
- After a merge, delete the branch, locally and on GitHub.
- `.local-gitignore` is this checkout's own ignore file (`git config core.excludesFile .local-gitignore`).

## Signing

- Release signing is configured as in skein and zfls: `sign-windows` in `ci.yml` signs the program with Azure Artifact Signing, and the release job signs `SHA256SUMS` with GPG and attests the files, each while its repository variable is set. They run only for a release, or a run started by hand with `-f sign=true`; never for a pull request (signings are limited per month).
- The GPG key is the shared Chasing Daylight release signing key; `SIGNING-KEY.asc` is its public half.
- The global `sign-ci-setup` skill sets them up, and `sign-local` signs a local build. The account details are outside the repository, where the global `CLAUDE.md` says; never copy them in.

## Style

- `.editorconfig` is authoritative. Zig: four spaces, as `zig fmt` writes them; everything else two.
- The code style of the global `CLAUDE.md` applies: files under 1000 lines (ideally 500), one per logical unit; `try`, never `catch @panic("OOM")`; sparse, terse comments; no em dashes; American English.
- Zig 0.17: the global `zig` skill lists what 0.15 to 0.18 removed or renamed; skein's `CLAUDE.md` has a table of the deprecated declarations and their replacements.
- Markdown: one line per paragraph or list item, no hard wraps; no markdownlint warnings.

## Commands

- Never write a redirect that can create a `nul` file: `/dev/null` in Bash, `$null` in PowerShell.
- Search with `rg` (with an explicit path) or the Grep tool, excluding `zig-pkg`, `.zig-cache` and `zig-out`.
- Kill only processes you started, matched by their own command line.

## Checks before a pull request

Tests cite the requirements they verify (`// verifies:` in `offline/php/test/smoke.php`, `# verifies:` in `tests/server/check.sh`), and `docs/test-procedures.md` holds them as procedures; a new check of a requirement adds both. Every check records a Skein result (`tests/result.sh`), which CI's Results job turns into the coverage a release publishes. `bash tools/agent/check.sh` runs what CI runs: the version, `zig fmt --check`, markdownlint, `skein check`, the PHP build and its test script (`--quick` skips the build, which takes tens of minutes the first time). CI does not run on pull requests into `dev` (only on those into `main`, and when started by hand: `gh workflow run ci.yml --ref BRANCH`), so these checks are what stands between a change and `dev`; say in the pull request which were run.

## Traps met before

- On Windows, a full parallel build of `offline/php` can fail with `SystemResources` or clang exit codes 45 and 66 while spawning compilers: build with `-j6`.
- A Windows checkout must keep LF line endings (`.gitattributes`): the patches must match PHP's sources byte for byte.
- A static build never runs PHP's `DllMain`: what `win32/dllmain.c` initializes is done in `offline/php/compat/static_init.inc`, and a constructor in a file of its own is dropped by the linker.
- zlib.net has answered CI runners with an HTML page; zlib comes from its author's GitHub release.
