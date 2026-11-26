<?php
/**
 * LocalSettings.php driven entirely by environment variables.
 *
 * Every variable is documented in .env.example. Site-specific PHP that cannot
 * be expressed as a variable goes in /etc/mediawiki/conf.d/*.php, which is
 * loaded at the end of this file.
 */

if ( !defined( 'MEDIAWIKI' ) ) {
	exit;
}

// Maintenance scripts can load this file more than once.
if ( !function_exists( 'wikiEnv' ) ) {
	/** String variable; unset or empty falls back to the default. */
	function wikiEnv( string $name, ?string $default = null ): ?string {
		$value = getenv( $name );
		return ( $value === false || $value === '' ) ? $default : $value;
	}

	/** Boolean variable: 1/true/yes/on are true (case-insensitive), anything else false. */
	function wikiEnvBool( string $name, bool $default ): bool {
		$value = wikiEnv( $name );
		if ( $value === null ) {
			return $default;
		}
		return in_array( strtolower( trim( $value ) ), [ '1', 'true', 'yes', 'on' ], true );
	}

	/** Comma-separated list variable. */
	function wikiEnvList( string $name, string $default = '' ): array {
		return array_values( array_filter( array_map( 'trim',
			explode( ',', wikiEnv( $name, $default ) ) ), 'strlen' ) );
	}
}

## ---------------------------------------------------------------- Site

$wgSitename = wikiEnv( 'MW_SITE_NAME', 'Wiki' );

$wgServer = wikiEnv( 'MW_SERVER' );
if ( $wgServer === null ) {
	// Let MediaWiki fail with its own "must be set" error for web requests,
	// but say something useful on the command line.
	if ( PHP_SAPI === 'cli' ) {
		fwrite( STDERR, "MW_SERVER is not set. Set it to the public URL of the wiki.\n" );
		exit( 1 );
	}
	unset( $wgServer );
} else {
	$wgServer = rtrim( $wgServer, '/' );
}

$wgScriptPath = rtrim( wikiEnv( 'MW_SCRIPT_PATH', '' ), '/' );
$wgResourceBasePath = $wgScriptPath;

$wgLogos = [
	'1x' => wikiEnv( 'MW_LOGO', "$wgResourceBasePath/resources/assets/change-your-logo.svg" ),
	'icon' => wikiEnv( 'MW_LOGO_ICON', "$wgResourceBasePath/resources/assets/change-your-logo-icon.svg" ),
];

$wgLanguageCode = wikiEnv( 'MW_LANG', 'en' );
$wgLocaltimezone = wikiEnv( 'MW_TIMEZONE', 'UTC' );

foreach ( [ 'MinervaNeue', 'MonoBook', 'Timeless', 'Vector' ] as $wikiSkin ) {
	if ( is_file( "$IP/skins/$wikiSkin/skin.json" ) ) {
		wfLoadSkin( $wikiSkin );
	}
}
$wgDefaultSkin = wikiEnv( 'MW_SKIN', 'vector-2022' );

// Reverse proxies whose X-Forwarded-For header is trusted (IPs or CIDR ranges).
$wgCdnServersNoPurge = wikiEnvList( 'MW_TRUSTED_PROXIES' );

## ---------------------------------------------------------------- Storage (SQLite only)

$wgDBtype = 'sqlite';
$wgDBserver = '';
$wgDBname = wikiEnv( 'MW_DB_NAME', 'wiki' );
$wgDBuser = '';
$wgDBpassword = '';
$wgSQLiteDataDir = rtrim( wikiEnv( 'MW_DATA_DIR', '/var/www/data' ), '/' );

// The three blocks below are what the MediaWiki 1.43 installer generates for
// SQLite: caches, the localisation cache and the job queue each get their own
// database file so they do not contend with the main database for its lock.
$wgObjectCaches[CACHE_DB] = [
	'class' => SqlBagOStuff::class,
	'loggroup' => 'SQLBagOStuff',
	'server' => [
		'type' => 'sqlite',
		'dbname' => 'wikicache',
		'tablePrefix' => '',
		'variables' => [ 'synchronous' => 'NORMAL' ],
		'dbDirectory' => $wgSQLiteDataDir,
		'trxMode' => 'IMMEDIATE',
		'flags' => 0
	]
];
$wgLocalisationCacheConf['storeServer'] = [
	'type' => 'sqlite',
	'dbname' => "{$wgDBname}_l10n_cache",
	'tablePrefix' => '',
	'variables' => [ 'synchronous' => 'NORMAL' ],
	'dbDirectory' => $wgSQLiteDataDir,
	'trxMode' => 'IMMEDIATE',
	'flags' => 0
];
$wgJobTypeConf['default'] = [
	'class' => 'JobQueueDB',
	'claimTTL' => 3600,
	'server' => [
		'type' => 'sqlite',
		'dbname' => "{$wgDBname}_jobqueue",
		'tablePrefix' => '',
		'variables' => [ 'synchronous' => 'NORMAL' ],
		'dbDirectory' => $wgSQLiteDataDir,
		'trxMode' => 'IMMEDIATE',
		'flags' => 0
	]
];
$wgResourceLoaderUseObjectCacheForDeps = true;
$wgSharedTables[] = 'actor';

// The web container and the jobrunner are separate processes in separate
// containers, so the main cache must be one they share. APCu (CACHE_ACCEL) is
// per-container: SMW would keep serving stale property types from it after the
// jobrunner changed them. MediaWiki still uses APCu for its local-server cache.
$wgMainCacheType = CACHE_DB;
$wgSessionCacheType = CACHE_DB;
$wgMemCachedServers = [];

## ---------------------------------------------------------------- Secrets

// MW_SECRET_KEY wins; otherwise the entrypoint generates one on first run and
// keeps it in the data volume.
$wgSecretKey = wikiEnv( 'MW_SECRET_KEY' );
if ( $wgSecretKey === null && is_readable( "$wgSQLiteDataDir/secret.key" ) ) {
	$wgSecretKey = trim( file_get_contents( "$wgSQLiteDataDir/secret.key" ) );
}
if ( !$wgSecretKey ) {
	if ( PHP_SAPI === 'cli' ) {
		fwrite( STDERR, "No secret key: set MW_SECRET_KEY or let the entrypoint create "
			. "$wgSQLiteDataDir/secret.key.\n" );
	} else {
		http_response_code( 500 );
		echo "Wiki is not initialised: no secret key.";
	}
	exit( 1 );
}
$wgAuthenticationTokenVersion = '1';
// The web installer/upgrader is not used; updates run from the entrypoint.
$wgUpgradeKey = false;

## ---------------------------------------------------------------- Access

if ( wikiEnvBool( 'MW_PRIVATE', false ) ) {
	$wgGroupPermissions['*']['read'] = false;
	$wgGroupPermissions['*']['edit'] = false;
}
if ( !wikiEnvBool( 'MW_ALLOW_ANON_EDIT', false ) ) {
	$wgGroupPermissions['*']['edit'] = false;
	$wgGroupPermissions['*']['createpage'] = false;
	$wgGroupPermissions['*']['createtalk'] = false;
}
if ( !wikiEnvBool( 'MW_ALLOW_REGISTRATION', false ) ) {
	// Admins can still create accounts through Special:CreateAccount.
	$wgGroupPermissions['*']['createaccount'] = false;
	$wgGroupPermissions['*']['autocreateaccount'] = false;
}

// Any non-empty message puts the wiki in read-only mode.
$wikiReadOnly = wikiEnv( 'MW_READ_ONLY' );
if ( $wikiReadOnly !== null ) {
	$wgReadOnly = $wikiReadOnly;
}

## ---------------------------------------------------------------- Features

$wgEnableUploads = wikiEnvBool( 'MW_ENABLE_UPLOADS', false );
if ( is_executable( '/usr/bin/convert' ) ) {
	$wgUseImageMagick = true;
	$wgImageMagickConvertCommand = '/usr/bin/convert';
}
$wgUseInstantCommons = false;
$wgPingback = false;
$wgDiff3 = '/usr/bin/diff3';

$wgEnableEmail = wikiEnvBool( 'MW_ENABLE_EMAIL', false );
$wgEnableUserEmail = $wgEnableEmail;
$wgEmergencyContact = wikiEnv( 'MW_EMAIL_SENDER', '' );
$wgPasswordSender = wikiEnv( 'MW_EMAIL_SENDER', '' );
$wgEnotifUserTalk = false;
$wgEnotifWatchlist = false;
$wgEmailAuthentication = true;
if ( $wgEnableEmail && wikiEnv( 'MW_SMTP_HOST' ) !== null ) {
	$wgSMTP = [
		'host' => wikiEnv( 'MW_SMTP_HOST' ),
		'IDHost' => wikiEnv( 'MW_SMTP_IDHOST', parse_url( wikiEnv( 'MW_SERVER', '' ), PHP_URL_HOST ) ?: 'localhost' ),
		'port' => (int)wikiEnv( 'MW_SMTP_PORT', '587' ),
		'auth' => wikiEnv( 'MW_SMTP_USER' ) !== null,
		'username' => wikiEnv( 'MW_SMTP_USER', '' ),
		'password' => wikiEnv( 'MW_SMTP_PASSWORD', '' ),
	];
}

// Bundled extensions. Names are directory names under extensions/.
foreach ( wikiEnvList( 'MW_EXTENSIONS',
	'Cite,ParserFunctions,WikiEditor,CodeEditor,SyntaxHighlight_GeSHi,VisualEditor,'
	. 'TemplateData,CategoryTree,Interwiki,Nuke,ReplaceText,Scribunto'
) as $wikiExtension ) {
	if ( in_array( $wikiExtension, [ 'SemanticMediaWiki', 'Wikibase' ], true ) ) {
		continue; // controlled by MW_ENABLE_SMW / MW_ENABLE_WIKIBASE below
	}
	if ( preg_match( '/^[A-Za-z0-9_-]+$/', $wikiExtension )
		&& is_file( "$IP/extensions/$wikiExtension/extension.json" )
	) {
		wfLoadExtension( $wikiExtension );
	} else {
		error_log( "MW_EXTENSIONS: skipping unknown extension '$wikiExtension'" );
	}
}
$wgPFEnableStringFunctions = true;
if ( extension_loaded( 'luasandbox' ) ) {
	$wgScribuntoDefaultEngine = 'luasandbox';
}

## ---------------------------------------------------------------- Semantic MediaWiki

if ( wikiEnvBool( 'MW_ENABLE_SMW', true ) ) {
	wfLoadExtension( 'SemanticMediaWiki' );
	// SMW records its schema/upgrade state in .smw.json. Keep it in the data
	// volume so it survives container replacement.
	$smwgConfigFileDir = $wgSQLiteDataDir;
}

## ---------------------------------------------------------------- Wikibase (repo + client)

if ( wikiEnvBool( 'MW_ENABLE_WIKIBASE', true ) ) {
	wfLoadExtension( 'WikibaseRepository', "$IP/extensions/Wikibase/extension-repo.json" );
	require_once "$IP/extensions/Wikibase/repo/ExampleSettings.php";
	wfLoadExtension( 'WikibaseClient', "$IP/extensions/Wikibase/extension-client.json" );
	require_once "$IP/extensions/Wikibase/client/ExampleSettings.php";

	// SMW and Wikibase both want a namespace called "Property" (SMW at 102,
	// Wikibase at 122). SMW wins, and Wikibase then cannot create properties.
	// Overriding $wgExtraNamespaces alone is not enough, because Wikibase's
	// default-namespace hook runs later and overwrites it. So: turn the
	// defaults off and declare the entity namespaces and entity source by hand.
	$wgWBRepoSettings['defaultEntityNamespaces'] = false;

	foreach ( [
		'WB_NS_ITEM' => 120,
		'WB_NS_ITEM_TALK' => 121,
		'WB_NS_PROPERTY' => 122,
		'WB_NS_PROPERTY_TALK' => 123,
	] as $wikiConstant => $wikiNamespaceId ) {
		if ( !defined( $wikiConstant ) ) {
			define( $wikiConstant, $wikiNamespaceId );
		}
	}

	$wikiItemNs = str_replace( ' ', '_', wikiEnv( 'WB_ITEM_NAMESPACE', 'Item' ) );
	$wikiPropertyNs = str_replace( ' ', '_', wikiEnv( 'WB_PROPERTY_NAMESPACE', 'WbProperty' ) );
	if ( strcasecmp( $wikiPropertyNs, 'Property' ) === 0 && wikiEnvBool( 'MW_ENABLE_SMW', true ) ) {
		// Would re-create the clash this block exists to avoid.
		$wikiPropertyNs = 'WbProperty';
	}

	$wgExtraNamespaces[WB_NS_ITEM] = $wikiItemNs;
	$wgExtraNamespaces[WB_NS_ITEM_TALK] = "{$wikiItemNs}_talk";
	$wgExtraNamespaces[WB_NS_PROPERTY] = $wikiPropertyNs;
	$wgExtraNamespaces[WB_NS_PROPERTY_TALK] = "{$wikiPropertyNs}_talk";
	$wgNamespacesToBeSearchedDefault[WB_NS_ITEM] = true;

	$wbEntitySources = [ 'local' => [
		'entityNamespaces' => [ 'item' => WB_NS_ITEM, 'property' => WB_NS_PROPERTY ],
		'repoDatabase' => false,
		'baseUri' => wikiEnv( 'MW_SERVER', '' ) . '/entity/',
		'rdfNodeNamespacePrefix' => 'wd',
		'rdfPredicateNamespacePrefix' => '',
		'interwikiPrefix' => '',
	] ];
	$wgWBRepoSettings['entitySources'] = $wbEntitySources;
	$wgWBClientSettings['entitySources'] = $wbEntitySources;
}

## ---------------------------------------------------------------- Operations

// 0 = page views never run jobs; the jobrunner service does.
$wgJobRunRate = (float)wikiEnv( 'MW_JOB_RUN_RATE', '0' );

if ( wikiEnvBool( 'MW_DEBUG', false ) ) {
	error_reporting( -1 );
	ini_set( 'display_errors', '1' );
	$wgShowExceptionDetails = true;
	$wgShowDBErrorBacktrace = true;
	$wgDevelopmentWarnings = true;
}

## ---------------------------------------------------------------- Local overrides

foreach ( glob( '/etc/mediawiki/conf.d/*.php' ) ?: [] as $wikiOverride ) {
	require $wikiOverride;
}
unset( $wikiSkin, $wikiExtension, $wikiConstant, $wikiNamespaceId, $wikiItemNs,
	$wikiPropertyNs, $wikiReadOnly, $wikiOverride );
