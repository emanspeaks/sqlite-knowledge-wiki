//! Builds PHP as a static library for Windows with nothing but Zig: the
//! compiler, the linker and the Windows headers and C runtime are the ones Zig
//! bundles (MinGW-w64). No Microsoft toolchain or SDK is used.
//!
//! The PHP sources are the official release named in build.zig.zon. They are
//! copied into the build cache and patches/ is applied to the copy.
//!
//!   zig build            static library and the smoke-test program
//!   zig build -Doptimize=fast
const std = @import("std");
const sources = @import("sources.zig");
const components = @import("components.zig");
const extension_table = @import("build/extensions.zig");
const libs = @import("build/libraries.zig");
const sbom = @import("build/sbom.zig").sbom;

const Extension = extension_table.Extension;
const extensions = extension_table.extensions;
const builtin_modules = extension_table.builtin_modules;
const Library = libs.Library;
const library_flags = libs.library_flags;

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

const system_libs = [_][]const u8{
    "ws2_32",  "kernel32", "advapi32", "shell32", "iphlpapi", "dnsapi",
    "psapi",   "bcrypt",   "ole32",    "user32",  "shlwapi",
    // ext/gd (screen capture functions)
     "gdi32",
    // the smoke program's crash handler
    "dbghelp",
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{
        .default_target = .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    });
    const optimize = b.standardOptimizeOption(.{});

    // The pristine release, copied into the cache with the patches applied.
    const prepare_mod = b.createModule(.{
        .target = b.resolveTargetQuery(.{}),
        .optimize = .safe,
        .link_libc = true,
    });
    prepare_mod.addCSourceFile(.{ .file = b.path("tools/prepare_src.c") });
    const prepare = b.addRunArtifact(b.addExecutable(.{ .name = "prepare_src", .root_module = prepare_mod }));
    prepare.addDirectoryArg2(b.dependency("php", .{}).path(""), .{});
    const src = prepare.addOutputDirectoryArg2("php-src", .{});
    prepare.addFileArg2(b.path("patches/php-8.3-mingw.patch"), .{});
    prepare.addFileArg2(b.path("patches/php-8.3-opcache-embed.patch"), .{});

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
    try config.appendSlice(arena, "#include \"config.base.h\"\n");
    for (builtin_modules) |m| {
        try includes_c.appendSlice(arena, b.fmt("#include \"{s}\"\n", .{m[0]}));
        try modules_c.appendSlice(arena, b.fmt("\t{s},\n", .{m[1]}));
    }
    for (extensions) |ext| {
        try config.appendSlice(arena, ext.config);
        if (ext.header) |header| try includes_c.appendSlice(arena, b.fmt("#include \"{s}\"\n", .{header}));
        if (ext.module) |module| try modules_c.appendSlice(arena, b.fmt("\t{s},\n", .{module}));
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
    try libraries.put(arena, "zlib", libs.zlib(b, target, optimize));
    try libraries.put(arena, "sqlite", libs.sqlite(b, target, optimize));
    try libraries.put(arena, "libxml2", libs.libxml2(b, target, optimize));
    try libraries.put(arena, "lua", libs.lua(b, target, optimize));
    try libraries.put(arena, "win_iconv", libs.winIconv(b, target, optimize));
    try libraries.put(arena, "oniguruma", libs.oniguruma(b, target, optimize));
    try libraries.put(arena, "libpng", libs.libpng(b, target, optimize, libraries.get("zlib").?));
    try libraries.put(arena, "jpeg", libs.jpeg(b, target, optimize));
    try libraries.put(arena, "icu", libs.icu(b, target, optimize));

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
        .optimize = .safe,
        .link_libc = true,
    });
    masm2gas_mod.addCSourceFile(.{ .file = b.path("tools/masm2gas.c") });
    const masm2gas = b.addExecutable(.{ .name = "masm2gas", .root_module = masm2gas_mod });
    for ([_][]const u8{ "jump", "make" }) |routine| {
        const convert = b.addRunArtifact(masm2gas);
        convert.addFileArg2(src.path(b, b.fmt("Zend/asm/{s}_x86_64_ms_pe_masm.asm", .{routine})), .{});
        php.addAssemblyFile(convert.addOutputFileArg2(b.fmt("{s}_fcontext.S", .{routine}), .{}));
    }
    // Windows and MinGW import libraries: pkg-config knows none of them, and on
    // GitHub's Windows runners the one on the PATH (Strawberry Perl's) fails
    for (system_libs) |name| php.linkSystemLibrary(name, .{ .use_pkg_config = .no });

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
        const flags = try std.mem.concat(arena, []const u8, &.{ &php_flags, ext.flags });
        for (ext.own_sources) |file| m.addCSourceFile(.{ .file = b.path(file), .flags = &library_flags });
        for (ext.system_libs) |name| m.linkSystemLibrary(name, .{ .use_pkg_config = .no });
        const root = if (ext.package) |package| b.dependency(package, .{}).path(ext.package_dir) else src;
        if (ext.cxx) {
            // -fms-extensions is for PHP's C; the C++ sources get C++17, which ICU's headers need.
            var c_files: std.ArrayList([]const u8) = .empty;
            var cxx_files: std.ArrayList([]const u8) = .empty;
            for (ext.sources) |file| {
                const list = if (std.mem.endsWith(u8, file, ".cpp")) &cxx_files else &c_files;
                try list.append(arena, file);
            }
            const cxx_flags = try std.mem.concat(arena, []const u8, &.{ flags, &.{"-std=c++17"} });
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

    // `zig build licenses`: every component's license text, zig-out/licenses/.
    // They go out with the program.
    const licenses_step = b.step("licenses", "Collect the license texts of the third-party components");
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
    // The offline viewer's components come from this build's manifest; the
    // wiki service's from the Dockerfile, the Composer lock and the image's
    // inventory, which a build step reads so that a change to them is noticed.
    const sbom_files = b.addWriteFiles();
    const sbom_base = sbom_files.add("sbom-base.cdx.json", try sbom(b));
    const sbom_wiki = b.addRunArtifact(b.addExecutable(.{ .name = "sbom_wiki", .root_module = b.createModule(.{
        .root_source_file = b.path("tools/sbom_wiki.zig"),
        .target = b.graph.host,
        .optimize = .safe,
    }) }));
    sbom_wiki.addFileArg2(sbom_base, .{});
    sbom_wiki.addFileArg2(b.path("../../Dockerfile"), .{});
    sbom_wiki.addFileArg2(b.path("../../composer/composer.lock"), .{});
    sbom_wiki.addFileArg2(b.path("../../image/inventory.csv"), .{});
    const sbom_file = sbom_wiki.addOutputFileArg2("sbom.cdx.json", .{});
    const sbom_step = b.step("sbom", "Write the software bill of materials (CycloneDX JSON)");
    sbom_step.dependOn(&b.addInstallFile(sbom_file, "sbom.cdx.json").step);
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
