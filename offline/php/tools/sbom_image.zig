//! The wiki service image's own components for the SBOM: its Debian packages,
//! its PHP, and the PHP extensions that are not part of PHP. Read from
//! image/inventory.tsv, which image/inventory.sh writes inside the image
//! (ci.yml's Server job). Its lines, tab-separated, `#` for comments:
//!   os       ID VERSION_ID                      (/etc/os-release)
//!   php      VERSION URL SHA256                 (the php image's PHP_* variables)
//!   php-ext  NAME VERSION
//!   deb      NAME VERSION ARCH SOURCE SOURCE_VERSION
const std = @import("std");
const entry = @import("sbom_entry.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const ParseError = error{ InventoryLineMalformed, InventoryIncomplete } || Allocator.Error;

const Extension = struct { name: []const u8, version: []const u8 };

const Package = struct {
    name: []const u8,
    version: []const u8,
    arch: []const u8,
    source: []const u8,
    source_version: []const u8,
};

pub const Inventory = struct {
    os_id: []const u8,
    os_version: []const u8,
    php_version: []const u8,
    php_url: []const u8,
    php_sha256: []const u8,
    extensions: []const Extension,
    packages: []const Package,
};

pub fn parse(arena: Allocator, text: []const u8) ParseError!Inventory {
    var os: ?[2][]const u8 = null;
    var php: ?[3][]const u8 = null;
    var extensions: std.ArrayList(Extension) = .empty;
    var packages: std.ArrayList(Package) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (line.len == 0 or line[0] == '#') continue;
        var fields: [6][]const u8 = undefined;
        var n: usize = 0;
        var it = std.mem.splitScalar(u8, line, '\t');
        while (it.next()) |f| : (n += 1) {
            if (n == fields.len) return error.InventoryLineMalformed;
            fields[n] = f;
        }
        const kind = fields[0];
        if (std.mem.eql(u8, kind, "os") and n == 3) {
            os = .{ fields[1], fields[2] };
        } else if (std.mem.eql(u8, kind, "php") and n == 4) {
            php = .{ fields[1], fields[2], fields[3] };
        } else if (std.mem.eql(u8, kind, "php-ext") and n == 3) {
            try extensions.append(arena, .{ .name = fields[1], .version = fields[2] });
        } else if (std.mem.eql(u8, kind, "deb") and n == 6) {
            try packages.append(arena, .{ .name = fields[1], .version = fields[2], .arch = fields[3], .source = fields[4], .source_version = fields[5] });
        } else return error.InventoryLineMalformed;
    }
    const o = os orelse return error.InventoryIncomplete;
    const p = php orelse return error.InventoryIncomplete;
    if (packages.items.len == 0) return error.InventoryIncomplete;
    return .{
        .os_id = o[0],
        .os_version = o[1],
        .php_version = p[0],
        .php_url = p[1],
        .php_sha256 = p[2],
        .extensions = extensions.items,
        .packages = packages.items,
    };
}

pub fn write(arena: Allocator, w: *Io.Writer, inv: Inventory) (Io.Writer.Error || Allocator.Error)!void {
    const origin = "the container image: image/inventory.tsv";
    try entry.write(w, .{
        .name = "PHP",
        .version = inv.php_version,
        .supplier = "The PHP Group",
        .description = "The PHP of the wiki service's image, built from the release by the official php image",
        .licenses = &.{"PHP-3.01"},
        .purl = try arena.print("pkg:generic/php@{s}?download_url={s}", .{ inv.php_version, try entry.purlEncode(arena, inv.php_url) }),
        .hash_alg = "SHA-256",
        .hash = inv.php_sha256,
        .url = inv.php_url,
        .origin = origin,
    });
    for (inv.extensions) |e| {
        try entry.write(w, .{
            .name = e.name,
            .version = e.version,
            .supplier = "PECL",
            .description = "A PHP extension of the image that is not part of PHP",
            .purl = try arena.print("pkg:generic/pecl/{s}@{s}", .{ e.name, try entry.purlEncode(arena, e.version) }),
            .origin = origin,
        });
    }
    for (inv.packages) |p| {
        try entry.write(w, .{
            .name = p.name,
            .version = p.version,
            .supplier = "Debian",
            .purl = try arena.print("pkg:deb/{s}/{s}@{s}?arch={s}&distro={s}-{s}", .{
                inv.os_id,
                p.name,
                try entry.purlEncode(arena, p.version),
                p.arch,
                inv.os_id,
                inv.os_version,
            }),
            .origin = origin,
            .source = try arena.print("{s} source package {s} {s}", .{ inv.os_id, p.source, p.source_version }),
        });
    }
}
