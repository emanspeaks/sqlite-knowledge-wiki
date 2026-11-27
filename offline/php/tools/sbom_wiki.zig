//! sbom_wiki: completes the SBOM with the wiki service's components.
//!
//!   sbom_wiki BASE.json DOCKERFILE COMPOSER.lock INVENTORY.csv OUT.json
//!
//! BASE.json is the SBOM build.zig writes (PHP and its libraries). This adds
//! the two images and the Wikibase commit pinned in the Dockerfile, every
//! package of the Composer lock, and the image's Debian packages, PHP and PHP
//! extensions (image/inventory.csv), so the SBOM names what the image holds.
//! Run as a build step, so a changed input is noticed.
const std = @import("std");
const entry = @import("sbom_entry.zig");
const image = @import("sbom_image.zig");

const Io = std.Io;

const Package = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8 = "",
    license: []const []const u8 = &.{},
    source: ?struct { url: []const u8 = "", reference: []const u8 = "" } = null,
    dist: ?struct { url: []const u8 = "", shasum: ?[]const u8 = null } = null,
};

const Lock = struct { packages: []const Package };

/// An image reference pinned by digest: `name:tag@sha256:hex`.
const Image = struct {
    name: []const u8,
    tag: []const u8,
    digest: []const u8,

    fn parse(ref: []const u8) error{ImageNotPinned}!Image {
        const at = std.mem.find(u8, ref, "@sha256:") orelse return error.ImageNotPinned;
        const colon = std.mem.findScalar(u8, ref[0..at], ':') orelse return error.ImageNotPinned;
        return .{ .name = ref[0..colon], .tag = ref[colon + 1 .. at], .digest = ref[at + "@sha256:".len ..] };
    }
};

const Pins = struct {
    mediawiki: Image,
    composer: Image,
    wikibase_commit: []const u8,
    wikibase_branch: []const u8,
    wikibase_url: []const u8,
};

fn readPins(dockerfile: []const u8) error{ PinMissing, ImageNotPinned }!Pins {
    var mediawiki: ?[]const u8 = null;
    var composer: ?[]const u8 = null;
    var commit: ?[]const u8 = null;
    var branch: ?[]const u8 = null;
    var url: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, dockerfile, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (std.mem.startsWith(u8, line, "ARG MEDIAWIKI_IMAGE=")) mediawiki = line["ARG MEDIAWIKI_IMAGE=".len..];
        if (std.mem.startsWith(u8, line, "ARG WIKIBASE_COMMIT=")) commit = line["ARG WIKIBASE_COMMIT=".len..];
        if (std.mem.startsWith(u8, line, "ARG WIKIBASE_BRANCH=")) branch = line["ARG WIKIBASE_BRANCH=".len..];
        if (std.mem.startsWith(u8, line, "ARG WIKIBASE_GIT_URL=")) url = line["ARG WIKIBASE_GIT_URL=".len..];
        if (std.mem.startsWith(u8, line, "FROM composer:")) {
            const ref = line["FROM ".len..];
            composer = ref[0 .. std.mem.findScalar(u8, ref, ' ') orelse ref.len];
        }
    }
    return .{
        .mediawiki = try Image.parse(mediawiki orelse return error.PinMissing),
        .composer = try Image.parse(composer orelse return error.PinMissing),
        .wikibase_commit = commit orelse return error.PinMissing,
        .wikibase_branch = branch orelse return error.PinMissing,
        .wikibase_url = url orelse return error.PinMissing,
    };
}

fn writeWiki(arena: std.mem.Allocator, w: *Io.Writer, pins: Pins, lock: Lock) !void {
    const image_origin = "the container build: an image pinned by digest in the Dockerfile";
    try entry.write(w, .{
        .name = "MediaWiki",
        .version = pins.mediawiki.tag,
        .supplier = "Wikimedia Foundation and contributors",
        .description = "The wiki: the official Docker image, with MediaWiki's bundled extensions and skins; the image's PHP and Debian packages are listed apart",
        .licenses = &.{"GPL-2.0-or-later"},
        .purl = try arena.print("pkg:docker/library/{s}@sha256%3A{s}?tag={s}", .{ pins.mediawiki.name, pins.mediawiki.digest, pins.mediawiki.tag }),
        .hash_alg = "SHA-256",
        .hash = pins.mediawiki.digest,
        .url = try arena.print("https://hub.docker.com/_/{s}", .{pins.mediawiki.name}),
        .origin = image_origin,
    });
    try entry.write(w, .{
        .name = "Composer",
        .version = pins.composer.tag,
        .supplier = "Nils Adermann, Jordi Boggiano and contributors",
        .description = "The PHP package manager, copied into the image from its official Docker image",
        .licenses = &.{"MIT"},
        .purl = try arena.print("pkg:docker/library/{s}@sha256%3A{s}?tag={s}", .{ pins.composer.name, pins.composer.digest, pins.composer.tag }),
        .hash_alg = "SHA-256",
        .hash = pins.composer.digest,
        .url = try arena.print("https://hub.docker.com/_/{s}", .{pins.composer.name}),
        .origin = image_origin,
    });
    try entry.write(w, .{
        .name = "Wikibase",
        .version = try arena.print("{s}@{s}", .{ pins.wikibase_branch, pins.wikibase_commit[0..12] }),
        .supplier = "Wikimedia Deutschland",
        .description = "Structured data repository and client, with its git submodules (pinned by the commit)",
        .licenses = &.{"GPL-2.0-or-later"},
        .purl = try arena.print("pkg:generic/wikibase@{s}?vcs_url=git%2B{s}", .{ pins.wikibase_commit, pins.wikibase_url }),
        .url = pins.wikibase_url,
        .origin = "the container build: a git commit pinned in the Dockerfile",
        .reference = pins.wikibase_commit,
    });
    for (lock.packages) |p| {
        const shasum = if (p.dist) |d| d.shasum orelse "" else "";
        try entry.write(w, .{
            .name = p.name,
            .version = p.version,
            .supplier = p.name[0 .. std.mem.findScalar(u8, p.name, '/') orelse p.name.len],
            .description = p.description,
            .licenses = p.license,
            .purl = try arena.print("pkg:composer/{s}@{s}", .{ p.name, p.version }),
            .hash_alg = if (shasum.len != 0) "SHA-1" else "",
            .hash = shasum,
            .url = if (p.dist) |d| d.url else "",
            .origin = "the container build: composer/composer.lock",
            .source = if (p.source) |s| s.url else "",
            .reference = if (p.source) |s| s.reference else "",
        });
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    if (args.len != 6) {
        std.log.err("usage: sbom_wiki BASE.json DOCKERFILE COMPOSER.lock INVENTORY.csv OUT.json", .{});
        return error.Usage;
    }
    const cwd = Io.Dir.cwd();
    const base = try cwd.readFileAlloc(io, args[1], arena, .limited(1 << 24));
    const dockerfile = try cwd.readFileAlloc(io, args[2], arena, .limited(1 << 20));
    const lock_text = try cwd.readFileAlloc(io, args[3], arena, .limited(1 << 26));
    const inventory_text = try cwd.readFileAlloc(io, args[4], arena, .limited(1 << 24));
    const pins = try readPins(dockerfile);
    const lock = try std.json.parseFromSliceLeaky(Lock, arena, lock_text, .{ .ignore_unknown_fields = true });
    const inventory = try image.parse(arena, inventory_text);

    // BASE ends with its components' closing bracket; the wiki's go before it
    const tail = "\n  ]\n}\n";
    if (!std.mem.endsWith(u8, base, tail)) return error.UnexpectedBase;

    var out: Io.Writer.Allocating = .init(arena);
    try out.writer.writeAll(base[0 .. base.len - tail.len]);
    try writeWiki(arena, &out.writer, pins, lock);
    try image.write(arena, &out.writer, inventory);
    try out.writer.writeAll(tail);
    try cwd.writeFile(io, .{ .sub_path = args[5], .data = out.written() });
}
