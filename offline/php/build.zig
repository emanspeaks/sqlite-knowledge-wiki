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
    "-DARG_MAX=14500",
    // ext/hash's SHA-3
    "-DKeccakP200_excluded",
    "-DKeccakP400_excluded",
    "-DKeccakP800_excluded",
};

/// Windows headers PHP includes under a spelling that Zig's bundled headers,
/// which are all lower-case, do not have. It only matters on build hosts with
/// case-sensitive file systems.
const header_spellings = [_][]const u8{
    "Sddl.h", "WinBase.h", "Winbase.h", "Wincrypt.h", "Windns.h", "Winsock2.h", "Winuser.h", "Ws2tcpip.h",
};

/// An optional extension compiled into the library. Each is built as its own
/// static library so that its include directories and flags stay its own
/// (several bundle a config.h).
const Extension = struct {
    name: []const u8,
    sources: []const []const u8,
    /// The header that declares the module, and the module pointer in it.
    header: []const u8,
    module: []const u8,
    /// Appended to main/config.w32.h, as PHP's configure would.
    config: []const u8,
    /// Include directories relative to the PHP sources.
    include_dirs: []const []const u8 = &.{},
    flags: []const []const u8 = &.{},
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
        // Without multibyte regular expressions, which would need Oniguruma.
        .name = "mbstring",
        .sources = &sources.mbstring,
        .header = "ext/mbstring/mbstring.h",
        .module = "phpext_mbstring_ptr",
        .config = "#define HAVE_MBSTRING 1\n",
        .include_dirs = &.{ "ext/mbstring", "ext/mbstring/libmbfl", "ext/mbstring/libmbfl/mbfl" },
        .flags = &.{ "-DHAVE_STRICMP", "-DMBFL_DLL_EXPORT=1", "-DHAVE_CONFIG_H" },
        // PHP's configure copies libmbfl/config.h.w32 to libmbfl/config.h.
        .generated = &.{.{ .name = "libmbfl/config.h", .contents = "#include \"config.h.w32\"\n" }},
    },
    .{
        .name = "pdo",
        .sources = &sources.pdo,
        .header = "ext/pdo/php_pdo.h",
        .module = "phpext_pdo_ptr",
        .config = "",
    },
    .{
        .name = "session",
        .sources = &sources.session,
        .header = "ext/session/php_session.h",
        .module = "phpext_session_ptr",
        .config = "#define HAVE_PHP_SESSION 1\n",
    },
    .{
        .name = "tokenizer",
        .sources = &sources.tokenizer,
        .header = "ext/tokenizer/php_tokenizer.h",
        .module = "phpext_tokenizer_ptr",
        .config = "#define HAVE_TOKENIZER 1\n",
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
    "ws2_32", "kernel32", "advapi32", "shell32", "iphlpapi", "dnsapi",
    "psapi",  "bcrypt",   "ole32",    "user32",  "shlwapi",
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
        includes_c.appendSlice(arena, b.fmt("#include \"{s}\"\n", .{ext.header})) catch @panic("OOM");
        modules_c.appendSlice(arena, b.fmt("\t{s},\n", .{ext.module})) catch @panic("OOM");
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
    , .{ includes_c.items, modules_c.items }));

    const includes: Includes = .{
        .src = src,
        .spellings = spellings.getDirectory(),
        .generated = generated.getDirectory(),
    };

    const php = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    addPhpIncludes(b, php, includes);
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
        addPhpIncludes(b, m, includes);
        const flags = std.mem.concat(arena, []const u8, &.{ &php_flags, ext.flags }) catch @panic("OOM");
        m.addCSourceFiles(.{ .root = src, .files = ext.sources, .flags = flags });
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
