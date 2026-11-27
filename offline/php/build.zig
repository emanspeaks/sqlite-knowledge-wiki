//! Builds PHP as a static library for Windows with nothing but Zig: the
//! compiler, the linker and the Windows headers and C runtime are the ones Zig
//! bundles (MinGW-w64). No Microsoft toolchain or SDK is used.
//!
//! The PHP sources are the official release named in build.zig.zon. They are
//! copied into the build cache and patches/ is applied to the copy.
//!
//!   zig build            static library and the smoke-test program
//!   zig build -Doptimize=ReleaseFast
const std = @import("std");
const sources = @import("sources.zig");
const icu_sources = @import("icu_sources.zig");
const components = @import("components.zig");
const manifest = @import("build.zig.zon");

/// Flags for every PHP source file.
const php_flags = [_][]const u8{
    // PHP's Windows code uses Microsoft language extensions (__int64 suffixes,
    // anonymous structs, __declspec).
    "-fms-extensions",
    // PHP is not clean under UBSan, which Zig turns on for Debug builds of C.
    "-fno-sanitize=undefined",
    "-w",
    "-DZEND_ENABLE_STATIC_TSRMLS_CACHE=1",
    "-DPHP_WIN32",
    "-DZEND_WIN32",
    "-DWIN32",
    "-D_WINDOWS",
    "-DWINDOWS=1",
    "-D_WIN32_WINNT=0x0A00",
    "-DWINVER=0x0A00",
    "-D_USE_MATH_DEFINES",
    "-DZEND_DEBUG=0",
    // Static build: these make PHPAPI and ZEND_API plain declarations.
    "-DPHP_EXPORTS",
    "-DLIBZEND_EXPORTS",
    "-DTSRM_EXPORTS",
    "-DSAPI_EXPORTS",
    "-D_MBCS",
    "-DNDEBUG",
    "-DFD_SETSIZE=256",
    "-DARG_MAX=14500",
    // ext/date: makes timelib take its allocator from timelib_config.h.
    // Without it half of timelib uses malloc and half PHP's allocator.
    "-DHAVE_TIMELIB_CONFIG_H=1",
    // ext/hash's SHA-3
    "-DKeccakP200_excluded",
    "-DKeccakP400_excluded",
    "-DKeccakP800_excluded",
};

/// Windows headers PHP includes under a spelling that Zig's bundled headers,
/// which are all lower-case, do not have. It only matters on build hosts with
/// case-sensitive file systems.
const header_spellings = [_][]const u8{
    "LMCONS.H", "Sddl.h", "Wingdi.h", "WinBase.h", "Winbase.h", "Wincrypt.h", "Windns.h", "Winsock2.h", "Winuser.h", "Ws2tcpip.h",
};

/// An optional extension compiled into the library. Each is built as its own
/// static library so that its include directories and flags stay its own
/// (several bundle a config.h).
const Extension = struct {
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

const extensions = [_]Extension{
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
const builtin_modules = [_][2][]const u8{
    .{ "ext/date/php_date.h", "phpext_date_ptr" },
    .{ "ext/hash/php_hash.h", "phpext_hash_ptr" },
    .{ "ext/json/php_json.h", "phpext_json_ptr" },
    .{ "ext/pcre/php_pcre.h", "phpext_pcre_ptr" },
    .{ "ext/random/php_random.h", "phpext_random_ptr" },
    .{ "ext/reflection/php_reflection.h", "phpext_reflection_ptr" },
    .{ "ext/spl/php_spl.h", "phpext_spl_ptr" },
    .{ "ext/standard/php_standard.h", "phpext_standard_ptr" },
};

const system_libs = [_][]const u8{
    "ws2_32",  "kernel32", "advapi32", "shell32", "iphlpapi", "dnsapi",
    "psapi",   "bcrypt",   "ole32",    "user32",  "shlwapi",
    // ext/gd (screen capture functions)
     "gdi32",
    // the smoke program's crash handler
    "dbghelp",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    });
    const optimize = b.standardOptimizeOption(.{});

    // The pristine release, copied into the cache with the patches applied.
    const prepare_mod = b.createModule(.{
        .target = b.resolveTargetQuery(.{}),
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    prepare_mod.addCSourceFile(.{ .file = b.path("tools/prepare_src.c") });
    const prepare = b.addRunArtifact(b.addExecutable(.{ .name = "prepare_src", .root_module = prepare_mod }));
    prepare.addDirectoryArg(b.dependency("php", .{}).path(""));
    const src = prepare.addOutputDirectoryArg("php-src");
    prepare.addFileArg(b.path("patches/php-8.3-mingw.patch"));
    prepare.addFileArg(b.path("patches/php-8.3-opcache-embed.patch"));

    // One forwarding header per spelling. #include_next keeps this from
    // including itself where file names are case-insensitive.
    const spellings = b.addWriteFiles();
    for (header_spellings) |name| {
        var lower_buf: [32]u8 = undefined;
        const lower = std.ascii.lowerString(&lower_buf, name);
        _ = spellings.add(name, b.fmt("#pragma once\n#include_next <{s}>\n", .{lower}));
    }

    // main/config.w32.h and main/internal_functions.c, which PHP's configure
    // writes from the list of enabled extensions.
    const generated = b.addWriteFiles();
    var config: std.ArrayList(u8) = .empty;
    var includes_c: std.ArrayList(u8) = .empty;
    var modules_c: std.ArrayList(u8) = .empty;
    const arena = b.allocator;
    config.appendSlice(arena, "#include \"config.base.h\"\n") catch @panic("OOM");
    for (builtin_modules) |m| {
        includes_c.appendSlice(arena, b.fmt("#include \"{s}\"\n", .{m[0]})) catch @panic("OOM");
        modules_c.appendSlice(arena, b.fmt("\t{s},\n", .{m[1]})) catch @panic("OOM");
    }
    for (extensions) |ext| {
        config.appendSlice(arena, ext.config) catch @panic("OOM");
        if (ext.header) |header| includes_c.appendSlice(arena, b.fmt("#include \"{s}\"\n", .{header})) catch @panic("OOM");
        if (ext.module) |module| modules_c.appendSlice(arena, b.fmt("\t{s},\n", .{module})) catch @panic("OOM");
    }
    _ = generated.add("main/config.w32.h", config.items);
    const internal_functions = generated.add("internal_functions.c", b.fmt(
        \\/* Generated by build.zig, as PHP's configure generates it from
        \\ * main/internal_functions.c.in. */
        \\#include "php.h"
        \\#include "php_main.h"
        \\#include "zend_modules.h"
        \\#include "zend_compile.h"
        \\#include <stdarg.h>
        \\#include <stdlib.h>
        \\#include <stdio.h>
        \\
        \\{s}
        \\static zend_module_entry * const php_builtin_extensions[] = {{
        \\{s}}};
        \\
        \\#define EXTCOUNT (sizeof(php_builtin_extensions)/sizeof(zend_module_entry *))
        \\
        \\PHPAPI int php_register_internal_extensions(void)
        \\{{
        \\    return php_register_extensions(php_builtin_extensions, EXTCOUNT);
        \\}}
        \\
        \\/* In place of win32/dllmain.c, which only runs for a DLL. It is part of
        \\ * this file so that the linker cannot leave it out of a static link. */
        \\#include "static_init.inc"
        \\
    , .{ includes_c.items, modules_c.items }));

    const includes: Includes = .{
        .src = src,
        .spellings = spellings.getDirectory(),
        .generated = generated.getDirectory(),
    };

    var libraries: std.StringHashMapUnmanaged(Library) = .empty;
    libraries.put(arena, "zlib", zlib(b, target, optimize)) catch @panic("OOM");
    libraries.put(arena, "sqlite", sqlite(b, target, optimize)) catch @panic("OOM");
    libraries.put(arena, "libxml2", libxml2(b, target, optimize)) catch @panic("OOM");
    libraries.put(arena, "lua", lua(b, target, optimize)) catch @panic("OOM");
    libraries.put(arena, "win_iconv", winIconv(b, target, optimize)) catch @panic("OOM");
    libraries.put(arena, "oniguruma", oniguruma(b, target, optimize)) catch @panic("OOM");
    libraries.put(arena, "libpng", libpng(b, target, optimize, libraries.get("zlib").?)) catch @panic("OOM");
    libraries.put(arena, "jpeg", jpeg(b, target, optimize)) catch @panic("OOM");
    libraries.put(arena, "icu", icu(b, target, optimize)) catch @panic("OOM");

    const php = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    addPhpIncludes(b, php, includes);
    // The core sees every library: internal_functions.c includes each
    // extension's header, and ext/standard uses zlib when it is there.
    {
        var it = libraries.valueIterator();
        while (it.next()) |lib| lib.addTo(php);
    }
    for (extensions) |ext| {
        if (ext.package) |package| php.addIncludePath(b.dependency(package, .{}).path(ext.package_dir));
    }
    php.addCSourceFiles(.{ .root = src, .files = &sources.core, .flags = &php_flags });
    php.addCSourceFiles(.{
        .root = src,
        .files = &sources.pcre2,
        .flags = &(php_flags ++ [_][]const u8{"-DHAVE_CONFIG_H"}),
    });
    php.addCSourceFile(.{ .file = internal_functions, .flags = &php_flags });
    // Fibers: PHP ships its context-switch routines for Windows only in
    // Microsoft assembler syntax. masm2gas rewrites the directives around the
    // instructions so that clang assembles PHP's own files.
    const masm2gas_mod = b.createModule(.{
        .target = b.resolveTargetQuery(.{}),
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    masm2gas_mod.addCSourceFile(.{ .file = b.path("tools/masm2gas.c") });
    const masm2gas = b.addExecutable(.{ .name = "masm2gas", .root_module = masm2gas_mod });
    for ([_][]const u8{ "jump", "make" }) |routine| {
        const convert = b.addRunArtifact(masm2gas);
        convert.addFileArg(src.path(b, b.fmt("Zend/asm/{s}_x86_64_ms_pe_masm.asm", .{routine})));
        php.addAssemblyFile(convert.addOutputFileArg(b.fmt("{s}_fcontext.S", .{routine})));
    }
    for (system_libs) |name| php.linkSystemLibrary(name, .{});

    for (extensions) |ext| {
        const m = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
        if (ext.generated.len != 0) {
            const files = b.addWriteFiles();
            for (ext.generated) |g| _ = files.add(g.name, g.contents);
            m.addIncludePath(files.getDirectory());
        }
        for (ext.include_dirs) |dir| m.addIncludePath(src.path(b, dir));
        for (ext.uses) |name| libraries.get(name).?.addTo(m);
        addPhpIncludes(b, m, includes);
        const flags = std.mem.concat(arena, []const u8, &.{ &php_flags, ext.flags }) catch @panic("OOM");
        for (ext.own_sources) |file| m.addCSourceFile(.{ .file = b.path(file), .flags = &library_flags });
        for (ext.system_libs) |name| m.linkSystemLibrary(name, .{});
        const root = if (ext.package) |package| b.dependency(package, .{}).path(ext.package_dir) else src;
        if (ext.cxx) {
            // -fms-extensions is for PHP's C; the C++ sources get C++17, which ICU's headers need.
            var c_files: std.ArrayList([]const u8) = .empty;
            var cxx_files: std.ArrayList([]const u8) = .empty;
            for (ext.sources) |file| {
                const list = if (std.mem.endsWith(u8, file, ".cpp")) &cxx_files else &c_files;
                list.append(arena, file) catch @panic("OOM");
            }
            const cxx_flags = std.mem.concat(arena, []const u8, &.{ flags, &.{"-std=c++17"} }) catch @panic("OOM");
            m.addCSourceFiles(.{ .root = root, .files = c_files.items, .flags = flags });
            m.addCSourceFiles(.{ .root = root, .files = cxx_files.items, .flags = cxx_flags });
            m.link_libcpp = true;
        } else {
            m.addCSourceFiles(.{ .root = root, .files = ext.sources, .flags = flags });
        }
        php.linkLibrary(b.addLibrary(.{ .name = b.fmt("php_{s}", .{ext.name}), .linkage = .static, .root_module = m }));
    }

    const lib = b.addLibrary(.{ .name = "php", .linkage = .static, .root_module = php });
    b.installArtifact(lib);

    // A program that starts the embedded interpreter and runs a line of PHP.
    const smoke_mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    addPhpIncludes(b, smoke_mod, includes);
    smoke_mod.addCSourceFile(.{ .file = b.path("test/embed_smoke.c"), .flags = &php_flags });
    smoke_mod.linkLibrary(lib);
    const smoke = b.addExecutable(.{ .name = "php-embed-smoke", .root_module = smoke_mod });
    b.installArtifact(smoke);

    // `zig build licenses`: every component's licence text, zig-out/licenses/.
    // They go out with the program.
    const licenses_step = b.step("licenses", "Collect the licence texts of the third-party components");
    inline for (components.fetched) |c| {
        // PHP's are taken from the prepared sources below.
        if (c.license_file.len != 0 and !std.mem.eql(u8, c.dependency.?, "php")) {
            const file = b.dependency(c.dependency.?, .{}).path(c.license_file);
            licenses_step.dependOn(&b.addInstallFile(file, b.fmt("licenses/{s}.txt", .{c.name})).step);
        }
    }
    for ([_][2][]const u8{
        .{ "LICENSE", "PHP" },
        .{ "README.REDIST.BINS", "PHP bundled libraries" },
        .{ "Zend/LICENSE", "Zend Engine" },
        .{ "Zend/asm/LICENSE", "Boost.Context" },
        .{ "ext/date/lib/LICENSE.rst", "timelib" },
        .{ "ext/fileinfo/libmagic/LICENSE", "libmagic" },
        .{ "ext/mbstring/libmbfl/LICENSE", "libmbfl" },
        .{ "ext/bcmath/libbcmath/LICENSE", "libbcmath" },
    }) |entry| {
        licenses_step.dependOn(&b.addInstallFile(src.path(b, entry[0]), b.fmt("licenses/{s}.txt", .{entry[1]})).step);
    }
    const license_notes = b.addWriteFiles();
    licenses_step.dependOn(&b.addInstallFile(license_notes.add("SQLite.txt",
        \\SQLite is in the public domain. Its authors disclaim copyright; in place
        \\of a legal notice its sources carry this blessing:
        \\
        \\    May you do good and not evil.
        \\    May you find forgiveness for yourself and forgive others.
        \\    May you share freely, never taking more than you give.
        \\
        \\See https://www.sqlite.org/copyright.html
        \\
    ), "licenses/SQLite.txt").step);

    // `zig build sbom`: the software bill of materials, zig-out/sbom.cdx.json.
    const sbom_files = b.addWriteFiles();
    const sbom_file = sbom_files.add("sbom.cdx.json", sbom(b));
    const sbom_step = b.step("sbom", "Write the software bill of materials (CycloneDX JSON)");
    sbom_step.dependOn(&b.addInstallFile(sbom_file, "sbom.cdx.json").step);
}

/// The software bill of materials in CycloneDX 1.5 JSON. Where each fetched
/// component comes from and its package hash are read from build.zig.zon
/// itself, so the SBOM cannot disagree with what is built; a dependency with
/// no entry in components.zig is a compile error. There is no timestamp or
/// serial number: the same sources give the same file.
fn sbom(b: *std.Build) []const u8 {
    comptime {
        for (std.meta.fieldNames(@TypeOf(manifest.dependencies))) |dependency| {
            var found = false;
            for (components.fetched) |c| {
                if (std.mem.eql(u8, c.dependency.?, dependency)) found = true;
            }
            if (!found) @compileError("build.zig.zon dependency '" ++ dependency ++ "' has no entry in components.zig");
        }
    }
    const arena = b.allocator;
    var out: std.ArrayList(u8) = .empty;
    const version = b.option([]const u8, "version", "The project version to record in the SBOM") orelse "0.0.0";
    out.appendSlice(arena, b.fmt(
        \\{{
        \\  "bomFormat": "CycloneDX",
        \\  "specVersion": "1.5",
        \\  "version": 1,
        \\  "metadata": {{
        \\    "component": {{
        \\      "type": "application",
        \\      "name": "sqlite-knowledge-wiki",
        \\      "version": {s},
        \\      "licenses": [{{ "license": {{ "id": "MIT" }} }}]
        \\    }}
        \\  }},
        \\  "components": [
        \\
    , .{json(b, version)})) catch @panic("OOM");

    var first = true;
    inline for (components.fetched) |c| {
        const dep = @field(manifest.dependencies, c.dependency.?);
        appendComponent(b, &out, &first, c, "fetched and built by offline/php/build.zig", dep.url, dep.hash);
    }
    for (components.bundled_in_php) |c| appendComponent(b, &out, &first, c, "bundled in the PHP release", null, null);
    for (components.wiki) |c| appendComponent(b, &out, &first, c, "fetched by the container build", null, null);
    out.appendSlice(arena, "\n  ]\n}\n") catch @panic("OOM");
    return out.items;
}

fn appendComponent(
    b: *std.Build,
    out: *std.ArrayList(u8),
    first: *bool,
    c: components.Component,
    origin: []const u8,
    url: ?[]const u8,
    zig_hash: ?[]const u8,
) void {
    const arena = b.allocator;
    if (!first.*) out.appendSlice(arena, ",\n") catch @panic("OOM");
    first.* = false;
    // An SPDX identifier goes in "id"; anything else has to be a "name".
    const license_key = if (std.mem.startsWith(u8, c.license, "LicenseRef-")) "name" else "id";
    out.appendSlice(arena, b.fmt(
        \\    {{
        \\      "type": "library",
        \\      "name": {s},
        \\      "version": {s},
        \\      "supplier": {{ "name": {s} }},
        \\      "description": {s},
        \\      "licenses": [{{ "license": {{ "{s}": {s} }} }}]
    , .{ json(b, c.name), json(b, c.version), json(b, c.supplier), json(b, c.purpose), license_key, json(b, c.license) })) catch @panic("OOM");
    if (c.sha256.len != 0) {
        out.appendSlice(arena, b.fmt(",\n      \"hashes\": [{{ \"alg\": \"SHA-256\", \"content\": {s} }}]", .{json(b, c.sha256)})) catch @panic("OOM");
    }
    if (url) |u| {
        out.appendSlice(arena, b.fmt(",\n      \"externalReferences\": [{{ \"type\": \"distribution\", \"url\": {s} }}]", .{json(b, u)})) catch @panic("OOM");
    }
    out.appendSlice(arena, b.fmt(",\n      \"properties\": [\n        {{ \"name\": \"origin\", \"value\": {s} }}", .{json(b, origin)})) catch @panic("OOM");
    if (zig_hash) |h| out.appendSlice(arena, b.fmt(",\n        {{ \"name\": \"zig-package-hash\", \"value\": {s} }}", .{json(b, h)})) catch @panic("OOM");
    if (c.source.len != 0) out.appendSlice(arena, b.fmt(",\n        {{ \"name\": \"source\", \"value\": {s} }}", .{json(b, c.source)})) catch @panic("OOM");
    if (c.source_note.len != 0) out.appendSlice(arena, b.fmt(",\n        {{ \"name\": \"source-note\", \"value\": {s} }}", .{json(b, c.source_note)})) catch @panic("OOM");
    out.appendSlice(arena, "\n      ]\n    }") catch @panic("OOM");
}

/// A JSON string literal. The values are plain ASCII text written in this
/// repository; quotes and backslashes are the only characters to escape.
fn json(b: *std.Build, text: []const u8) []const u8 {
    var out: std.ArrayList(u8) = .empty;
    out.append(b.allocator, '"') catch @panic("OOM");
    for (text) |ch| {
        if (ch == '"' or ch == '\\') out.append(b.allocator, '\\') catch @panic("OOM");
        out.append(b.allocator, ch) catch @panic("OOM");
    }
    out.append(b.allocator, '"') catch @panic("OOM");
    return out.items;
}

/// A third-party library built from its release in build.zig.zon.
const Library = struct {
    artifact: *std.Build.Step.Compile,
    include: std.Build.LazyPath,
    /// A header the library's own configure step would have generated.
    config_header: ?*std.Build.Step.ConfigHeader = null,
    /// More header directories.
    extra_include: ?std.Build.LazyPath = null,
    extra_include2: ?std.Build.LazyPath = null,

    fn addTo(lib: Library, m: *std.Build.Module) void {
        m.addIncludePath(lib.include);
        if (lib.extra_include) |dir| m.addIncludePath(dir);
        if (lib.extra_include2) |dir| m.addIncludePath(dir);
        if (lib.config_header) |h| m.addConfigHeader(h);
        m.linkLibrary(lib.artifact);
    }
};

/// Flags for third-party C: no warnings, and no UBSan in Debug builds.
const library_flags = [_][]const u8{ "-w", "-fno-sanitize=undefined" };

fn zlib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Library {
    const dep = b.dependency("zlib", .{});
    const m = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    m.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &.{
            "adler32.c", "compress.c", "crc32.c",   "deflate.c",  "gzclose.c", "gzlib.c",   "gzread.c", "gzwrite.c",
            "infback.c", "inffast.c",  "inflate.c", "inftrees.c", "trees.c",   "uncompr.c", "zutil.c",
        },
        .flags = &library_flags,
    });
    return .{
        .artifact = b.addLibrary(.{ .name = "z", .linkage = .static, .root_module = m }),
        .include = dep.path(""),
    };
}

fn sqlite(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Library {
    const dep = b.dependency("sqlite", .{});
    const m = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    m.addCSourceFile(.{
        .file = dep.path("sqlite3.c"),
        .flags = &(library_flags ++ [_][]const u8{
            // MediaWiki's search index is an FTS3 table.
            "-DSQLITE_ENABLE_FTS3",
            "-DSQLITE_ENABLE_FTS3_PARENTHESIS",
            "-DSQLITE_ENABLE_FTS4",
            "-DSQLITE_ENABLE_FTS5",
            "-DSQLITE_ENABLE_RTREE",
            "-DSQLITE_ENABLE_MATH_FUNCTIONS",
            // pdo_sqlite's column metadata
            "-DSQLITE_ENABLE_COLUMN_METADATA",
            "-DSQLITE_OMIT_LOAD_EXTENSION",
            "-DSQLITE_DQS=0",
        }),
    });
    return .{
        .artifact = b.addLibrary(.{ .name = "sqlite3", .linkage = .static, .root_module = m }),
        .include = dep.path(""),
    };
}

/// ICU's common, i18n and io libraries with ICU's data built in, as one static
/// library. The data is the prebuilt archive the ICU release ships
/// (source/data/in/icudt79l.dat), placed in the program by the assembler.
fn icu(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Library {
    const dep = b.dependency("icu", .{});
    const flags = [_][]const u8{
        "-w",
        "-fno-sanitize=undefined",
        "-std=c++17",
        "-fno-exceptions",
        "-DU_STATIC_IMPLEMENTATION",
        "-DU_ENABLE_DYLOAD=0",
        "-DHAVE_DLOPEN=0",
        "-DU_HAVE_STRTOD_L=0",
        "-DU_ATTRIBUTE_DEPRECATED=",
    };
    const m = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true, .link_libcpp = true });
    m.addIncludePath(dep.path("source/common"));
    m.addIncludePath(dep.path("source/i18n"));
    m.addCSourceFiles(.{
        .root = dep.path("source/common"),
        .files = &icu_sources.common,
        .flags = &(flags ++ [_][]const u8{"-DU_COMMON_IMPLEMENTATION"}),
    });
    m.addCSourceFiles(.{
        .root = dep.path("source/i18n"),
        .files = &icu_sources.i18n,
        .flags = &(flags ++ [_][]const u8{"-DU_I18N_IMPLEMENTATION"}),
    });
    m.addIncludePath(dep.path("source/io"));
    m.addCSourceFiles(.{
        .root = dep.path("source/io"),
        .files = &icu_sources.io,
        .flags = &(flags ++ [_][]const u8{"-DU_IO_IMPLEMENTATION"}),
    });
    // icudt79_dat is the symbol ICU looks for (U_ICUDATA_ENTRY_POINT).
    const data = b.addWriteFiles();
    const data_s = data.add("icudata.S",
        \\    .section .rdata,"dr"
        \\    .globl icudt79_dat
        \\    .balign 16
        \\icudt79_dat:
        \\    .incbin "icudt79l.dat"
        \\
    );
    _ = data.addCopyFile(dep.path("source/data/in/icudt79l.dat"), "icudt79l.dat");
    m.addIncludePath(data.getDirectory());
    m.addAssemblyFile(data_s);
    return .{
        .artifact = b.addLibrary(.{ .name = "icu", .linkage = .static, .root_module = m }),
        .include = dep.path("source/common"),
        .extra_include = dep.path("source/i18n"),
        .extra_include2 = dep.path("source/io"),
    };
}

fn libpng(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    z: Library,
) Library {
    const dep = b.dependency("libpng", .{});
    // libpng ships the configuration its default build produces.
    const generated = b.addWriteFiles();
    _ = generated.addCopyFile(dep.path("scripts/pnglibconf.h.prebuilt"), "pnglibconf.h");
    const m = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    m.addIncludePath(generated.getDirectory());
    z.addTo(m);
    m.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &.{
            "png.c",      "pngerror.c", "pngget.c",   "pngmem.c", "pngpread.c", "pngread.c",  "pngrio.c",   "pngrtran.c",
            "pngrutil.c", "pngset.c",   "pngtrans.c", "pngwio.c", "pngwrite.c", "pngwtran.c", "pngwutil.c",
        },
        // The portable C code only: no hand-written SIMD.
        .flags = &(library_flags ++ [_][]const u8{ "-DPNG_INTEL_SSE_OPT=0", "-DPNG_ARM_NEON_OPT=0" }),
    });
    const lib = b.addLibrary(.{ .name = "png16", .linkage = .static, .root_module = m });
    return .{ .artifact = lib, .include = dep.path(""), .extra_include = generated.getDirectory() };
}

/// The Independent JPEG Group's libjpeg.
fn jpeg(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Library {
    const dep = b.dependency("jpeg", .{});
    // jconfig.vc is the configuration libjpeg ships for Windows compilers.
    const generated = b.addWriteFiles();
    _ = generated.addCopyFile(dep.path("jconfig.vc"), "jconfig.h");
    const m = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    m.addIncludePath(generated.getDirectory());
    m.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &.{
            "jaricom.c",  "jcapimin.c", "jcapistd.c", "jcarith.c",  "jccoefct.c", "jccolor.c",  "jcdctmgr.c", "jchuff.c",
            "jcinit.c",   "jcmainct.c", "jcmarker.c", "jcmaster.c", "jcomapi.c",  "jcparam.c",  "jcprepct.c", "jcsample.c",
            "jctrans.c",  "jdapimin.c", "jdapistd.c", "jdarith.c",  "jdatadst.c", "jdatasrc.c", "jdcoefct.c", "jdcolor.c",
            "jddctmgr.c", "jdhuff.c",   "jdinput.c",  "jdmainct.c", "jdmarker.c", "jdmaster.c", "jdmerge.c",  "jdpostct.c",
            "jdsample.c", "jdtrans.c",  "jerror.c",   "jfdctflt.c", "jfdctfst.c", "jfdctint.c", "jidctflt.c", "jidctfst.c",
            "jidctint.c", "jquant1.c",  "jquant2.c",  "jutils.c",   "jmemmgr.c",  "jmemnobs.c",
        },
        .flags = &library_flags,
    });
    const lib = b.addLibrary(.{ .name = "jpeg", .linkage = .static, .root_module = m });
    return .{ .artifact = lib, .include = dep.path(""), .extra_include = generated.getDirectory() };
}

/// win-iconv: the iconv interface on top of Windows' own conversion
/// functions. Public domain. It replaces GNU libiconv, which is LGPL.
fn winIconv(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Library {
    const dep = b.dependency("win_iconv", .{});
    const m = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    m.addIncludePath(dep.path(""));
    m.addCSourceFile(.{ .file = dep.path("win_iconv.c"), .flags = &library_flags });
    return .{
        .artifact = b.addLibrary(.{ .name = "iconv", .linkage = .static, .root_module = m }),
        .include = dep.path(""),
    };
}

/// Oniguruma: the regular expression engine behind mbstring's mb_ereg
/// functions, which the Math extension uses. BSD licence.
fn oniguruma(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Library {
    const dep = b.dependency("oniguruma", .{});
    // config.h.win64 is the configuration Oniguruma ships for 64-bit Windows.
    const generated = b.addWriteFiles();
    _ = generated.addCopyFile(dep.path("src/config.h.win64"), "config.h");
    const m = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    m.addIncludePath(generated.getDirectory());
    m.addIncludePath(dep.path("src"));
    m.addCSourceFiles(.{
        .root = dep.path("src"),
        .files = &.{
            "regparse.c",          "regcomp.c",           "regexec.c",           "regenc.c",      "regerror.c",   "regext.c",     "regsyntax.c",
            "regtrav.c",           "regversion.c",        "st.c",                "reggnu.c",      "onig_init.c",  "unicode.c",    "unicode_unfold_key.c",
            "unicode_fold1_key.c", "unicode_fold2_key.c", "unicode_fold3_key.c", "ascii.c",       "utf8.c",       "utf16_be.c",   "utf16_le.c",
            "utf32_be.c",          "utf32_le.c",          "euc_jp.c",            "euc_jp_prop.c", "sjis.c",       "sjis_prop.c",  "iso8859_1.c",
            "iso8859_2.c",         "iso8859_3.c",         "iso8859_4.c",         "iso8859_5.c",   "iso8859_6.c",  "iso8859_7.c",  "iso8859_8.c",
            "iso8859_9.c",         "iso8859_10.c",        "iso8859_11.c",        "iso8859_13.c",  "iso8859_14.c", "iso8859_15.c", "iso8859_16.c",
            "euc_tw.c",            "euc_kr.c",            "big5.c",              "gb18030.c",     "koi8_r.c",     "cp1251.c",
        },
        .flags = &(library_flags ++ [_][]const u8{ "-DONIG_STATIC", "-DONIG_EXTERN=extern", "-DHAVE_CONFIG_H" }),
    });
    return .{
        .artifact = b.addLibrary(.{ .name = "onig", .linkage = .static, .root_module = m }),
        .include = dep.path("src"),
    };
}

/// Lua 5.1, the version Scribunto's modules are written for: the core and
/// the standard libraries, without the interpreter and compiler programs.
fn lua(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Library {
    const dep = b.dependency("lua", .{});
    const m = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    m.addCSourceFiles(.{
        .root = dep.path("src"),
        .files = &.{
            "lapi.c",    "lauxlib.c",  "lbaselib.c", "lcode.c",   "ldblib.c", "ldebug.c",   "ldo.c",     "ldump.c",
            "lfunc.c",   "lgc.c",      "linit.c",    "liolib.c",  "llex.c",   "lmathlib.c", "lmem.c",    "loadlib.c",
            "lobject.c", "lopcodes.c", "loslib.c",   "lparser.c", "lstate.c", "lstring.c",  "lstrlib.c", "ltable.c",
            "ltablib.c", "ltm.c",      "lundump.c",  "lvm.c",     "lzio.c",
        },
        .flags = &library_flags,
    });
    return .{
        .artifact = b.addLibrary(.{ .name = "lua5.1", .linkage = .static, .root_module = m }),
        .include = dep.path("src"),
    };
}

/// libxml2 with what PHP's XML extensions use, and without the parts that
/// reach outside the process (HTTP, loadable modules, system catalogs) or need other libraries
/// (iconv, ICU, zlib). Encodings beyond the built-in ones are not available
/// to the XML parser; UTF-8, UTF-16, ISO-8859-x and ASCII are built in.
fn libxml2(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) Library {
    const dep = b.dependency("libxml2", .{});
    const version = b.addConfigHeader(.{
        .style = .{ .autoconf_at = dep.path("include/libxml/xmlversion.h.in") },
        .include_path = "libxml/xmlversion.h",
    }, .{
        .VERSION = "2.15.4",
        .LIBXML_VERSION_NUMBER = 21504,
        .LIBXML_VERSION_EXTRA = "",
        .MODULE_EXTENSION = ".dll",
        .WITH_THREADS = 0,
        .WITH_THREAD_ALLOC = 0,
        .WITH_OUTPUT = 1,
        .WITH_PUSH = 1,
        .WITH_READER = 1,
        .WITH_PATTERN = 1,
        .WITH_WRITER = 1,
        .WITH_SAX1 = 1,
        .WITH_HTTP = 0,
        .WITH_VALID = 1,
        .WITH_HTML = 1,
        .WITH_C14N = 1,
        .WITH_CATALOG = 0,
        .WITH_XPATH = 1,
        .WITH_XPTR = 1,
        .WITH_XINCLUDE = 1,
        .WITH_ICONV = 0,
        .WITH_ICU = 0,
        .WITH_ISO8859X = 1,
        .WITH_DEBUG = 0,
        .WITH_REGEXPS = 1,
        .WITH_RELAXNG = 1,
        .WITH_SCHEMAS = 1,
        .WITH_SCHEMATRON = 0,
        .WITH_MODULES = 0,
        .WITH_ZLIB = 0,
    });
    const config = b.addWriteFiles();
    _ = config.add("config.h",
        \\/* Written by build.zig in place of libxml2's configure. */
        \\#define HAVE_STDINT_H 1
        \\#define HAVE_DECL_GETENTROPY 0
        \\#define HAVE_DECL_GLOB 0
        \\#define HAVE_DECL_MMAP 0
        \\
    );
    const m = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    m.addConfigHeader(version);
    m.addIncludePath(config.getDirectory());
    m.addIncludePath(dep.path("include"));
    m.addIncludePath(dep.path(""));
    m.addCSourceFiles(.{
        .root = dep.path(""),
        .files = &.{
            "HTMLparser.c", "HTMLtree.c",        "SAX2.c",            "buf.c",       "c14n.c",      "catalog.c",   "chvalid.c",
            "dict.c",       "encoding.c",        "entities.c",        "error.c",     "globals.c",   "hash.c",      "list.c",
            "parser.c",     "parserInternals.c", "pattern.c",         "relaxng.c",   "threads.c",   "tree.c",      "uri.c",
            "valid.c",      "xinclude.c",        "xlink.c",           "xmlIO.c",     "xmlmemory.c", "xmlreader.c", "xmlregexp.c",
            "xmlsave.c",    "xmlschemas.c",      "xmlschemastypes.c", "xmlstring.c", "xmlwriter.c", "xpath.c",     "xpointer.c",
        },
        .flags = &(library_flags ++ [_][]const u8{"-DLIBXML_STATIC"}),
    });
    m.linkSystemLibrary("bcrypt", .{});
    const lib = b.addLibrary(.{ .name = "xml2", .linkage = .static, .root_module = m });
    lib.installConfigHeader(version);
    return .{
        .artifact = lib,
        .include = dep.path("include"),
        .config_header = version,
    };
}

const Includes = struct {
    src: std.Build.LazyPath,
    spellings: std.Build.LazyPath,
    generated: std.Build.LazyPath,
};

fn addPhpIncludes(b: *std.Build, m: *std.Build.Module, inc: Includes) void {
    // Ours first: timelib_config.h and wsyslog.h, which PHP's Windows build
    // generates, and the header spellings.
    m.addIncludePath(b.path("compat"));
    m.addIncludePath(inc.spellings);
    // PHP includes its configuration as <../main/config.w32.h>, relative to an
    // include directory, and as "config.w32.h".
    m.addIncludePath(inc.generated);
    m.addIncludePath(inc.generated.path(b, "main"));
    m.addIncludePath(inc.src);
    for ([_][]const u8{
        "main",                      "Zend", "TSRM", "ext", "ext/date/lib", "ext/pcre/pcre2lib",
        "ext/hash/sha3/generic64lc",
    }) |dir| m.addIncludePath(inc.src.path(b, dir));
}
