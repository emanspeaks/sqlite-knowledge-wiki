<!-- skein: begin; written by 'skein agents', which writes it again -->

## Skein

This repository keeps its requirements, specifications and their traceability with Skein (<https://github.com/chasingdaylight/skein>). An item is a paragraph or list entry of a Markdown document, or a Markdown file of its own, with a marker:

```markdown
%TYPE[ID words key=value,value] The text of the item.

- %TYPE[.part] A part of the item above, as a list entry.
```

- A marker is `%`, the item type, and in brackets the ID, then bare words (the category and the status) and `key=value` (an attribute, or links to the items named, separated by commas). `.part` names a part by its whole's ID.
- `%[ID]` in text refers to an item; `%[ID some words]` shows the words in its place.
- IDs never change by hand: `skein move OLD NEW` renames one everywhere. `skein new TYPE` starts an item, `skein link FROM TYPE TO` adds a link.
- Items are in `docs/`, `standards/npr7150.2d/` (read-only: an external standard, not to be edited).

After editing documents, item files or `.skein/`, run `skein check` and mend what it reports. `skein trace ID` shows an item with everything above and below it, and `skein coverage` what is not yet linked or cited. `skein mcp` offers all of this as tools to agents that speak the Model Context Protocol.

<!-- skein: end -->
