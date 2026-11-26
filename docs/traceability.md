+++
document = "SW-RTM"
revision = "Draft"
item = "PRD-12"
maturity = "D"
+++

# Bidirectional traceability

The traces of %[SWE-052], each kept by links and generated both ways: preliminary at SRR, baselined at SwRR, final at ORR (topic 7.08). Which of them the project's class requires is set by its `class` option, and `skein coverage` counts the gaps.

## Higher-level requirements to software requirements

```skein
matrix derives
```

## Software requirements to hazards

```skein
matrix addresses
```

## Software requirements to design

```skein
matrix satisfies
```

## Software requirements to verifications

```skein
matrix verifies
```

## Software requirements to non-conformances

```skein
matrix affects
```

Design to code is traced by the citations in the code (`// implements: DES-001`), which `skein trace` shows for each component.
