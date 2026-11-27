//! The wiki service image's own components for the SBOM: its Debian packages,
//! its PHP, and the PHP extensions installed from PECL. Read from
//! image/inventory.csv, which image/inventory.sh writes inside the image
//! (ci.yml's Server job): CSV, unquoted, with the header `header` and its
//! eight columns on every row. A row's kind says which columns it fills:
//!   os       name (ID), version (VERSION_ID)          /etc/os-release
//!   php      version, url, sha256                     the php image's PHP_*
//!   php-ext  name, version                            `pecl list`
//!   deb      name, version, arch, source, source_version
const std = @import("std");
const entry = @import("sbom_entry.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const header = "kind,name,version,arch,source,source_version,url,sha256";

pub const ParseError = error{ InventoryHeaderWrong, InventoryRowMalformed, InventoryIncomplete } || Allocator.Error;

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

const Row = struct { kind: []const u8, name: []const u8, version: []const u8, arch: []const u8, source: []const u8, source_version: []const u8, url: []const u8, sha256: []const u8 };

fn splitRow(line: []const u8) error{InventoryRowMalformed}!Row {
    var fields: [8][]const u8 = undefined;
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, line, ',');
    while (it.next()) |f| : (n += 1) {
        if (n == fields.len) return error.InventoryRowMalformed;
        fields[n] = f;
    }
    if (n != fields.len) return error.InventoryRowMalformed;
    return .{ .kind = fields[0], .name = fields[1], .version = fields[2], .arch = fields[3], .source = fields[4], .source_version = fields[5], .url = fields[6], .sha256 = fields[7] };
}

pub fn parse(arena: Allocator, text: []const u8) ParseError!Inventory {
    var os: ?Row = null;
    var php: ?Row = null;
    var extensions: std.ArrayList(Extension) = .empty;
    var packages: std.ArrayList(Package) = .empty;
    var lines = std.mem.splitScalar(u8, text, '\n');
    if (!std.mem.eql(u8, std.mem.trimEnd(u8, lines.first(), "\r"), header)) return error.InventoryHeaderWrong;
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (line.len == 0) continue;
        const r = try splitRow(line);
        if (std.mem.eql(u8, r.kind, "os")) {
            os = r;
        } else if (std.mem.eql(u8, r.kind, "php")) {
            php = r;
        } else if (std.mem.eql(u8, r.kind, "php-ext")) {
            try extensions.append(arena, .{ .name = r.name, .version = r.version });
        } else if (std.mem.eql(u8, r.kind, "deb")) {
            try packages.append(arena, .{ .name = r.name, .version = r.version, .arch = r.arch, .source = r.source, .source_version = r.source_version });
        } else return error.InventoryRowMalformed;
    }
    const o = os orelse return error.InventoryIncomplete;
    const p = php orelse return error.InventoryIncomplete;
    if (packages.items.len == 0) return error.InventoryIncomplete;
    return .{
        .os_id = o.name,
        .os_version = o.version,
        .php_version = p.version,
        .php_url = p.url,
        .php_sha256 = p.sha256,
        .extensions = extensions.items,
        .packages = packages.items,
    };
}

pub fn write(arena: Allocator, w: *Io.Writer, inv: Inventory) (Io.Writer.Error || Allocator.Error)!void {
    const origin = "the container image: image/inventory.csv";
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
            .description = "A PHP extension of the image, installed from PECL",
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
