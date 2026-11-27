+++
document = "SW-SRS"
revision = "Draft"
item = "PRD-10"
maturity = "D"
+++

# Software requirements specification

The software requirements (%[SWE-050]), each specific, testable and traceable, with how it is verified (handbook topic 5.09). Each is an item of the type `requirement`, `SRS-001` and on, linked by `derives` to the higher-level requirement it comes from and by `addresses` to the hazards it is part of; its verification method is `verification=`.

## Introduction

This specification covers three software components:

- **Wiki service**: the container image, entrypoint, settings file and compose stack. Implemented.
- **Offline viewer**: the standalone Windows executable. In design; feasibility work is under way.
- **Media store**: the single-file media format, its server-side mount and its reader. In design.

Higher-level requirements are in [system-requirements.md](system-requirements.md). All items are drafts until reviewed.

## Functional requirements

### Wiki service

%requirement[SRS-001 functional verification=test derives=SYS-001] The image shall run MediaWiki 1.43 (LTS) with Semantic MediaWiki and Wikibase repository and client enabled together.

%requirement[SRS-002 functional verification=test derives=SYS-002] The wiki service shall keep the main database, object cache, localization cache and job queue in SQLite files in one data directory.

%requirement[SRS-003 functional verification=test derives=SYS-003] On first run, when no database file exists, the entrypoint shall install MediaWiki on SQLite and create the administrator account, taking the password from a file and never from a command-line argument.

%requirement[SRS-004 functional verification=test derives=SYS-003] On first run the entrypoint shall generate a secret key and persist it in the data volume if none is supplied.

%requirement[SRS-005 functional verification=test derives=SYS-001 rationale="A single update with both extensions enabled fails on a fresh database."] The entrypoint shall run the schema update with Semantic MediaWiki disabled before running it with Semantic MediaWiki enabled whenever the Wikibase table `wb_items_per_site` is missing, so that an interrupted first run recovers.

%requirement[SRS-006 functional verification=test derives=SYS-003] On later runs the entrypoint shall run the schema update before starting the web server, unless disabled by `MW_AUTO_UPDATE`.

%requirement[SRS-007 functional verification=inspection derives=SYS-003] Maintenance shall run as `www-data`, and the entrypoint shall fix the ownership of the data and images volumes.

%requirement[SRS-008 functional verification=test derives=SYS-003] The image shall provide a `jobrunner` command that runs the job queue in a loop and performs no initialization.

%requirement[SRS-009 functional verification=test derives=SYS-001 rationale="Both extensions register a namespace named Property."] Wikibase properties shall live in a namespace distinct from Semantic MediaWiki's `Property` namespace, named by `WB_PROPERTY_NAMESPACE` (default `WbProperty`).

%requirement[SRS-010 functional verification=test derives=SYS-005] When `MW_READ_ONLY` is set to a message, page reads, searches, semantic queries and Wikibase reads shall work, edits shall be refused with that message, and the schema update and job runner shall not run.

%requirement[SRS-011 functional verification=test derives=SYS-001 rationale="A per-container cache served stale property types to the web container."] The web and job runner processes shall share one main object cache.

### Offline viewer

%requirement[SRS-020 functional verification=demonstration derives=SYS-006,SYS-010] The offline viewer shall run MediaWiki, Semantic MediaWiki and Wikibase in-process against the database file, rendering each page and evaluating each query when it is requested.

%requirement[SRS-021 functional verification=test derives=SYS-006] The offline viewer shall read the wiki database from the SQLite file that accompanies the executable; the data shall not be built into the executable.

%requirement[SRS-022 functional verification=test derives=SYS-011] The offline viewer shall open the wiki database read-only, and the file's content shall be byte-for-byte unchanged after any session.

%requirement[SRS-023 functional verification=test derives=SYS-011] The offline viewer shall create a scratch folder next to the database file and keep its caches there, including a secondary SQLite cache database.

%requirement[SRS-024 functional verification=inspection derives=SYS-009] The offline viewer shall answer the page's requests in-process and shall open no listening socket.

%requirement[SRS-025 functional verification=inspection derives=SYS-007] The offline viewer shall be one executable file containing the PHP runtime, the MediaWiki code and its settings. MediaWiki's code shall be read from inside the executable; files may be cached in the scratch folder.

%requirement[SRS-026 functional verification=test derives=SYS-006] The offline viewer shall have built in every setting the container image uses, with the read-only offline profile on top, and shall refuse a database whose MediaWiki version does not match its own.

%requirement[SRS-027 functional verification=demonstration derives=SYS-012] Scribunto Lua modules shall run in the offline viewer without starting an external program.

%requirement[SRS-031 functional verification=test derives=SYS-012] Scribunto's CPU-time limit on Lua scripts shall be enforced in the offline viewer.

%requirement[SRS-032 functional verification=test derives=SYS-012] The Math extension shall be enabled in the wiki service and in the offline viewer, rendering formulas without an external service.

%requirement[SRS-028 functional verification=inspection derives=SYS-013] The offline viewer shall ship a prebaked English localization cache.

%requirement[SRS-029 functional verification=test derives=SYS-012] Thumbnails shall be generated offline with PHP's own image library; ImageMagick shall not be required.

%requirement[SRS-030 interface verification=test derives=SYS-012] Features that need Python (syntax highlighting) shall use the interpreter named by the environment variable `MEDIAWIKI_PYTHON` when it is set, and otherwise the Python found on the system path. The offline viewer shall not supply Python.

### Media store

%requirement[SRS-040 functional verification=test derives=SYS-014] Uploaded media shall be stored in a single SQLite file, with each file's content split into chunks.

%requirement[SRS-041 functional verification=test derives=SYS-016] Each chunk shall be compressed independently, and stored uncompressed when compression does not make it smaller.

%requirement[SRS-042 functional verification=test derives=SYS-014] On the server the media file shall be presented to MediaWiki and the web server as an ordinary directory through a FUSE mount, so that the web server serves media files directly.

%requirement[SRS-043 functional verification=test derives=SYS-014] The FUSE daemon shall be supervised and restarted if it exits.

%requirement[SRS-044 functional verification=test derives=SYS-014,SYS-008] The offline viewer shall read media from the single-file media store that accompanies the database, directly, without a mount and without privileges beyond those of a basic user. Its first release shall do so; it shall not fall back to a folder of loose files.

%requirement[SRS-045 functional verification=inspection derives=SYS-014] Generated thumbnails shall be kept outside the media file: in a cache directory on the server and in the scratch folder offline.

%requirement[SRS-046 functional verification=inspection derives=SYS-014] The server and the offline viewer shall use one shared implementation of the media file format.

## Performance and quality requirements

%requirement[SRS-060 performance verification=test derives=SYS-016] Reading media shall support seeking to any offset without decompressing the whole file.

%requirement[SRS-061 performance verification=analysis derives=SYS-017] The media file format shall have no size limit below one terabyte for the store, and none on an individual file below the store's limit.

%requirement[SRS-062 quality verification=demonstration derives=SYS-015] A consistent snapshot of the database file and of the media file shall be obtainable while the wiki service is running.

## Interface requirements

%requirement[SRS-070 interface verification=inspection derives=SYS-004] Every setting of the wiki service listed in `.env.example` shall be read from an environment variable with a documented default.

%requirement[SRS-071 interface verification=inspection derives=SYS-003,SYS-015] The compose file shall define a `wiki` service and a `jobrunner` service that share the image and the data and media volumes, with the job runner waiting for the wiki to be healthy.

%requirement[SRS-072 interface verification=test derives=SYS-003] The image shall define a health check.

%requirement[SRS-073 interface verification=demonstration derives=SYS-008] The offline viewer's window shall be built with direct Win32 calls, with page content shown by the WebView2 runtime of Windows 11, which is assumed present.

## Design and implementation constraints

%[SWE-184].

%requirement[SRS-080 constraint verification=inspection derives=SYS-003] The image shall be based on the official `mediawiki:1.43` image, with the settings file outside the web root.

%requirement[SRS-081 constraint verification=inspection derives=SYS-018,SYS-019] The PHP runtime of the offline viewer shall be built by the project's own `build.zig` from the official signed PHP release, fetched as a dependency pinned by hash in `build.zig.zon`.

%requirement[SRS-082 constraint verification=inspection derives=SYS-018] Every third-party library linked into the offline viewer or the media store shall be fetched at build time from its official release, pinned by content hash in the build manifest, and built from source by the project's build.

%requirement[SRS-083 constraint verification=inspection derives=SYS-020] Released builds of the offline viewer shall be code-signed in the release pipeline, with a trusted timestamp, and the pipeline shall verify the signature.

%requirement[SRS-084 constraint verification=inspection derives=SYS-015 rationale="The owner controls the host VM."] The wiki container may be granted the capability and device access that FUSE needs.

%requirement[SRS-086 constraint verification=inspection derives=SYS-019] Native components shall build for Windows with the toolchain Zig bundles, without the Microsoft compiler or SDK installed.

%requirement[SRS-087 constraint verification=test derives=SYS-018] The offline PHP shall build its fiber context-switch routines from PHP's own sources; the routines shall not be copied from another project. Fibers shall be covered by the build's tests.

%requirement[SRS-088 constraint verification=inspection derives=SYS-018 rationale="The project prefers permissive licenses; GPL and LGPL components are accepted where the wiki requires them."] A third-party component under a copyleft license shall be used only where no permissively licensed alternative meets the need, and each such component shall be listed with its license.

%requirement[SRS-089 interface verification=demonstration derives=SYS-003,SYS-007] A release shall be published from GitHub Actions with two separate packages: a zip of only the files needed to deploy the wiki service, and the Windows executable. The container image itself shall not be built or published by the release.

%requirement[SRS-090 constraint verification=inspection derives=SYS-018] Each release shall include a software bill of materials naming every third-party component, its version, license and source. It shall be generated from the build's own dependency manifest.

%requirement[SRS-091 constraint verification=inspection derives=SYS-021] The project's own code shall be under the MIT license.

%requirement[SRS-092 constraint verification=inspection derives=SYS-018] A release shall carry SHA-256 checksums of its files and a detached GPG signature of the checksum file, verifiable with a public key kept in the repository.

%requirement[SRS-093 constraint verification=inspection derives=SYS-021] The project's license shall be a release artifact, and the package of the offline viewer shall contain the license text of every third-party component in it.

%requirement[SRS-085 constraint verification=inspection derives=SYS-021] Requirements shall be kept as Skein items in this repository and `skein check` shall report no problems.

## Qualification provisions

How each requirement is verified: test, analysis, inspection or demonstration, each with its criteria. The [traceability](traceability.md) page shows each requirement with what verifies it.

## Rationale, assumptions and limitations

- The WebView2 runtime is assumed present on the target machines until shown otherwise.
- Python is assumed to be available on the target machines.
- The executable is expected to be large; size is not constrained.
- Media volumes of a terabyte or more are not an initial concern.
