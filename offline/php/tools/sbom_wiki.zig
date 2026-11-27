//! sbom_wiki: completes the SBOM with the wiki service's components.
//!
//!   sbom_wiki BASE.json DOCKERFILE COMPOSER.lock OUT.json
//!
//! BASE.json is the SBOM build.zig writes (PHP and its libraries). This adds
//! the two images and the Wikibase commit pinned in the Dockerfile, and every
//! package of the Composer lock, so the SBOM names exactly what the image
//! holds. Run as a build step, so a changed Dockerfile or lock is noticed.
const std = @import("std");

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

/// Writes `text` as a JSON string.
fn str(w: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    try std.json.Stringify.value(text, .{}, w);
}

const Entry = struct {
    name: []const u8,
    version: []const u8,
    supplier: []const u8,
    description: []const u8,
    licenses: []const []const u8,
    purl: []const u8,
    hash_alg: []const u8 = "",
    hash: []const u8 = "",
    url: []const u8 = "",
    origin: []const u8,
    source: []const u8 = "",
    reference: []const u8 = "",
};

fn writeEntry(w: *Io.Writer, e: Entry) Io.Writer.Error!void {
    try w.writeAll(",\n    {\n      \"type\": \"library\",\n      \"name\": ");
    try str(w, e.name);
    try w.writeAll(",\n      \"version\": ");
    try str(w, e.version);
    try w.writeAll(",\n      \"supplier\": { \"name\": ");
    try str(w, e.supplier);
    try w.writeAll(" },\n      \"description\": ");
    try str(w, e.description);
    try w.writeAll(",\n      \"purl\": ");
    try str(w, e.purl);
    try w.writeAll(",\n      \"licenses\": [");
    for (e.licenses, 0..) |license, i| {
        if (i != 0) try w.writeAll(", ");
        // an SPDX expression ("(MIT or GPL-2.0)") or identifier
        try w.writeAll(if (std.mem.findAny(u8, license, " ()") != null) "{ \"expression\": " else "{ \"license\": { \"id\": ");
        try str(w, license);
        try w.writeAll(if (std.mem.findAny(u8, license, " ()") != null) " }" else " } }");
    }
    try w.writeAll("]");
    if (e.hash.len != 0) {
        try w.writeAll(",\n      \"hashes\": [{ \"alg\": ");
        try str(w, e.hash_alg);
        try w.writeAll(", \"content\": ");
        try str(w, e.hash);
        try w.writeAll(" }]");
    }
    if (e.url.len != 0) {
        try w.writeAll(",\n      \"externalReferences\": [{ \"type\": \"distribution\", \"url\": ");
        try str(w, e.url);
        try w.writeAll(" }]");
    }
    try w.writeAll(",\n      \"properties\": [\n        { \"name\": \"origin\", \"value\": ");
    try str(w, e.origin);
    try w.writeAll(" }");
    if (e.source.len != 0) {
        try w.writeAll(",\n        { \"name\": \"source\", \"value\": ");
        try str(w, e.source);
        try w.writeAll(" }");
    }
    if (e.reference.len != 0) {
        try w.writeAll(",\n        { \"name\": \"source-reference\", \"value\": ");
        try str(w, e.reference);
        try w.writeAll(" }");
    }
    try w.writeAll("\n      ]\n    }");
}

fn writeWiki(arena: std.mem.Allocator, w: *Io.Writer, pins: Pins, lock: Lock) !void {
    const image_origin = "the container build: an image pinned by digest in the Dockerfile";
    try writeEntry(w, .{
        .name = "MediaWiki",
        .version = pins.mediawiki.tag,
        .supplier = "Wikimedia Foundation and contributors",
        .description = "The wiki: the official Docker image, which also carries PHP, Apache, the bundled extensions and Debian's packages (not listed here)",
        .licenses = &.{"GPL-2.0-or-later"},
        .purl = try arena.print("pkg:docker/library/{s}@sha256%3A{s}?tag={s}", .{ pins.mediawiki.name, pins.mediawiki.digest, pins.mediawiki.tag }),
        .hash_alg = "SHA-256",
        .hash = pins.mediawiki.digest,
        .url = try arena.print("https://hub.docker.com/_/{s}", .{pins.mediawiki.name}),
        .origin = image_origin,
    });
    try writeEntry(w, .{
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
    try writeEntry(w, .{
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
        try writeEntry(w, .{
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
    if (args.len != 5) {
        std.log.err("usage: sbom_wiki BASE.json DOCKERFILE COMPOSER.lock OUT.json", .{});
        return error.Usage;
    }
    const cwd = Io.Dir.cwd();
    const base = try cwd.readFileAlloc(io, args[1], arena, .limited(1 << 24));
    const dockerfile = try cwd.readFileAlloc(io, args[2], arena, .limited(1 << 20));
    const lock_text = try cwd.readFileAlloc(io, args[3], arena, .limited(1 << 26));
    const pins = try readPins(dockerfile);
    const lock = try std.json.parseFromSliceLeaky(Lock, arena, lock_text, .{ .ignore_unknown_fields = true });

    // BASE ends with its components' closing bracket; the wiki's go before it
    const tail = "\n  ]\n}\n";
    if (!std.mem.endsWith(u8, base, tail)) return error.UnexpectedBase;

    var out: Io.Writer.Allocating = .init(arena);
    try out.writer.writeAll(base[0 .. base.len - tail.len]);
    try writeWiki(arena, &out.writer, pins, lock);
    try out.writer.writeAll(tail);
    try cwd.writeFile(io, .{ .sub_path = args[4], .data = out.written() });
}
