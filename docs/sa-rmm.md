+++
document = "SA-RMM"
revision = "Draft"
+++

# Software assurance requirements mapping matrix

How the software assurance organization carries out the tasks of NASA-STD-8739.8B for each requirement of NPR 7150.2D that the project's class invokes (%[SASS-01]), built from the project's own [Requirements Mapping Matrix](rmm.md): tasks under a requirement tailored out of the NPR drop out with it, and tailoring of the assurance tasks needs the concurrence of the Center SMA Technical Authority (section 4.5 of the standard; handbook topic 8.51).

A row is an item of the type `assurance`, linked by `performs` to the tasks it covers, of the category FC, T, PC, NC or NA, with where its products or evidence are; a PC, NC or NA row gives its rationale and risk.

```text
%assurance[sa.swe-013 FC performs=SA-013.1,SA-013.2 evidence="SAP, section 2"] The assurance plan is in place and reviewed.
```

## The matrix

```skein
matrix performs profile=assured from.columns=category,component,evidence
```

## IV&V

When IV&V is performed on the project (the template's option `ivv`), a row per requirement of section 4.4.2, linked by `ivv-performs`:

```skein
matrix ivv-performs
```
