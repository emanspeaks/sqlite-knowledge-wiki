#!/usr/bin/env python3
"""Pack a directory tree into one WVFS file.

    pack.py SRC_DIR OUT_FILE

Layout (little-endian):
    header   32 bytes: magic "WVFS1\\0\\0\\0", u32 entry count, u32 mtime,
                       u64 offset of the string table, u64 file size
    entries  32 bytes each, sorted by path (bytewise, shorter first):
                       u32 path offset, u32 path length, u64 data offset,
                       u64 data size, u32 flags (1 = directory), u32 child count
    strings  the paths, relative to the root, no leading slash; root is ""
    data     file contents, uncompressed, each aligned to 8 bytes.
             A directory's data is its child names, each NUL-terminated.
"""
import os, struct, sys, time

SKIP = {".git", "tests", "images", "node_modules"}

def main():
    src, out = sys.argv[1], sys.argv[2]
    entries = {}  # relative path (bytes) -> (is_dir, payload or real path)
    for root, dirs, files in os.walk(src):
        dirs[:] = sorted(d for d in dirs if d not in SKIP)
        rel = os.path.relpath(root, src)
        rel = "" if rel == "." else rel
        names = []
        for name in sorted(dirs):
            names.append(name)
        for name in sorted(files):
            full = os.path.join(root, name)
            if not os.path.isfile(full):   # broken symlink
                continue
            names.append(name)
            entries[os.path.join(rel, name).encode()] = (False, full)
        entries[rel.encode()] = (True, b"".join(n.encode() + b"\0" for n in names), len(names))

    paths = sorted(entries)
    strings = b"".join(paths)
    header_size, entry_size = 32, 32
    strings_off = header_size + entry_size * len(paths)
    data_off = (strings_off + len(strings) + 7) & ~7

    table, pos, path_pos = [], data_off, 0
    with open(out, "wb") as f:
        f.seek(data_off)
        for p in paths:
            e = entries[p]
            if e[0]:
                payload, count, flags = e[1], e[2], 1
            else:
                with open(e[1], "rb") as g:
                    payload = g.read()
                count, flags = 0, 0
            f.write(payload)
            table.append(struct.pack("<IIQQII", path_pos, len(p), pos, len(payload), flags, count))
            path_pos += len(p)
            pad = (-len(payload)) & 7
            f.write(b"\0" * pad)
            pos += len(payload) + pad
        f.seek(0)
        f.write(struct.pack("<8sIIQQ", b"WVFS1\0\0\0", len(paths), int(time.time()) - 86400, strings_off, pos))
        f.write(b"".join(table))
        f.write(strings)
    print(f"{len(paths)} entries, {pos} bytes")

if __name__ == "__main__":
    main()
