# sqlite-knowledge-wiki

A containerized team wiki: **MediaWiki 1.43 LTS + Semantic MediaWiki 7.4 +
Wikibase (repo and client)**, with **SQLite as the only database**. No MySQL or
MariaDB anywhere. Configuration comes from environment variables.

| Component | Version |
|---|---|
| MediaWiki | 1.43 (official `mediawiki:1.43` image, PHP 8.3) |
| Semantic MediaWiki | `~7.4` from Packagist (build arg `SMW_VERSION`) |
| Wikibase | branch `REL1_43` with its JavaScript submodules (build arg `WIKIBASE_BRANCH`) |

## Quick start

```bash
cp .env.example .env
```

Edit `.env`: set `MW_SERVER` to the public URL and `MW_ADMIN_PASSWORD` to a
password of at least 10 characters. Then:

```bash
docker compose up --build -d
```

The first start installs MediaWiki, creates the admin account and builds the
SMW and Wikibase tables; `docker compose ps` shows `healthy` when it is done.
The wiki listens on `127.0.0.1:8080` (change with `WIKI_BIND`).

Two services share one image and two named volumes:

- `wiki` — Apache + PHP. Initializes or updates the database on start.
- `jobrunner` — runs MediaWiki's job queue in a loop. It starts once `wiki` is
  healthy. SMW and Wikibase both depend on jobs running, so keep it.
- `wiki-data` volume → `/var/www/data`: the SQLite files and the secret key.
- `wiki-images` volume → `/var/www/html/images`: uploads.

### Behind a reverse proxy

`MW_SERVER` must be the URL users type, including `https://`. Proxy to the
published port and pass the client address:

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    client_max_body_size 100m;
}
```

Set `MW_TRUSTED_PROXIES` to the address the proxy connects from (as seen inside
the container, usually the Docker bridge range) so MediaWiki logs real client
IPs instead of the proxy's.

## Environment variables

`.env.example` is the reference; every variable is documented there. Booleans
accept `1`/`true`/`yes`/`on`.

| Variable | Default | Purpose |
|---|---|---|
| `MW_SERVER` | *(required)* | Public URL of the wiki |
| `MW_SITE_NAME` | `Wiki` | Site name |
| `MW_SCRIPT_PATH` | *(empty)* | URL path prefix, e.g. `/w`; empty = site root |
| `MW_LANG` | `en` | Content language |
| `MW_TIMEZONE` | `UTC` | Local timezone |
| `MW_SKIN` | `vector-2022` | Default skin |
| `MW_LOGO`, `MW_LOGO_ICON` | placeholder | Logo URLs |
| `MW_TRUSTED_PROXIES` | *(empty)* | Proxy IPs/CIDRs trusted for `X-Forwarded-For` |
| `MW_ADMIN_USER` | `Admin` | First run only: admin account name |
| `MW_ADMIN_PASSWORD` | *(required on first run)* | First run only; min. 10 characters |
| `MW_ADMIN_PASSWORD_FILE` | | Alternative: path to a file holding the password |
| `MW_DB_NAME` | `wiki` | Database is `<MW_DATA_DIR>/<MW_DB_NAME>.sqlite` |
| `MW_DATA_DIR` | `/var/www/data` | Data directory in the container (must match the volume mount) |
| `MW_SECRET_KEY` | auto | If unset, generated once and kept in `<MW_DATA_DIR>/secret.key` |
| `MW_PRIVATE` | `false` | Login required to read |
| `MW_ALLOW_REGISTRATION` | `false` | Visitors may create accounts |
| `MW_ALLOW_ANON_EDIT` | `false` | Editing without an account |
| `MW_READ_ONLY` | *(empty)* | Non-empty text = read-only mode with that message |
| `MW_ENABLE_UPLOADS` | `false` | File uploads |
| `MW_ENABLE_EMAIL` | `false` | Email features |
| `MW_EMAIL_SENDER`, `MW_SMTP_HOST`, `MW_SMTP_PORT`, `MW_SMTP_USER`, `MW_SMTP_PASSWORD` | | Sender and SMTP relay (the container has no local mailer) |
| `MW_EXTENSIONS` | see `.env.example` | Comma list of bundled extensions to load |
| `MW_ENABLE_SMW` | `true` | Semantic MediaWiki |
| `MW_ENABLE_WIKIBASE` | `true` | Wikibase repo + client |
| `WB_ITEM_NAMESPACE` | `Item` | Name of the Wikibase item namespace (ID 120) |
| `WB_PROPERTY_NAMESPACE` | `WbProperty` | Name of the Wikibase property namespace (ID 122) |
| `MW_JOB_RUN_RATE` | `0` | Jobs per page view; keep `0` with the jobrunner service |
| `MW_JOB_INTERVAL` | `10` | Seconds between jobrunner passes |
| `MW_AUTO_UPDATE` | `true` | Run `update.php --quick` on every start |
| `MW_DEBUG` | `false` | Show exception details (not for production) |
| `WIKI_BIND` | `127.0.0.1:8080` | Host address the wiki is published on (compose only) |
| `MEDIAWIKI_IMAGE`, `SMW_VERSION`, `WIKIBASE_BRANCH` | `mediawiki:1.43`, `~7.4`, `REL1_43` | Build arguments |

The Math extension is on by default and renders formulas to MathML inside PHP (`native` mode); it needs no rendering service. The image's PHP already has the multibyte regular-expression support it uses.

Settings that have no variable go in a PHP file mounted into
`/etc/mediawiki/conf.d/`; every `*.php` there is loaded at the end of
`LocalSettings.php`.

### Read-only mode

`MW_READ_ONLY=<message>` sets `$wgReadOnly`. Reading, searching, `#ask` queries
and Wikibase reads keep working; every edit is refused with the message. The
entrypoint also skips `update.php` and the jobrunner idles, so nothing writes
wiki content. Logging in still works through the web form; the API's
`clientlogin` is refused (MediaWiki treats it as a write).

MediaWiki still writes to its cache database (`wikicache.sqlite`) and the main
database stays in WAL mode, so the data directory itself must remain writable.

## Maintenance commands

```bash
docker compose exec -u www-data wiki php maintenance/run.php <script> [args]
```

Always pass `-u www-data`, so nothing in the data volume ends up owned by root.

## Backup

The database runs in SQLite's WAL mode: recent writes live in
`wiki.sqlite-wal` until they are checkpointed. **Do not copy `wiki.sqlite` on
its own while the wiki is running** — the copy can be missing data or be
inconsistent. Use one of these instead.

**Online (wiki keeps running).** SQLite's backup API takes a consistent
snapshot:

```bash
docker compose exec -u www-data wiki sh -c 'mkdir -p /var/www/data/backup && sqlite3 /var/www/data/wiki.sqlite ".backup /var/www/data/backup/wiki.sqlite" && cp /var/www/data/secret.key /var/www/data/backup/'
```

```bash
docker compose cp wiki:/var/www/data/backup ./backup
```

**Offline.** Stop both services, then copy the whole volume, WAL files included:

```bash
docker compose stop
```

```bash
docker run --rm -v sqlite-knowledge-wiki_wiki-data:/data:ro -v "$PWD":/out alpine tar czf /out/wiki-data.tgz -C /data .
```

```bash
docker compose start
```

What matters: `wiki.sqlite` (all content, users, SMW and Wikibase data),
`secret.key` (unless you set `MW_SECRET_KEY`), and the `wiki-images` volume if
uploads are enabled. `wikicache.sqlite` and `wiki_l10n_cache.sqlite` are caches
and are rebuilt; `wiki_jobqueue.sqlite` holds only pending jobs.

**Restore.** Stop the services, put `wiki.sqlite` (and `secret.key`) back in the
data volume, delete any stale `wiki.sqlite-wal` and `wiki.sqlite-shm`, start
again. Check a database with:

```bash
docker compose exec -u www-data wiki sqlite3 /var/www/data/wiki.sqlite "PRAGMA integrity_check;"
```

## Upgrading

1. Take a backup.
2. Rebuild. For patch releases of the same MediaWiki line:

   ```bash
   docker compose build --pull --no-cache
   ```

   For a new MediaWiki release line, set `MEDIAWIKI_IMAGE` and a matching
   `WIKIBASE_BRANCH` (Wikibase branches track MediaWiki releases, e.g.
   `REL1_43`), and an `SMW_VERSION` that supports it.
3. Recreate the containers:

   ```bash
   docker compose up -d
   ```

   The entrypoint runs `update.php --quick` on start (`MW_AUTO_UPDATE=true`),
   which applies schema changes for core, SMW and Wikibase.

## Two gotchas this image handles

Neither is specific to SQLite; both bite any install that combines SMW with
Wikibase.

**1. Install order.** Running `update.php` once with both extensions enabled on
a fresh database fails: SMW creates pages before Wikibase's tables exist, and a
Wikibase client hook queries the missing `wb_items_per_site` table. The
entrypoint runs `update.php` with SMW disabled first, then again with SMW
enabled. It decides by checking whether `wb_items_per_site` exists, so an
interrupted first run recovers, and enabling Wikibase later on an existing wiki
works too.

**2. Namespace clash.** SMW and Wikibase both register a namespace named
"Property" (SMW at 102, Wikibase at 122). SMW wins, and creating a Wikibase
property throws `PageAssertionException ... Special:Badtitle/NS122:P1`. Setting
`$wgExtraNamespaces[122]` alone does not fix it, because Wikibase's
default-namespace hook overwrites it later. `LocalSettings.php` therefore sets
`$wgWBRepoSettings['defaultEntityNamespaces'] = false` and declares the entity
namespaces and the entity source by hand. The result:

- `Property:Has mass` — a Semantic MediaWiki property
- `WbProperty:P1` — a Wikibase property (rename with `WB_PROPERTY_NAMESPACE`)
- `Item:Q1` — a Wikibase item

A third thing worth knowing: the main object cache is the shared SQLite cache
(`CACHE_DB`), not APCu. The jobrunner is a separate container, and with a
per-container APCu cache the web container kept serving stale SMW property
types after the jobrunner had updated them.

## Build notes

- Wikibase's editing UI lives in git submodules; the Dockerfile fetches them at
  full depth with retries, because some are hosted on Wikimedia's Phabricator,
  which rejects shallow fetches and rate-limits.
- `install.php` refuses to run when it finds a `LocalSettings.php`, so the
  first-run install runs with `MW_CONFIG_FILE` unset and writes its generated
  settings to a throwaway directory. The real settings file is baked into the
  image at `/etc/mediawiki/LocalSettings.php`, outside the web root.
- Other entrypoint commands: `jobrunner` (job loop, no initialization) and any
  other command, which is executed as given.

## Releases

`VERSION` holds the next release's version. A push to `main` with an untagged version is built, tested on Windows, packaged and published by `.github/workflows/release.yml`. A release has:

- `sqlite-knowledge-wiki-vX-server.zip`: the files to deploy the wiki service (the image is built where it is deployed, with `docker compose up --build`).
- the Windows program, as its own zip.
- `sqlite-knowledge-wiki-vX-sbom.cdx.json`: the bill of materials (CycloneDX), with every third-party component's version, licence, source and checksum. `zig build sbom` in `offline/php` writes it.
- `SHA256SUMS`.

## Licence

The code in this repository is under the MIT licence (`LICENSE`). The software it builds and deploys has licences of its own, listed in the bill of materials: MediaWiki, Semantic MediaWiki and Wikibase are GPL-2.0-or-later, and two libraries inside PHP are LGPL.
