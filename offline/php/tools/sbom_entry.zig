//! One component of the SBOM in CycloneDX 1.5 JSON, as sbom_wiki writes them
//! after the base SBOM's.
const std = @import("std");

const Io = std.Io;

pub const Entry = struct {
    name: []const u8,
    version: []const u8,
    supplier: []const u8,
    description: []const u8 = "",
    licenses: []const []const u8 = &.{},
    purl: []const u8,
    hash_alg: []const u8 = "",
    hash: []const u8 = "",
    url: []const u8 = "",
    origin: []const u8,
    source: []const u8 = "",
    reference: []const u8 = "",
};

/// Writes `text` as a JSON string.
fn str(w: *Io.Writer, text: []const u8) Io.Writer.Error!void {
    try std.json.Stringify.value(text, .{}, w);
}

/// Writes `e` as an element of the components array, after another.
pub fn write(w: *Io.Writer, e: Entry) Io.Writer.Error!void {
    try w.writeAll(",\n    {\n      \"type\": \"library\",\n      \"name\": ");
    try str(w, e.name);
    try w.writeAll(",\n      \"version\": ");
    try str(w, e.version);
    try w.writeAll(",\n      \"supplier\": { \"name\": ");
    try str(w, e.supplier);
    try w.writeAll(" }");
    if (e.description.len != 0) {
        try w.writeAll(",\n      \"description\": ");
        try str(w, e.description);
    }
    try w.writeAll(",\n      \"purl\": ");
    try str(w, e.purl);
    if (e.licenses.len != 0) {
        try w.writeAll(",\n      \"licenses\": [");
        for (e.licenses, 0..) |license, i| {
            if (i != 0) try w.writeAll(", ");
            // an SPDX expression ("(MIT or GPL-2.0)") or identifier
            const expression = std.mem.findAny(u8, license, " ()") != null;
            try w.writeAll(if (expression) "{ \"expression\": " else "{ \"license\": { \"id\": ");
            try str(w, license);
            try w.writeAll(if (expression) " }" else " } }");
        }
        try w.writeAll("]");
    }
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

/// `text` percent-encoded for a purl's version or qualifier value: all but
/// letters, digits and `.-_~`.
pub fn purlEncode(arena: std.mem.Allocator, text: []const u8) std.mem.Allocator.Error![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    for (text) |ch| {
        if (std.ascii.isAlphanumeric(ch) or std.mem.findScalar(u8, ".-_~", ch) != null) {
            try out.append(arena, ch);
        } else {
            try out.print(arena, "%{X:0>2}", .{ch});
        }
    }
    return out.items;
}
