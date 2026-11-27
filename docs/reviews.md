+++
document = "SW-REVIEWS"
revision = "Draft"
+++

# Software at the milestone reviews

What the software brings to each life-cycle review: the maturity of each product (the handbook's topic 7.08) and the software criteria of each review (topic 7.09), both in `standards/npr7150.2d/`, read-only. A project tailors the criteria to its class, justifies the tailoring to the Engineering and the SMA Technical Authorities, marks each criterion met or not at the review, and keeps the filled checklist as evidence.

## Maturity of the products

```skein
list product columns=mcr,srr,sw_rr,mdr,sdr,pdr,cdr,sir,trr,sar,orr
```

## The criteria of each review

```skein
list sw-check columns=review,checklist
```

## Numeric gates

The handbook's checklists set these, among others: requirements volatility under 30% at SwRR, MDR and SDR, under 20% at PDR, CDR and PRR, under 5% at TRR; TBD, TBC and TBR at most 20% of the SRS at SwRR and at most 1% from PDR on, all resolved by SAR; the data dictionary over 95% complete at CDR; for safety-critical components, cyclomatic complexity of 15 or less and 100% MC/DC coverage at TRR and after (%[SWE-219], %[SWE-220]); waivers and deviations approved by TRR and closed by SAR.
