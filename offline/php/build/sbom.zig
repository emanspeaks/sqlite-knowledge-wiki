//! The software bill of materials (`zig build sbom`).
const std = @import("std");
const components = @import("../components.zig");
const manifest = @import("../build.zig.zon");

/// The software bill of materials in CycloneDX 1.5 JSON, without the wiki
/// service's components, which tools/sbom_wiki.zig adds. Where each fetched
/// component comes from and its package hash are read from build.zig.zon
/// itself, so the SBOM cannot disagree with what is built; a dependency with
/// no entry in components.zig is a compile error. There is no timestamp or
/// serial number: the same sources give the same file.
pub fn sbom(b: *std.Build) ![]const u8 {
    comptime {
        for (@typeInfo(@TypeOf(manifest.dependencies)).@"struct".field_names) |dependency| {
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
    try out.appendSlice(arena, b.fmt(
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
    , .{try json(b, version)}));

    var first = true;
    inline for (components.fetched) |c| {
        const dep = @field(manifest.dependencies, c.dependency.?);
        try appendComponent(b, &out, &first, c, "fetched and built by offline/php/build.zig", dep.url, dep.hash);
    }
    for (components.bundled_in_php) |c| try appendComponent(b, &out, &first, c, "bundled in the PHP release", null, null);
    try out.appendSlice(arena, "\n  ]\n}\n");
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
) !void {
    const arena = b.allocator;
    if (!first.*) try out.appendSlice(arena, ",\n");
    first.* = false;
    // An SPDX identifier goes in "id"; anything else has to be a "name".
    const license_key = if (std.mem.startsWith(u8, c.license, "LicenseRef-")) "name" else "id";
    try out.appendSlice(arena, b.fmt(
        \\    {{
        \\      "type": "library",
        \\      "name": {s},
        \\      "version": {s},
        \\      "supplier": {{ "name": {s} }},
        \\      "description": {s},
        \\      "licenses": [{{ "license": {{ "{s}": {s} }} }}]
    , .{ try json(b, c.name), try json(b, c.version), try json(b, c.supplier), try json(b, c.purpose), license_key, try json(b, c.license) }));
    if (c.sha256.len != 0) {
        try out.appendSlice(arena, b.fmt(",\n      \"hashes\": [{{ \"alg\": \"SHA-256\", \"content\": {s} }}]", .{try json(b, c.sha256)}));
    }
    if (url) |u| {
        try out.appendSlice(arena, b.fmt(",\n      \"externalReferences\": [{{ \"type\": \"distribution\", \"url\": {s} }}]", .{try json(b, u)}));
    }
    try out.appendSlice(arena, b.fmt(",\n      \"properties\": [\n        {{ \"name\": \"origin\", \"value\": {s} }}", .{try json(b, origin)}));
    if (zig_hash) |h| try out.appendSlice(arena, b.fmt(",\n        {{ \"name\": \"zig-package-hash\", \"value\": {s} }}", .{try json(b, h)}));
    if (c.source.len != 0) try out.appendSlice(arena, b.fmt(",\n        {{ \"name\": \"source\", \"value\": {s} }}", .{try json(b, c.source)}));
    if (c.source_note.len != 0) try out.appendSlice(arena, b.fmt(",\n        {{ \"name\": \"source-note\", \"value\": {s} }}", .{try json(b, c.source_note)}));
    try out.appendSlice(arena, "\n      ]\n    }");
}

/// A JSON string literal. The values are plain ASCII text written in this
/// repository; quotes and backslashes are the only characters to escape.
fn json(b: *std.Build, text: []const u8) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    try out.append(b.allocator, '"');
    for (text) |ch| {
        if (ch == '"' or ch == '\\') try out.append(b.allocator, '\\');
        try out.append(b.allocator, ch);
    }
    try out.append(b.allocator, '"');
    return out.items;
}
