+++
document = "SYS-REQ"
revision = "Draft"
+++

# Higher-level requirements

What the project owner has asked of the system, as stated during design discussions. Each is an item of the type `system` (`SYS-001` and on). The software requirements in the [SRS](srs.md) derive from these.

## The wiki service

%system[SYS-001] The system shall provide a team wiki built on MediaWiki with Semantic MediaWiki and Wikibase (repository and client).

%system[SYS-002] The system shall use SQLite as its only database engine; no MySQL or MariaDB shall be required anywhere.

%system[SYS-003] The wiki service shall be delivered as a container image with a compose file, to run on the owner's web server behind a reverse proxy.

%system[SYS-004] The wiki service shall take its configuration from environment variables wherever possible.

%system[SYS-005] The wiki shall support a read-only mode in which reading and querying work and edits are refused.

## Offline access

%system[SYS-006] When the server is down or there is no network access, users shall still be able to navigate the wiki from a copy of its SQLite file.

%system[SYS-007] Offline access shall be provided by a single, fully portable, self-contained Windows executable: no installer, and no folder of sidecar files or dependencies.

%system[SYS-008] The offline viewer shall run on Windows 11 machines that are locked down and air-gapped, with basic user privileges.

%system[SYS-009] The offline viewer shall not host a server: it shall not listen on any network port, including the loopback interface.

%system[SYS-010] The offline viewer shall render pages and run queries on demand (live queries); pages and query results shall not be pre-rendered ahead of time.

%system[SYS-011] The offline viewer shall never write to the wiki database file it is given. Anything it must write shall go to a temporary folder it creates next to that file.

%system[SYS-012] Features of the wiki's extensions that pages depend on (for example Scribunto Lua modules) shall work in the offline viewer.

%system[SYS-013] The wiki supports a single language. Localisation may be fixed or prebaked.

## Media and backup

%system[SYS-014] Uploaded media shall be kept in one self-contained file, in a format that both the wiki service and the offline viewer use.

%system[SYS-015] The live database file and the media file shall be stored outside the container through a volume mount, so that a backup is a snapshot of those two files.

%system[SYS-016] Media storage shall support compression. Writing may be slow; reading shall be fast on both the server and the offline viewer.

%system[SYS-017] Media storage shall work at tens to hundreds of gigabytes. Whole-file backup is acceptable; incremental backup is not required.

## Supply chain and build

%system[SYS-018] Third-party code shall be built from the official sources of pinned versions, fetched at build time and checked against a recorded hash; the sources shall not be committed to this repository. Prebuilt binaries shall be accepted only from the official publisher of the software.

%system[SYS-019] Native components shall be built with the Zig build system as the C/C++ compiler and build tool.

%system[SYS-020] The offline viewer executable shall be code-signed with the owner's certificate.

## Process

%system[SYS-021] The project's requirements shall be tracked with Skein using the NPR 7150.2D template, as Class C software.
