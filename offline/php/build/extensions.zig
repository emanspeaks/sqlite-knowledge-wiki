//! The optional PHP extensions build.zig compiles in, and the always-on ones.
const sources = @import("../sources.zig");

/// An optional extension compiled into the library. Each is built as its own
/// static library so that its include directories and flags stay its own
/// (several bundle a config.h).
pub const Extension = struct {
    name: []const u8,
    sources: []const []const u8,
    /// The header that declares the module, and the module pointer in it.
    /// Null for a Zend extension, which the host registers itself.
    header: ?[]const u8,
    module: ?[]const u8,
    /// Appended to main/config.w32.h, as PHP's configure would.
    config: []const u8,
    /// Include directories relative to the PHP sources.
    include_dirs: []const []const u8 = &.{},
    flags: []const []const u8 = &.{},
    /// For an extension that is not part of PHP: its package in
    /// build.zig.zon and the directory in it that holds the sources.
    package: ?[]const u8 = null,
    package_dir: []const u8 = "",
    /// Sources in this repository that go with the extension.
    own_sources: []const []const u8 = &.{},
    system_libs: []const []const u8 = &.{},
    /// Whether some of the sources are C++.
    cxx: bool = false,
    /// Third-party libraries, by their name in build.zig.zon.
    uses: []const []const u8 = &.{},
    /// Extra headers the extension expects its build to have generated.
    generated: []const Generated = &.{},

    const Generated = struct { name: []const u8, contents: []const u8 };
};

pub const extensions = [_]Extension{
    .{
        .name = "bcmath",
        .sources = &sources.bcmath,
        .header = "ext/bcmath/php_bcmath.h",
        .module = "phpext_bcmath_ptr",
        .config = "#define HAVE_BCMATH 1\n",
        .include_dirs = &.{"ext/bcmath/libbcmath/src"},
    },
    .{
        .name = "calendar",
        .sources = &sources.calendar,
        .header = "ext/calendar/php_calendar.h",
        .module = "phpext_calendar_ptr",
        .config = "#define HAVE_CALENDAR 1\n",
    },
    .{
        .name = "ctype",
        .sources = &sources.ctype,
        .header = "ext/ctype/php_ctype.h",
        .module = "phpext_ctype_ptr",
        .config = "#define HAVE_CTYPE 1\n",
    },
    .{
        .name = "fileinfo",
        .sources = &sources.fileinfo,
        .header = "ext/fileinfo/php_fileinfo.h",
        .module = "phpext_fileinfo_ptr",
        .config = "",
        .include_dirs = &.{ "ext/fileinfo/libmagic", "ext/fileinfo" },
    },
    .{
        .name = "filter",
        .sources = &sources.filter,
        .header = "ext/filter/php_filter.h",
        .module = "phpext_filter_ptr",
        .config = "",
    },
    .{
        // PHP's bundled copy of libgd, for thumbnails: PNG, JPEG, GIF and BMP.
        // No FreeType (text drawing), XPM, WebP or AVIF.
        .name = "gd",
        .sources = &.{
            "ext/gd/gd.c",
            "ext/gd/libgd/gd2copypal.c",
            "ext/gd/libgd/gd.c",
            "ext/gd/libgd/gdcache.c",
            "ext/gd/libgd/gdfontg.c",
            "ext/gd/libgd/gdfontl.c",
            "ext/gd/libgd/gdfontmb.c",
            "ext/gd/libgd/gdfonts.c",
            "ext/gd/libgd/gdfontt.c",
            "ext/gd/libgd/gdft.c",
            "ext/gd/libgd/gd_gd2.c",
            "ext/gd/libgd/gd_gd.c",
            "ext/gd/libgd/gd_gif_in.c",
            "ext/gd/libgd/gd_gif_out.c",
            "ext/gd/libgd/gdhelpers.c",
            "ext/gd/libgd/gd_io.c",
            "ext/gd/libgd/gd_io_dp.c",
            "ext/gd/libgd/gd_io_file.c",
            "ext/gd/libgd/gd_io_ss.c",
            "ext/gd/libgd/gd_jpeg.c",
            "ext/gd/libgd/gdkanji.c",
            "ext/gd/libgd/gd_png.c",
            "ext/gd/libgd/gd_ss.c",
            "ext/gd/libgd/gdtables.c",
            "ext/gd/libgd/gd_topal.c",
            "ext/gd/libgd/gd_wbmp.c",
            "ext/gd/libgd/gdxpm.c",
            "ext/gd/libgd/wbmp.c",
            "ext/gd/libgd/gd_xbm.c",
            "ext/gd/libgd/gd_security.c",
            "ext/gd/libgd/gd_transform.c",
            "ext/gd/libgd/gd_filter.c",
            "ext/gd/libgd/gd_pixelate.c",
            "ext/gd/libgd/gd_rotate.c",
            "ext/gd/libgd/gd_color_match.c",
            "ext/gd/libgd/gd_webp.c",
            "ext/gd/libgd/gd_avif.c",
            "ext/gd/libgd/gd_crop.c",
            "ext/gd/libgd/gd_interpolation.c",
            "ext/gd/libgd/gd_matrix.c",
            "ext/gd/libgd/gd_bmp.c",
            "ext/gd/libgd/gd_tga.c",
        },
        .header = "ext/gd/php_gd.h",
        .module = "phpext_gd_ptr",
        .config = "#define HAVE_LIBGD 1\n#define HAVE_GD_BUNDLED 1\n#define HAVE_GD_PNG 1\n#define HAVE_GD_BMP 1\n#define HAVE_GD_TGA 1\n#define HAVE_LIBPNG 1\n#define HAVE_LIBJPEG 1\n#define HAVE_GD_JPG 1\n",
        .include_dirs = &.{ "ext/gd/libgd", "ext/gd" },
        // gd.c calls gdImageGetInterpolationMethod(), which the bundled gd.h
        // does not declare. Microsoft's compiler lets that pass; clang needs
        // telling. The function returns an int-sized enum, so it is safe.
        .flags = &.{ "-DPHP_GD_EXPORTS=1", "-DHAVE_GD_GET_INTERPOLATION", "-Wno-error=implicit-function-declaration" },
        .uses = &.{ "libpng", "jpeg", "zlib", "win_iconv" },
    },
    .{
        .name = "iconv",
        .sources = &sources.iconv,
        .header = "ext/iconv/php_iconv.h",
        .module = "phpext_iconv_ptr",
        .config = "#define HAVE_ICONV 1\n#define PHP_ICONV_IMPL \"\\\"win-iconv\\\"\"\n",
        .flags = &.{"-DPHP_ICONV_EXPORTS"},
        .uses = &.{"win_iconv"},
    },
    .{
        .name = "intl",
        .sources = &sources.intl,
        .header = "ext/intl/php_intl.h",
        .module = "phpext_intl_ptr",
        .config = "#define HAVE_INTL 1\n",
        .include_dirs = &.{"ext/intl"},
        .flags = &.{
            "-DU_STATIC_IMPLEMENTATION",
            "-DUNISTR_FROM_CHAR_EXPLICIT=explicit",
            "-DUNISTR_FROM_STRING_EXPLICIT=explicit",
            "-DU_NO_DEFAULT_INCLUDE_UTF_HEADERS=1",
            "-DU_HIDE_OBSOLETE_UTF_OLD_H=1",
        },
        .cxx = true,
        .uses = &.{"icu"},
    },
    .{
        // Scribunto's Lua engine, in-process. Its CPU-time limit uses POSIX
        // timers, which compat/luasandbox_posix_timers.c provides on Win32.
        .name = "luasandbox",
        .sources = &.{ "alloc.c", "data_conversion.c", "library.c", "luasandbox.c", "timer.c", "luasandbox_lstrlib.c" },
        .header = "php_luasandbox_win32.h",
        .module = "phpext_luasandbox_ptr",
        .config = "",
        .flags = &.{ "-DHAVE_CONFIG_H", "-include", "compat/luasandbox_posix_timers.h" },
        .own_sources = &.{"compat/luasandbox_posix_timers.c"},
        .system_libs = &.{"pthread"},
        .package = "luasandbox",
        .package_dir = "LuaSandbox-4.1.3",
        .uses = &.{"lua"},
        // PECL's build defines these in a config.h.
        .generated = &.{.{ .name = "config.h", .contents = "#include \"config.w32.h\"\n" }},
    },
    .{
        // With multibyte regular expressions (mb_ereg and friends), which
        // the Math extension uses.
        .name = "mbstring",
        .sources = &(sources.mbstring ++ [_][]const u8{"ext/mbstring/php_mbregex.c"}),
        .header = "ext/mbstring/mbstring.h",
        .module = "phpext_mbstring_ptr",
        .config = "#define HAVE_MBSTRING 1\n#define HAVE_MBREGEX 1\n",
        .include_dirs = &.{ "ext/mbstring", "ext/mbstring/libmbfl", "ext/mbstring/libmbfl/mbfl" },
        .flags = &.{ "-DHAVE_STRICMP", "-DMBFL_DLL_EXPORT=1", "-DHAVE_CONFIG_H", "-DONIG_EXTERN=extern", "-DPHP_ONIG_BAD_KOI8_ENTRY=1" },
        .uses = &.{"oniguruma"},
        // PHP's configure copies libmbfl/config.h.w32 to libmbfl/config.h.
        .generated = &.{.{ .name = "libmbfl/config.h", .contents = "#include \"config.h.w32\"\n" }},
    },
    .{
        // Without the JIT, whose build needs a Lua-based code generator. As a
        // Zend extension it is not in PHP's module list: the host registers
        // zend_extension_entry before start-up (see test/embed_smoke.c).
        .name = "opcache",
        .sources = &.{
            "ext/opcache/ZendAccelerator.c",             "ext/opcache/shared_alloc_win32.c",
            "ext/opcache/zend_accelerator_blacklist.c",  "ext/opcache/zend_accelerator_debug.c",
            "ext/opcache/zend_accelerator_hash.c",       "ext/opcache/zend_accelerator_module.c",
            "ext/opcache/zend_accelerator_util_funcs.c", "ext/opcache/zend_file_cache.c",
            "ext/opcache/zend_persist.c",                "ext/opcache/zend_persist_calc.c",
            "ext/opcache/zend_shared_alloc.c",
        },
        .header = null,
        .module = null,
        .config = "#define HAVE_OPCACHE 1\n",
        .include_dirs = &.{"ext/opcache"},
    },
    .{
        .name = "pdo",
        .sources = &sources.pdo,
        .header = "ext/pdo/php_pdo.h",
        .module = "phpext_pdo_ptr",
        .config = "",
    },
    .{
        .name = "pdo_sqlite",
        .sources = &sources.pdo_sqlite,
        .header = "ext/pdo_sqlite/php_pdo_sqlite.h",
        .module = "phpext_pdo_sqlite_ptr",
        .config = "#define HAVE_SQLITE3_COLUMN_TABLE_NAME 1\n#define HAVE_SQLITE3_CLOSE_V2 1\n",
        .uses = &.{"sqlite"},
    },
    .{
        .name = "session",
        .sources = &sources.session,
        .header = "ext/session/php_session.h",
        .module = "phpext_session_ptr",
        .config = "#define HAVE_PHP_SESSION 1\n",
    },
    .{
        .name = "sqlite3",
        .sources = &sources.sqlite3,
        .header = "ext/sqlite3/php_sqlite3.h",
        .module = "phpext_sqlite3_ptr",
        .config = "#define HAVE_SQLITE3 1\n#define HAVE_SQLITE3_ERRSTR 1\n#define HAVE_SQLITE3_EXPANDED_SQL 1\n",
        // SQLite is built without loadable extensions.
        .flags = &.{"-DSQLITE_OMIT_LOAD_EXTENSION"},
        .uses = &.{"sqlite"},
    },
    .{
        .name = "tokenizer",
        .sources = &sources.tokenizer,
        .header = "ext/tokenizer/php_tokenizer.h",
        .module = "phpext_tokenizer_ptr",
        .config = "#define HAVE_TOKENIZER 1\n",
    },
    .{
        .name = "dom",
        .sources = &sources.dom,
        .header = "ext/dom/php_dom.h",
        .module = "phpext_dom_ptr",
        .config = "#define HAVE_DOM 1\n",
        .flags = &.{"-DLIBXML_STATIC"},
        .uses = &.{"libxml2"},
    },
    .{
        .name = "libxml",
        .sources = &sources.libxml,
        .header = "ext/libxml/php_libxml.h",
        .module = "phpext_libxml_ptr",
        .config = "#define HAVE_LIBXML 1\n",
        .flags = &.{"-DLIBXML_STATIC"},
        .uses = &.{"libxml2"},
    },
    .{
        .name = "simplexml",
        .sources = &sources.simplexml,
        .header = "ext/simplexml/php_simplexml.h",
        .module = "phpext_simplexml_ptr",
        .config = "#define HAVE_SIMPLEXML 1\n",
        .flags = &.{ "-DLIBXML_STATIC", "-DPHP_SIMPLEXML_EXPORTS" },
        .uses = &.{"libxml2"},
    },
    .{
        .name = "xml",
        .sources = &sources.xml,
        .header = "ext/xml/php_xml.h",
        .module = "phpext_xml_ptr",
        .config = "#define HAVE_XML 1\n",
        .flags = &.{"-DLIBXML_STATIC"},
        .uses = &.{"libxml2"},
    },
    .{
        .name = "xmlreader",
        .sources = &sources.xmlreader,
        .header = "ext/xmlreader/php_xmlreader.h",
        .module = "phpext_xmlreader_ptr",
        .config = "#define HAVE_XMLREADER 1\n",
        .flags = &.{"-DLIBXML_STATIC"},
        .uses = &.{"libxml2"},
    },
    .{
        .name = "xmlwriter",
        .sources = &sources.xmlwriter,
        .header = "ext/xmlwriter/php_xmlwriter.h",
        .module = "phpext_xmlwriter_ptr",
        .config = "#define HAVE_XMLWRITER 1\n",
        .flags = &.{"-DLIBXML_STATIC"},
        .uses = &.{"libxml2"},
    },
    .{
        .name = "zlib",
        .sources = &sources.zlib,
        .header = "ext/zlib/php_zlib.h",
        .module = "phpext_zlib_ptr",
        .config = "#define HAVE_ZLIB_H 1\n#define HAVE_ZLIB 1\n",
        .flags = &.{"-DZLIB_EXPORTS"},
        .uses = &.{"zlib"},
    },
};

/// The extensions PHP always has, in the form internal_functions.c needs.
pub const builtin_modules = [_][2][]const u8{
    .{ "ext/date/php_date.h", "phpext_date_ptr" },
    .{ "ext/hash/php_hash.h", "phpext_hash_ptr" },
    .{ "ext/json/php_json.h", "phpext_json_ptr" },
    .{ "ext/pcre/php_pcre.h", "phpext_pcre_ptr" },
    .{ "ext/random/php_random.h", "phpext_random_ptr" },
    .{ "ext/reflection/php_reflection.h", "phpext_reflection_ptr" },
    .{ "ext/spl/php_spl.h", "phpext_spl_ptr" },
    .{ "ext/standard/php_standard.h", "phpext_standard_ptr" },
};
