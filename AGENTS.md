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
- Items are in `docs/`, `standards/npr7150.2d/` (read-only: an external standard, not to be edited), `standards/nasa-std-8739.8b/` (read-only: an external standard, not to be edited).

Item types:

- `assurance`: A row of the software assurance requirements mapping matrix (handbook topic 8.51): how the assurance organization carries out tasks of the standard, or the IV&V Provider a requirement of section 4.4.2; categories `FC`, `T`, `PC`, `NC`, `NA`; statuses `draft`, `approved`, `deprecated`, `removed`; attributes `component`, `evidence`, `rationale`, `risk`.
- `compliance`: A row of the project's Requirements Mapping Matrix (SWE-125): how the project, or one of its software components, meets a requirement of the NPR; categories `FC`, `T`, `PC`, `NC`, `NA`; statuses `draft`, `approved`, `deprecated`, `removed`; attributes `component`, `evidence`, `rationale`, `risk`.
- `design`: A software design component (SWE-057, SWE-058; 5.13 SwDD), which the code that implements it cites; statuses `draft`, `approved`, `deprecated`, `removed`.
- `guidance`: The NASA Software Engineering Handbook's reading of a requirement: its objective evidence, documents and software assurance; read-only, from skein's template; statuses `draft`, `approved`, `deprecated`, `removed`.
- `hazard`: A system hazard, or a hazard cause, control or mitigation, that software is part of (5.24 Hazard Report); statuses `draft`, `approved`, `deprecated`, `removed`.
- `ivv`: A requirement of NASA-STD-8739.8B on the IV&V Provider (section 4.4.2); read-only, from skein's template; statuses `draft`, `approved`, `deprecated`, `removed`; attributes `section`.
- `nonconformance`: A software non-conformance or problem report (SWE-201; 5.01 CR-PR), with its severity (SWE-202); categories `1`, `2`, `3`, `4`; statuses `open`, `analyzed`, `fixed`, `verified`, `closed`, `rejected`.
- `procedure`: A test procedure or test case (SWE-065; 5.14), with its pass and fail criteria; its results are recorded with skein result; categories `unit`, `integration`, `system`, `acceptance`, `regression`; statuses `draft`, `approved`, `deprecated`, `removed`.
- `product`: A software product and its expected maturity at each milestone review (NASA Software Engineering Handbook, topic 7.08); read-only, from skein's template; categories `engineering`, `assurance`, `ongoing`; statuses `draft`, `approved`, `deprecated`, `removed`; attributes `topic`, `mcr`, `srr`, `sw_rr`, `mdr`, `sdr`, `pdr`, `cdr`, `sir`, `trr`, `sar`, `orr`.
- `requirement`: A software requirement (SWE-050), specific, testable and traceable, with how it is verified (5.09 SRS, qualification provisions); categories `functional`, `performance`, `interface`, `safety`, `security`, `quality`, `constraint`; statuses `draft`, `tbd`, `tbr`, `approved`, `deprecated`, `removed`; attributes `rationale`.
- `sass`: A requirement of NASA-STD-8739.8B numbered by the standard (SASS-01); read-only, from skein's template; statuses `draft`, `approved`, `deprecated`, `removed`.
- `satask`: The software assurance and software safety tasks of NASA-STD-8739.8B (Table 1) for a requirement of NPR 7150.2D, each task a part; read-only, from skein's template; statuses `draft`, `approved`, `deprecated`, `removed`; attributes `classes`, `applies`.
- `sw-check`: The handbook's software entrance and success criteria for a life-cycle review (topic 7.09), its groups as parts (SWR-PDR.a); read-only, from skein's template; statuses `draft`, `approved`, `deprecated`, `removed`; attributes `review`, `checklist`.
- `swe`: A requirement of NPR 7150.2D, as NASA publishes it: read-only, taken by skein's tools/npr7150 and kept by hand; statuses `draft`, `approved`, `deprecated`, `removed`; attributes `section`, `classes`, `authority`, `authority_f`, `applies`, `title`, `handbook`.
- `system`: A higher-level requirement the software requirements come from: a system or subsystem requirement, often in another repository of the network; statuses `draft`, `approved`, `deprecated`, `removed`.
- `tailoring`: Relief from a requirement of the NPR (SWE-121, SWE-126): a deviation, asked before the requirement is under configuration control, or a waiver, asked after; with its rationale, risk and mitigation; categories `deviation`, `waiver`; statuses `draft`, `submitted`, `approved`, `rejected`, `withdrawn`; attributes `risk`, `mitigation`.

Link types (`key=ID` in a marker):

- `addresses` from `requirement` to `hazard`: A software requirement addresses a system hazard: a cause, a control or a mitigation (SWE-052, SWE-192).
- `affects` from `nonconformance` to `requirement`: A non-conformance is against a software requirement (SWE-052, SWE-201) (required).
- `assures` from `satask` to `swe`: The tasks of the standard assure a requirement of NPR 7150.2D (Table 1).
- `complies` from `compliance` to `swe`: A row of the Requirements Mapping Matrix says how the project meets a requirement of the NPR.
- `derives` from `requirement` to `system`: A software requirement comes from a higher-level requirement (SWE-052).
- `interprets` from `guidance` to `swe`: The handbook's reading of a requirement of the NPR.
- `ivv-performs` from `assurance` to `ivv`: A row of the assurance mapping matrix says how the IV&V Provider meets a requirement of section 4.4.2.
- `performs` from `assurance` to `satask`: A row of the assurance mapping matrix says how tasks of the standard are carried out.
- `satisfies` from `design` to `requirement`: A design component satisfies a software requirement (SWE-052).
- `tailors` from `tailoring` to `swe`: A deviation or waiver relieves the project of a requirement of the NPR; once approved, as good as its row in the matrix.
- `verifies` from `procedure` to `requirement`: A test procedure verifies a software requirement (SWE-052, SWE-065).

Code and tests cite items in comments:

- `offline-test`: files under `offline/php/test/` ending in `.php`, `// verifies: ID, ID`.
- `server-test`: files under `tests/server/` ending in `.sh`, `# verifies: ID, ID`.

After editing documents, item files or `.skein/`, run `skein check` and mend what it reports. `skein trace ID` shows an item with everything above and below it, and `skein coverage` what is not yet linked or cited. `skein mcp` offers all of this as tools to agents that speak the Model Context Protocol.

Approvals and reviews are people's, never an agent's: do not run `skein approve`, `skein review` or `skein clear`, and do not edit `.skein/approvals/`, `.skein/reviews/`, `.skein/signers.toml` or `.skein/baselines/`. Say which items need approving or which links reviewing, and leave it to the people who do it.

Still to do in setting up this project (`skein agents` writes this list again):

- Set `[maturity] milestone` to the review the project is at next, so that `skein check` holds the documents to the maturity it expects.
- Fill in the documents that are still the template's skeletons (24: docs/data-dictionary.md, docs/design.md, docs/estimates.md, docs/hazards.md, docs/index.md, docs/metrics.md, ...), or remove those the project's tailoring leaves out.

<!-- skein: end -->
