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
    const includes: Includes = .{ .src = src, .spellings = spellings.getDirectory() };

    const php = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    addPhpIncludes(b, php, includes);
    php.addCSourceFiles(.{ .root = src, .files = &sources.core, .flags = &php_flags });
    php.addCSourceFiles(.{
        .root = src,
        .files = &sources.pcre2,
        .flags = &(php_flags ++ [_][]const u8{"-DHAVE_CONFIG_H"}),
    });
    php.addCSourceFile(.{ .file = b.path("compat/internal_functions.c"), .flags = &php_flags });
    // Fibers: PHP ships these two routines for Windows only in Microsoft
    // assembler syntax; these are the same routines from Boost.Context in the
    // syntax clang assembles.
    php.addAssemblyFile(b.path("asm/jump_x86_64_ms_pe_clang_gas.S"));
    php.addAssemblyFile(b.path("asm/make_x86_64_ms_pe_clang_gas.S"));
    for (system_libs) |name| php.linkSystemLibrary(name, .{});

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

const Includes = struct { src: std.Build.LazyPath, spellings: std.Build.LazyPath };

fn addPhpIncludes(b: *std.Build, m: *std.Build.Module, inc: Includes) void {
    // Ours first: timelib_config.h and wsyslog.h, which PHP's Windows build
    // generates, and the header spellings.
    m.addIncludePath(b.path("compat"));
    m.addIncludePath(inc.spellings);
    // PHP includes its configuration as <../main/config.w32.h>, relative to an
    // include directory, and as "config.w32.h".
    m.addIncludePath(b.path("compat/main"));
    m.addIncludePath(inc.src);
    for ([_][]const u8{
        "main",                      "Zend", "TSRM", "ext", "ext/date/lib", "ext/pcre/pcre2lib",
        "ext/hash/sha3/generic64lc",
    }) |dir| m.addIncludePath(inc.src.path(b, dir));
}
