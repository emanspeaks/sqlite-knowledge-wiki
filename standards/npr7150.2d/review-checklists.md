<!-- The software entrance and success criteria of each life-cycle review, paraphrased from the checklists of the NASA Software Engineering Handbook (NASA-HDBK-2203, version D), topic 7.09 (PAT-066 to PAT-078, versions of 2025-07-25, read through the Internet Archive on 2026-11-22; the handbook updated them on 2026-05-19, and that version was not captured). Kept by hand from here. -->

# Review checklists

The handbook's software criteria for each life-cycle review (topic 7.09), in short: each review an item (`SWR-PDR`), each group of its checklist a part (`SWR-PDR.a`) where the checklist has groups. The checklists themselves (PAT-066 to PAT-078) have the full items; a project tailors them, marks each item met or not at the review, and keeps the filled checklist as evidence.

## MCR (PAT-066)

%sw-check[SWR-MCR review=MCR checklist=PAT-066] The software criteria of the MCR, by group:

- %sw-check[.a] mission objectives and software's role.
- %sw-check[.b] software concept and feasibility, reuse of existing assets considered.
- %sw-check[.c] preliminary key requirements and a requirements management framework.
- %sw-check[.d] high-level architecture and conceptual interfaces.
- %sw-check[.e] software risks identified, classification correct.
- %sw-check[.f] resources (incl. IV&V if required), budget and schedule, SE and SA points of contact.
- %sw-check[.g] compliance: contracts and SOW plan for NPR 7150.2 and NASA-STD-8739.8, NASA access to software products and metrics in electronic form, unique constraints.
- %sw-check[.h] preliminary safety-critical functions and hazards, early cybersecurity.
- %sw-check[.i] initial V&V strategy with measurable success criteria.
- %sw-check[.j] stakeholder buy-in, partnerships and agreements, open issues tracked; K MCR documentation reviewed, approval by authorities, planning sufficient to proceed.

## SRR (PAT-067)

%sw-check[SWR-SRR review=SRR checklist=PAT-067] The software criteria of the SRR, by group:

- %sw-check[.a] requirements complete (functional, performance, interface, safety, security, reliability, operational).
- %sw-check[.b] traceable to system requirements, mission objectives and stakeholders, bidirectional.
- %sw-check[.c] interfaces defined.
- %sw-check[.d] feasibility per requirement, risks with mitigations, new technology planning, credible SE/SA/safety cost and schedule, lessons learned addressed, NASA electronic access to products and metrics, supply chain risks.
- %sw-check[.e] measurable verification criteria, preliminary V&V plan.
- %sw-check[.f] safety-critical and cybersecurity requirements explicit, requirements safety analysis.
- %sw-check[.g] clarity and conflicts resolved.
- %sw-check[.h] stakeholder input and formal approval; I SRS, interface definitions and matrices reviewed and approved.
- %sw-check[.j] requirements change control process and tools with traceability and impact assessment; K SE and SA points of contact, resources scoped.
- %sw-check[.l1] process documents preliminary, initial classification, safety-critical assessment, preliminary hazard analysis, requirements-to-hazard traceability, hazard controls and verifications defined, all hazard-traced requirements verified by test, 8739.8 and 7150.2 mapping matrices completed, lessons learned review documented.
- %sw-check[.l2] quality requirements (allocation across hardware, software, operations; external and internal interfaces incl. security; fault management and cybersecurity requirements from the project protection plan).
- %sw-check[.l3] key plans available: SDP, SA and safety plan, cost estimate, IV&V plan if needed, schedules.

## SwRR (PAT-068)

%sw-check[SWR-SWRR review=SwRR checklist=PAT-068] The software criteria of the SwRR, by group:

- %sw-check[.a] complete, covering all aspects, SRS peer reviewed.
- %sw-check[.b] traceable and bidirectional incl. system, hardware and ICD requirements, transparent allocation to architecture.
- %sw-check[.c] interface document.
- %sw-check[.d] consistent, updates introduce no conflicts.
- %sw-check[.e] feasibility and requirement risks.
- %sw-check[.f] measurable acceptance criteria per requirement, verification plan (test, analysis, inspection).
- %sw-check[.g] safety and security requirements, hazards linked to requirements, hazard traceability, FMEA and FTA results reflected.
- %sw-check[.h] formal approval by leadership, systems engineering and SA; I SRS and supporting artifacts (matrices, dependency analyses, risk assessments) finalized, architecture defined.
- %sw-check[.j] change management with traceability and impact analysis, SDP/SMP incl. peer review and schedule coordination, SA/safety plan, classification, both mapping matrices, SCMP, SA requirements analysis, IV&V requirements analysis, risk items (new technology, credible cost, lessons learned, electronic access, supply chain, workforce), quality requirements (COTS/GOTS/MOTS/OSS and reuse, cybersecurity, fault management, testable, TBD thresholds, quality score, operational scenarios), metrics and margins.
- %sw-check[.k] test facilities, test tools, staffing (SE, SA, safety, IV&V).

## MDR (PAT-069)

%sw-check[SWR-MDR review=MDR checklist=PAT-069] mission objectives linked to high-level software requirements; preliminary requirements traceable, bidirectional traceability complete; integration concept and key interfaces; feasibility; risks; compliance with NASA and mission standards; safety-critical functions and preliminary cybersecurity; preliminary SDP; initial V&V strategy and preliminary IV&V success criteria; stakeholder approval; L: plans, schedules, architecture credibility, planned static analysis, quality requirements as in SwRR, hazard analysis complete, completed plans and peer reviews, margins, risks and process audit evidence, Severity 1 and 2 findings addressed, 7150.2 and 8739.8 RMMs complete, classification and safety-criticality assessments available, SA/safety/IV&V staffing, IV&V concept reviews, IV&V Project Execution Plan and risk assessment, SCMP, approved software concept, SRR RFAs and RIDs resolved.

## SDR (PAT-070)

%sw-check[SWR-SDR review=SDR checklist=PAT-070] high-level architecture with components and data flows; architecture traceable to all requirements, requirement quality items and thresholds as in SwRR; interfaces incl. data formats and protocols; feasibility and trade studies; risks incl. static analysis plan, Severity 1/2 findings, hardware-software concurrency risk, supply chain, workforce; preliminary data management; safety-critical design controls, security design, preliminary software hazard analysis; V&V plan for the design; compliance with standards (names NASA-STD-8719.13 and 8739.8); stakeholder approval; K documentation: architecture documents, SDP complete, classification and safety-criticality assessment, 7150.2 RMM, 8739.8 RMM, data dictionary, safety assessment, SA requirements analysis, IV&V requirements analysis, peer reviews of requirements and plans, preliminary human rating plan if applicable, preliminary maintenance plan, SCMP, IV&V PEP, SA/safety/IV&V personnel, SA point of contact, metrics selected with margins, certifiable practices with audit evidence; L readiness, MCR RFAs/RIDs resolved, critical issues closed, IV&V concurrence to begin Phase B.

## PDR (PAT-071)

%sw-check[SWR-PDR review=PDR checklist=PAT-071] A baselined SRS, verifiable requirements, peer reviews of safety and mission-critical requirements, TBD and volatility thresholds, FTA/FMEA reflected, OTS requirements baselined; preliminary SwDD meets requirements with margins (modes and states, common cause, safety-critical isolation, unauthorized use protections, automatic safing, fault management, command and telemetry, error detection, cybersecurity); bidirectional traceability requirements to design modules; baselined architecture; preliminary data dictionary; IV&V and SA requirements and design analyses complete; IV&V concurrence to proceed to CDR. B software hazards in system hazard analyses, preliminary FTA, risks assessed. C compliance: "Updated NPR 7150.2 and NASA-STD-8739.8 Requirements Mapping: tailoring completed and approved"; classification and safety-criticality updated. D tools, facilities, language training, validated and accredited tools, approach to autogenerated code, resource estimates and margins, test units and simulations planned. E process audit results available, processes being followed with evidence, problem reporting with tracking and resolution, change control (tracking, review, approval or disapproval, impact analysis, re-validation and re-verification). F ICDs mature for CDR, quality attributes in architecture, metrics in use, risks documented, SA and Severity 1/2 findings addressed, baselined SCMP, NASA electronic access. G IV&V concurrence, certifiable practices, SA personnel. H high-level test plan per level, preliminary test plans, prototypes. I peer reviews of preliminary design and requirements, CCB established, lessons learned. J trade studies, baselined cost estimate, operations concept and schedule, preliminary acceptance criteria. K RFAs and RIDs from previous reviews resolved.

## CDR (PAT-072)

%sw-check[SWR-CDR review=CDR checklist=PAT-072] The software criteria of the CDR, by group:

- %sw-check[.a] requirements baselined, bidirectional traceability between hazards and requirements and between detailed design and requirements.
- %sw-check[.b] design meets requirements, design artifacts approved, trade studies final.
- %sw-check[.c] interfaces.
- %sw-check[.d] risks and earlier open items.
- %sw-check[.e] complete test and verification plan for all levels.
- %sw-check[.f] safety-critical components meet safety requirements, compliance with 8739.8 verified.
- %sw-check[.g] configuration control of baselines, peer reviews and inspections compliant.
- %sw-check[.h] feasibility, hardware-software compatibility.
- %sw-check[.i] deliverables: SA design analysis, SA safety analysis, architecture, data flow diagrams, data dictionary, design, procedures for deliverable products, regression test plans, margins, preliminary SA test analysis, supplier documentation, FTA or preliminary FMEA, metrics, IV&V design analysis, design peer reviews, avionics architecture; detailed design checks as at PDR.
- %sw-check[.j] readiness: action items, previous RFAs/RIDs, SA/safety/IV&V personnel, classification and safety-criticality updated, CM in place, facilities and tools, schedule and change request status, lessons learned, process audit results, acceptance criteria; baselined requirements with thresholds; test plans, procedures, cases and environment correct for all levels; hazard analyses; data dictionary over 95% complete; static analysis use; operations concept at CDR detail; secure coding practices planned; credible cost and schedule backed by metrics; acceptable problem reporting and change control; requirements, data dictionary and design baselined under CM; IV&V concurrence to proceed to code.

## PRR (PAT-073)

%sw-check[SWR-PRR review=PRR checklist=PAT-073] development complete, IV&V and peer reviews of design done, no unresolved critical defects, detailed design with margins; hazards; all required testing complete (incl. STB use, OTS V&V to same level, regression approach, static analysis); IV&V concurrence; final configuration baselined; traceability from requirements to implementation and test, thresholds (volatility under 20%, TBD at most 1%, under 10% high-risk); documentation finalized (SA design and safety analyses, architecture and design, regression plans, supplier documentation, FTA/FMEA, classification and safety-criticality updated, lessons learned, data dictionary over 95%, change request status); deployment plan; safety and security certification documented; residual risks documented, Severity 1/2 findings addressed; training and support plan; stakeholder approval and prior RFAs/RIDs; transition plan; operations concept at CDR detail; certifiable practices with audit evidence; credible cost and schedule from metrics; problem reporting and change control.

## SIR (PAT-074)

%sw-check[SWR-SIR review=SIR checklist=PAT-074] integration complete, prior unit and verification results adequate, Severity 1/2 findings addressed, TBD/TBR plans, integration plans and configuration status; interfaces qualified and validated; integration testing complete with evidence list: test plans and results, test preparation, static analysis results, code coverage data, cyclomatic complexity data, metrics, hazard testing, IV&V concurrence; compatibility and performance with margins; traceability maintained; safety and security functions verified, cybersecurity risk of integration processes; problem resolution and risk communication; configuration baselined and all components and data under CM; documentation: approved integration plans and procedures, handling and safety requirements, unit test results, metrics, process audit results, data dictionary over 95% complete, RFAs/RIDs, qualification test results, ICDs; stakeholder approval and prior criteria met; readiness, discrepancies dispositioned, SA organization ready, staff trained.

## TRR (PAT-075)

%sw-check[SWR-TRR review=TRR checklist=PAT-075] The software criteria of the TRR, by group:

- %sw-check[.a] test objectives.
- %sw-check[.b] test plans, procedures and scripts approved (schedules, cases, steps, expected results, acceptance criteria), result capture and discrepancy reporting procedures, TRR materials (plans, procedures, cases, VDD, schedule, status, data), STB use, OTS V&V, regression approach, engineering units certified, V&V plans complete (stress, end-to-end, fault management, unauthorized use, regression), bidirectional traceability requirements to test procedures and approved coverage approach, peer reviews of safety and mission-critical test procedures, configuration data tested, informal runs done, independent testing planned; coverage of all requirements, expected results, nominal, abnormal, failure and degraded conditions.
- %sw-check[.c] every requirement traced to test cases, coverage gaps addressed, baselined requirements with the TRR thresholds.
- %sw-check[.d] test inputs and data validated, expected outputs defined.
- %sw-check[.e] test environment verified and close to operational, test network of events.
- %sw-check[.f] software built to baseline, no blocking defects, known discrepancies dispositioned.
- %sw-check[.g] interfaces.
- %sw-check[.h] issues and risks, safety-critical complexity at most 15 and 100% MC/DC, hazard analyses.
- %sw-check[.i] trained testers, agreed SA plan for witnessing or sampling; J CM: build from CM, FCA of the VDD, QA plan.
- %sw-check[.k] formal stakeholder approval to enter test.
- %sw-check[.l] problem tracking ready.
- %sw-check[.m] pre-test documents approved; N previous review criteria met, code reviews and walkthroughs, secure coding standard adherence, audits during implementation with evidence, VDD ready and FCA done, SA test analysis complete with issues resolved, waivers and deviations approved, prior test levels and dry run done, baselined documents available, lessons learned, outstanding SCRs, operations and user manuals validated, static analysis findings corrected, data dictionary tested, structural quality (maintainable, secure, testable, fault tolerant), IV&V concurrence.

## SAR (PAT-076)

%sw-check[SWR-SAR review=SAR checklist=PAT-076] The software criteria of the SAR, by group:

- %sw-check[.a] every requirement verified as satisfied and traceability shows every requirement implemented and tested; structural and functional quality.
- %sw-check[.b] team trained in operational, CM and defect processes, all testing complete, data loads, results analyzed, update procedures tested, secure, configuration data tested, TBD/TBR resolved and waivers, deviations and anomalies closed, coverage data with covered and uncovered analysis (100% for safety-critical, MC/DC), defects resolved, prior flight anomalies resolved.
- %sw-check[.c] integration and compatibility.
- %sw-check[.d] safety-critical and cybersecurity requirements validated, margins incl. worst-case execution time, complexity at most 15, hazard reports closed or mitigated.
- %sw-check[.e] final build baselined, products under CM.
- %sw-check[.f] documentation approved: maintenance plan, user manual, lessons learned, open items and waivers/deviations, open defect reports, test results, audit results, quality data, metric data, tests/demos/analyses/audits, interface status, data dictionary, VDD, evidence of good processes.
- %sw-check[.g] customer approval, SA sign-off on the certification package, IV&V concurrence, outstanding issues, software acceptably safe (safety requirements met, safety risk accepted by those affected, acceptance criteria met, evidence for SWE-134 and SSP 50038, change history acceptable).
- %sw-check[.h] training and maintenance materials.
- %sw-check[.i] risks closed or accepted, residual risk plans.
- %sw-check[.j] delivery and transfer plan, delivery approval.

## ORR (PAT-077)

%sw-check[SWR-ORR review=ORR checklist=PAT-077] verified and validated (quality data, test results, update procedures, TBD and waiver closure, coverage); functionality and margins, structural quality, interfaces; integration issues resolved, audit results, open items, waivers/deviations, open defect reports, prior flight anomalies; operational environment and constraints; safety-critical validation, hazards, complexity, cybersecurity protections; operational risk acceptable given open defects, operations risk management plan; final configuration baselined and delivered version under CM; operator training and procedures; documentation (VDD, quality data, data dictionary, lessons learned, process evidence); stakeholder approval incl. safety risk acceptance, SWE-134 and SSP 50038 evidence, IV&V concurrence, SA sign-off on certification package; maintenance and operational support plan (user manual, data loads), long-term maintenance responsibility assigned.

## FRR (PAT-078)

%sw-check[SWR-FRR review=FRR checklist=PAT-078] requirements verified and validated, code quality; testing complete with coverage and margins; regression tests; defects resolved or justified; baseline frozen, no unplanned changes after FRR approval; interfaces; operations support and anomaly tools; documentation (VDD, maintenance plan, user manual, data loads, lessons learned, open items and waivers/deviations, open defect reports, audit results, quality and metric data, data dictionary, process compliance evidence); safety: all hazard-traced requirements verified by test, complexity, risk acceptance, SWE-134 and SSP 50038 evidence, problem report summary with justification for each report left open; formal approval, entrance criteria met, SA sign-off on certification package, IV&V concurrence; deployment with backup and recovery; issue tracking in flight; trained team.
