<!-- The maturity of each software product at each milestone review, from the NASA Software Engineering Handbook (NASA-HDBK-2203, version D), topic 7.08, read through the Internet Archive (capture 2026-03-16) on 2026-11-21. Kept by hand from here when the handbook changes. -->

# Product maturity at milestone reviews

What the handbook expects of each software product at each review (topic 7.08; OCE-approved guidance, Center procedures take precedence, not class-specific): D draft, P preliminary (stabilizing, not yet under configuration management), B baseline (under configuration control), U update, F final, X complete, PPS per the project or assurance schedule. Each product is an item (`PRD-01` and on); a review it is not expected at has no value.

```skein
list product columns=mcr,srr,sw_rr,mdr,sdr,pdr,cdr,sir,trr,sar,orr
```

## Software engineering products (NPR 7150.2)

%product[PRD-01 engineering topic=5.08 srr=P sw_rr=B mdr=U sdr=U pdr=U cdr=U orr=F] Software Development Plan (SDP) / Software Management Plan (SMP)

%product[PRD-02 engineering topic=7.16 srr=P sw_rr=B mdr=U sdr=U pdr=U cdr=U orr=F] NPR 7150.2 Requirements Mapping Matrix/table

%product[PRD-03 engineering mcr=D srr=P sw_rr=B mdr=U sdr=U pdr=U cdr=U orr=F] Software Schedule

%product[PRD-04 engineering mcr=D srr=P sw_rr=B mdr=U sdr=U pdr=U cdr=U orr=F] Software Cost Estimate

%product[PRD-05 engineering topic=5.06 srr=P sw_rr=P mdr=P sdr=B pdr=U cdr=U orr=F] Software Configuration Management Plan (SCMP)

%product[PRD-06 engineering topic=5.10 pdr=P cdr=B sir=U trr=U orr=F] Software Test Plans

%product[PRD-07 engineering topic=5.14 cdr=D sir=P trr=B sar=U orr=F] Software Test Procedures

%product[PRD-08 engineering topic=5.11 sar=B orr=F] Software Test Reports

%product[PRD-09 engineering topic=5.04 cdr=D sir=P trr=P sar=B orr=F] Software Maintenance Plan

%product[PRD-10 engineering topic=5.09 srr=P sw_rr=B mdr=U sdr=U pdr=U cdr=U trr=U orr=F] Software Requirements Specification (SRS)

%product[PRD-11 engineering srr=P sw_rr=B mdr=U sdr=U pdr=U cdr=U orr=F] Requirements on OTS s/w

%product[PRD-12 engineering topic=SWE-052 srr=P sw_rr=B pdr=U cdr=U trr=U sar=U orr=F] Bi-directional Requirements Traceability matrix

%product[PRD-13 engineering topic=5.07 sw_rr=P mdr=P sdr=P pdr=B cdr=U orr=F] Software Data Dictionary

%product[PRD-14 engineering topic=5.13 mdr=P sdr=P pdr=B cdr=U trr=U orr=F] Software Design Description (Architectural Design)

%product[PRD-15 engineering topic=5.13 pdr=P cdr=B trr=U orr=F] Software Design Description (Detailed Design)

%product[PRD-16 engineering topic=5.02 mdr=P sdr=P pdr=P cdr=B trr=U orr=F] Interface Design Description

%product[PRD-17 engineering sw_rr=B pdr=U cdr=U] Software Coding Standards/Guidelines

%product[PRD-18 engineering sir=B trr=U orr=F] Source Code

%product[PRD-19 engineering topic=5.16 sir=P trr=P sar=B orr=F] Version Description Document (VDD)

%product[PRD-20 engineering topic=5.12 sar=B orr=F] Software User's Manual (SUM)

%product[PRD-21 engineering mcr=P srr=U sw_rr=U mdr=U sdr=U pdr=U cdr=U trr=U sar=U orr=U] Records of Continuous Risk Management

%product[PRD-22 engineering topic=5.05 sw_rr=P mdr=P sdr=P pdr=X cdr=X sir=X trr=X sar=X orr=X] Measurement Analysis Results

%product[PRD-23 engineering sw_rr=X mdr=X sdr=X pdr=X cdr=X] Software Volatility measures

%product[PRD-24 engineering srr=P sw_rr=P mdr=U sdr=U pdr=B cdr=U orr=F] Operational Concepts (part of "Mission Operations Concept" or separate)

%product[PRD-25 engineering pdr=X cdr=X] Record of trade-off criteria & assessment (make/buy decision)

%product[PRD-26 engineering sw_rr=B trr=B] Acceptance Criteria and Conditions

## Software assurance and software safety products (NASA-STD-8739.8)

%product[PRD-27 assurance topic=8.51 srr=D sw_rr=D mdr=P sdr=B pdr=U cdr=U orr=F] Software Assurance and Software Safety Plan(s)

%product[PRD-28 assurance mcr=D srr=P sw_rr=P mdr=P sdr=B pdr=U cdr=U] Software Assurance and Software Safety Cost Estimates

%product[PRD-29 assurance srr=D sw_rr=D mdr=P sdr=B pdr=U cdr=U orr=F] NASA-STD-8739.8 Requirements Mapping Matrix (RMM)

%product[PRD-30 assurance srr=P sw_rr=B mdr=U sdr=U pdr=U cdr=U orr=F] Safety-Critical Software Determination

%product[PRD-31 assurance srr=P sw_rr=B mdr=U sdr=U pdr=U cdr=U orr=F] Software Classification Determination

%product[PRD-32 assurance srr=P sw_rr=P mdr=P sdr=B pdr=U cdr=U] Software Assurance schedule

%product[PRD-33 assurance topic=8.53 srr=P sw_rr=P mdr=P sdr=P pdr=B cdr=U sir=U trr=U sar=U orr=F] IV&V Project Execution Plan (if required)

%product[PRD-34 assurance mcr=P srr=B sw_rr=U mdr=U sdr=U pdr=U cdr=U sir=U trr=U] IV&V Project risk assessment (if required)

%product[PRD-35 assurance sw_rr=P mdr=P sdr=B pdr=U cdr=F] Software Assurance Product Acceptance Criteria and Conditions

%product[PRD-36 assurance topic=8.54 srr=P sw_rr=B mdr=U sdr=U pdr=U cdr=U sir=U trr=U sar=U orr=F] Software Assurance Requirements Analysis

%product[PRD-37 assurance topic=8.58 sw_rr=D mdr=P sdr=P pdr=B cdr=U sir=U trr=U sar=U orr=F] Software Assurance and Software Safety hazard analysis

%product[PRD-38 assurance topic=8.58 srr=D sw_rr=D mdr=P sdr=P pdr=B cdr=U sir=U trr=U sar=U orr=F] Software Assurance safety analysis

%product[PRD-39 assurance topic=8.55 mdr=P sdr=P pdr=P cdr=B orr=F] Software Assurance design analysis

%product[PRD-40 assurance topic=8.56 sir=B trr=U orr=F] Software source code quality analysis

%product[PRD-41 assurance topic=8.57 sir=P trr=B sar=U orr=F] Software Assurance Testing/Verification Activities Analysis

%product[PRD-42 assurance sir=P trr=B orr=F] Software Static Code Analysis

%product[PRD-43 assurance sir=P trr=B sar=U orr=F] Analysis showing software code coverage percentage for safety-critical code

%product[PRD-44 assurance sir=P trr=B orr=F] Analysis showing software Cyclomatic Complexity for safety-critical code

%product[PRD-45 assurance trr=B sar=U orr=F] Security vulnerabilities and security weaknesses analysis

%product[PRD-46 assurance sw_rr=X mdr=U sdr=U pdr=U cdr=U] SA analysis of software volatility measures

## Ongoing activities

%product[PRD-47 ongoing sw_rr=PPS mdr=PPS sdr=PPS pdr=PPS cdr=PPS sir=PPS trr=PPS sar=PPS orr=PPS] Software Process Root Cause Analysis results

%product[PRD-48 ongoing sw_rr=PPS mdr=PPS sdr=PPS pdr=PPS cdr=PPS sir=PPS trr=PPS sar=PPS orr=PPS] Software risks, findings, or known issues

%product[PRD-49 ongoing sw_rr=PPS mdr=PPS sdr=PPS pdr=PPS cdr=PPS sir=PPS trr=PPS sar=PPS orr=PPS] Evaluation of software changes

%product[PRD-50 ongoing topic=8.52 srr=PPS sw_rr=PPS mdr=PPS sdr=PPS pdr=PPS cdr=PPS sir=PPS trr=PPS sar=PPS orr=PPS] Software Assurance status reports, including Software Assurance metric analysis

%product[PRD-51 ongoing srr=PPS sw_rr=PPS mdr=PPS sdr=PPS pdr=PPS cdr=PPS sir=PPS trr=PPS sar=PPS orr=PPS] Participation in Software Peer reviews

%product[PRD-52 ongoing srr=PPS sw_rr=PPS mdr=PPS pdr=PPS cdr=PPS sir=PPS trr=PPS sar=PPS orr=PPS] Software Assurance process Audits and Assessments (schedules in 8.59)

%product[PRD-53 ongoing sir=PPS trr=PPS sar=PPS orr=PPS] Software test witnessing

%product[PRD-54 ongoing mcr=PPS srr=PPS sw_rr=PPS mdr=PPS sdr=PPS pdr=PPS cdr=PPS sir=PPS trr=PPS sar=PPS orr=PPS] Software Assurance participation in milestone product reviews
