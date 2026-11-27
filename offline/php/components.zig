//! What the SBOM says about each third-party component, beyond what
//! build.zig.zon already holds (where it is fetched from and its content
//! hash). `zig build sbom` fails if a dependency in build.zig.zon has no
//! entry here, so a new dependency cannot be added without one.
//!
//! Licences are SPDX identifiers. `sha256` is the published checksum of the
//! release archive, checked when the version was pinned; empty where the
//! source is a git tag, which `source_note` then identifies.

pub const Component = struct {
    /// The dependency's name in build.zig.zon; null for a component that is
    /// not fetched by this build.
    dependency: ?[]const u8 = null,
    name: []const u8,
    version: []const u8,
    license: []const u8,
    supplier: []const u8,
    purpose: []const u8,
    sha256: []const u8 = "",
    /// Where it comes from, for a component not in build.zig.zon.
    source: []const u8 = "",
    source_note: []const u8 = "",
    /// The file in the component's release that holds its licence, for a
    /// fetched component. Empty where the release has none.
    license_file: []const u8 = "",
};

/// Fetched and built by offline/php/build.zig into the offline viewer.
pub const fetched = [_]Component{
    .{ .dependency = "php", .license_file = "LICENSE", .name = "PHP", .version = "8.3.37", .license = "PHP-3.01", .supplier = "The PHP Group", .purpose = "The PHP interpreter, embedded in the offline viewer", .sha256 = "0237af84478b7a7649d3964153f1b8653d622550b846f56d63062de683fb86bb" },
    .{ .dependency = "zlib", .license_file = "LICENSE", .name = "zlib", .version = "1.3.1", .license = "Zlib", .supplier = "Jean-loup Gailly and Mark Adler", .purpose = "Compression: PHP zlib extension, libpng", .sha256 = "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23" },
    .{ .dependency = "sqlite", .name = "SQLite", .version = "3.54.1", .license = "blessing", .supplier = "SQLite Consortium", .purpose = "The wiki database engine: PHP sqlite3 and pdo_sqlite extensions", .sha256 = "0a9c8e34352dad46006aa82836d5383bff9dc6bc9ce5a60553c05aa30e6ad1f9" },
    .{ .dependency = "libxml2", .license_file = "Copyright", .name = "libxml2", .version = "2.15.4", .license = "MIT", .supplier = "The GNOME Project", .purpose = "XML and HTML parsing: PHP dom, libxml, simplexml, xml, xmlreader, xmlwriter extensions", .sha256 = "98087fd181d9070724f3fbc65c7377db03038eb92bd882374daff44940138821" },
    .{ .dependency = "icu", .license_file = "LICENSE", .name = "ICU4C", .version = "79.1", .license = "Unicode-3.0", .supplier = "Unicode, Inc.", .purpose = "Unicode and locale support and data: PHP intl extension", .sha256 = "06fa63ecb521048f8082f12ad988f6b678d90cbd88aafce24cbc94902b191d99" },
    .{ .dependency = "lua", .license_file = "COPYRIGHT", .name = "Lua", .version = "5.1.5", .license = "MIT", .supplier = "Lua.org, PUC-Rio", .purpose = "Runs Scribunto modules", .sha256 = "2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333" },
    .{ .dependency = "luasandbox", .license_file = "LuaSandbox-4.1.3/COPYING", .name = "LuaSandbox", .version = "4.1.3", .license = "MIT", .supplier = "Wikimedia Foundation", .purpose = "PHP extension that runs Lua in-process for Scribunto", .sha256 = "8d20420b19b71f23782077ec8f51d044d54b2e5e4356d91bae45aad07e93adf6" },
    .{ .dependency = "libpng", .license_file = "LICENSE", .name = "libpng", .version = "1.6.59", .license = "libpng-2.0", .supplier = "The PNG Reference Library Authors", .purpose = "PNG images: PHP gd extension", .sha256 = "d80dd2a38a37f803cb9b6ac7b14bd6e74ddc3b654780a8380bdf93523fdb4389" },
    .{ .dependency = "jpeg", .license_file = "README", .name = "libjpeg", .version = "9f", .license = "IJG", .supplier = "Independent JPEG Group", .purpose = "JPEG images: PHP gd extension", .sha256 = "04705c110cb2469caa79fb71fba3d7bf834914706e9641a4589485c1f832565b" },
    .{ .dependency = "win_iconv", .license_file = "readme.txt", .name = "win-iconv", .version = "0.0.11", .license = "LicenseRef-public-domain", .supplier = "Yukihiro Nakadaira", .purpose = "Character set conversion: PHP iconv extension", .source_note = "git tag v0.0.11, commit 70a279dcfe6318bbe63e019e33b3230b55c19762" },
    .{ .dependency = "oniguruma", .license_file = "COPYING", .name = "Oniguruma", .version = "6.9.10", .license = "BSD-2-Clause", .supplier = "K. Kosako", .purpose = "Multibyte regular expressions: PHP mbstring extension", .sha256 = "2a5cfc5ae259e4e97f86b68dfffc152cdaffe94e2060b770cb827238d769fc05" },
};

/// Libraries that come inside the PHP release and are compiled with it. The
/// versions are the ones PHP 8.3.37 bundles. This list covers the bundled
/// libraries with a licence of their own; it is not every file in PHP with a
/// separate notice.
pub const bundled_in_php = [_]Component{
    .{ .name = "Zend Engine", .version = "4.3.37", .license = "Zend-2.0", .supplier = "Zend Technologies", .purpose = "PHP's language engine", .source = "PHP release, Zend/" },
    .{ .name = "PCRE2", .version = "10.42", .license = "BSD-3-Clause", .supplier = "University of Cambridge", .purpose = "Regular expressions: PHP pcre extension", .source = "PHP release, ext/pcre/pcre2lib" },
    .{ .name = "timelib", .version = "2022.14", .license = "MIT", .supplier = "Derick Rethans", .purpose = "Dates and time zones: PHP date extension", .source = "PHP release, ext/date/lib" },
    .{ .name = "libmagic", .version = "5.43", .license = "BSD-2-Clause", .supplier = "Christos Zoulas and contributors", .purpose = "File type detection: PHP fileinfo extension", .source = "PHP release, ext/fileinfo/libmagic" },
    .{ .name = "libgd", .version = "2.0.35", .license = "GD", .supplier = "The GD project", .purpose = "Image processing: PHP gd extension", .source = "PHP release, ext/gd/libgd (PHP's own fork)" },
    .{ .name = "libmbfl", .version = "1.3.2", .license = "LGPL-2.1-only", .supplier = "The PHP Group", .purpose = "Multibyte encodings: PHP mbstring extension", .source = "PHP release, ext/mbstring/libmbfl" },
    .{ .name = "libbcmath", .version = "PHP fork of 0.2", .license = "LGPL-2.1-or-later", .supplier = "Free Software Foundation", .purpose = "Arbitrary precision arithmetic: PHP bcmath extension", .source = "PHP release, ext/bcmath/libbcmath" },
    .{ .name = "xxHash", .version = "0.8.1", .license = "BSD-2-Clause", .supplier = "Yann Collet", .purpose = "Hash functions: PHP hash extension", .source = "PHP release, ext/hash/xxhash" },
    .{ .name = "Boost.Context (fcontext assembly)", .version = "as bundled", .license = "BSL-1.0", .supplier = "Oliver Kowalke", .purpose = "Fiber context switching", .source = "PHP release, Zend/asm" },
};

/// The wiki software. The container build fetches these (see Dockerfile);
/// the offline viewer will carry the same tree. The versions are the build
/// arguments' defaults; the exact versions are fixed when an image is built.
pub const wiki = [_]Component{
    .{ .name = "MediaWiki", .version = "1.43 (LTS series)", .license = "GPL-2.0-or-later", .supplier = "Wikimedia Foundation and contributors", .purpose = "The wiki", .source = "Docker Hub official image mediawiki:1.43, which also carries its bundled extensions and PHP libraries" },
    .{ .name = "Semantic MediaWiki", .version = "~7.4", .license = "GPL-2.0-or-later", .supplier = "Semantic MediaWiki project", .purpose = "Semantic properties and queries", .source = "Packagist, mediawiki/semantic-media-wiki, with its Composer dependencies" },
    .{ .name = "Wikibase", .version = "REL1_43 branch", .license = "GPL-2.0-or-later", .supplier = "Wikimedia Deutschland", .purpose = "Structured data repository and client", .source = "https://gerrit.wikimedia.org/r/mediawiki/extensions/Wikibase, with its git submodules and Composer dependencies" },
};
