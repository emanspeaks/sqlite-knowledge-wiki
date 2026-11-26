+++
document = "SW-RMM"
revision = "Draft"
item = "PRD-02"
maturity = "D"
+++

# Requirements Mapping Matrix

How the project meets each requirement of NPR 7150.2D that its class invokes (%[SWE-125], %[SWE-139]), with the tailoring approved for it (%[SWE-121]). Preliminary at SRR, baselined at SwRR, final at ORR (topic 7.08).

A row of the matrix is an item of the type `compliance`, linked to the requirement by `complies`: its category is FC (fully compliant), T (tailored), PC (partially compliant), NC (not compliant) or NA (not applicable), and it says where the evidence is. A row may be kept per software component. Every row says where or how the requirement is met; every PC, NC or NA row gives its rationale and risk (the handbook's PAT-057 checklist). The matrix is peer reviewed and kept for the life of the project.

```text
%compliance[rmm.swe-013 FC complies=SWE-013 evidence="SDP, section 3"] The development plan covers the whole life cycle.
```

## The matrix

```skein
matrix complies profile=class columns=section,title,authority from.columns=category,component,evidence
```

## Tailoring

Deviations and waivers, each an item of the type `tailoring` linked by `tailors` to the requirement it relieves, in force once approved by the Technical Authorities (NPR 7150.2D, 2.1.8.2; %[SWE-126]).

```skein
list tailoring
```

## Approval

Tailoring is approved by signatures in the matrix itself (%[SWE-126], %[SWE-150]); the software assurance organization keeps its own matrix of NASA-STD-8739.8B's tasks, built from this one. The signatures of the matrix and of its tailoring: the Center Engineering Technical Authority, the Center Safety and Mission Assurance Technical Authority, and, where Appendix C names them, the Health and Medical Technical Authority, the CIO's designee and the SAISO. `skein approve --as ROLE` records each.
