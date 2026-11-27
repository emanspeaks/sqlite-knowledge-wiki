//! The third-party libraries, each built from its release in build.zig.zon.
const std = @import("std");
const icu_sources = @import("../icu_sources.zig");

/// A third-party library built from its release in build.zig.zon.
pub const Library = struct {
    artifact: *std.Build.Step.Compile,
    include: std.Build.LazyPath,
    /// A header the library's own configure step would have generated.
    config_header: ?*std.Build.Step.ConfigHeader = null,
    /// More header directories.
    extra_include: ?std.Build.LazyPath = null,
    extra_include2: ?std.Build.LazyPath = null,

    pub fn addTo(lib: Library, m: *std.Build.Module) void {
        m.addIncludePath(lib.include);
        if (lib.extra_include) |dir| m.addIncludePath(dir);
        if (lib.extra_include2) |dir| m.addIncludePath(dir);
        if (lib.config_header) |h| m.addConfigHeader(h);
        m.linkLibrary(lib.artifact);
    }
};

/// Flags for third-party C: no warnings, and no UBSan in Debug builds.
pub const library_flags = [_][]const u8{ "-w", "-fno-sanitize=undefined" };

pub fn zlib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) Library {
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

pub fn sqlite(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) Library {
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
pub fn icu(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) Library {
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

pub fn libpng(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.OptimizeMode,
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
pub fn jpeg(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) Library {
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
pub fn winIconv(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) Library {
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
/// functions, which the Math extension uses. BSD license.
pub fn oniguruma(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) Library {
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
pub fn lua(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) Library {
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
pub fn libxml2(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.lang.OptimizeMode) Library {
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
