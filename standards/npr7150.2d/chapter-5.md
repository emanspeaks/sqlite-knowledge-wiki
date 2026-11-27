<!-- NPR 7150.2D, NASA Software Engineering Requirements (effective March 08, 2022), from https://nodis3.gsfc.nasa.gov/displayDir.cfm?Internal_ID=N_PR_7150_002D_&page_name=Chapter5, retrieved 2026-11-22. Taken by tools/npr7150 in skein's repository (zig build npr7150), and kept by hand from here when NASA revises the NPR. -->

# Chapter 5: Supporting Software Life Cycle Requirements

## 5.1 Software Configuration Management (SCM)

5.1.1 Software Configuration Management (SCM) is the process of applying configuration management throughout the software life cycle to ensure the completeness and correctness of software configuration items. SCM applies technical and administrative direction and surveillance to identify and record the functional and physical characteristics of software configuration items, control changes to those characteristics, record and report change processing and implementation status, and verify compliance with specified requirements. SCM establishes and maintains the integrity of the products of a software project throughout the software life cycle. Use of standard Center or organizational SCM processes and procedures is encouraged where applicable.

%swe[SWE-079 section=5.1.2 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Develop CM Plan" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695458/SWE-079+-+Develop+CM+Plan] The project manager shall develop a software configuration management plan that describes the functions, responsibilities, and authority for the implementation of software configuration management for the project.

%swe[SWE-080 section=5.1.3 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Track and Evaluate Changes" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695459/SWE-080+-+Track+and+Evaluate+Changes] The project manager shall track and evaluate changes to software products.

%swe[SWE-081 section=5.1.4 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Identify Software CM Items" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695461/SWE-081+-+Identify+Software+CM+Items] The project manager shall identify the software configuration items (e.g., software records, code, data, tools, models, scripts) and their versions to be controlled for the project.

> Note: The items to be controlled include tools, items, or settings used to develop the software, which could impact the software. Examples of such items include compiler/assembler versions, makefiles, batch files, and specific environment settings.

%swe[SWE-082 section=5.1.5 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Authorizing Changes" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695463/SWE-082+-+Authorizing+Changes] The project manager shall establish and implement procedures to:

- %swe[.a] Designate the levels of control through which each identified software configuration item is required to pass.
- %swe[.b] Identify the persons or groups with authority to authorize changes.
- %swe[.c] Identify the persons or groups to make changes at each level.

> Note: IEEE 828-2012, IEEE Standard for Configuration Management in Systems and Software Engineering describes configuration management processes to be established, how they are to be accomplished, who is responsible for doing specific activities, when they are to happen, and what specific resources are required. It addresses configuration management activities over a product’s life cycle. Configuration management in systems and software engineering is a specialty discipline within the larger discipline of configuration management. Configuration management is essential to systems engineering and software engineering.

%swe[SWE-083 section=5.1.6 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Status Accounting" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695465/SWE-083+-+Status+Accounting] The project manager shall prepare and maintain records of the configuration status of software configuration items.

%swe[SWE-084 section=5.1.7 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Configuration Audits" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695466/SWE-084+-+Configuration+Audits] The project manager shall perform software configuration audits to determine the correct version of the software configuration items and verify that they conform to the records that define them.

%swe[SWE-085 section=5.1.8 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Release Management" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695469/SWE-085+-+Release+Management] The project manager shall establish and implement procedures for the storage, handling, delivery, release, and maintenance of deliverable software products.

%swe[SWE-045 section=5.1.9 classes=A,B,C,F authority=Center authority_f=CIO applies=always title="Project Participation in Audits" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695419/SWE-045+-+Project+Participation+in+Audits] The project manager shall participate in any joint NASA/developer audits.

## 5.2 Software Risk Management

%swe[SWE-086 classes=A,B,C,F authority=Center authority_f=CIO applies=always title="Continuous Risk Management" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695470/SWE-086+-+Continuous+Risk+Management] The project manager shall record, analyze, plan, track, control, and communicate all of the software risks and mitigation plans.

> Note: Project managers should be aware of any risks that remain after mitigations have been completed or after a risk has been accepted.

## 5.3 Software Peer Reviews and Inspections

5.3.1 Software peer reviews and inspections are the in-process technical examination of work products by peers to find and eliminate defects early in the life cycle. Software peer reviews and inspections are performed following defined procedures covering the preparation for the review, the review itself is conducted, results are recorded, results are reported, and completion criteria is certified. When planning the composition of a software peer review or inspection team, consider including software testing, system testing, software assurance, software safety, software cybersecurity, and software IV&V personnel.

%swe[SWE-087 section=5.3.2 classes=A,B,C,F authority=Center authority_f=CIO applies=always title="Software Peer Reviews and Inspections for Requirements, Plans, Design, Code, and Test Procedures" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695472/SWE-087+-+Software+Peer+Reviews+and+Inspections+for+Requirements+Plans+Design+Code+and+Test+Procedures] The project manager shall perform and report the results of software peer reviews or software inspections for:

- %swe[.a] Software requirements.
- %swe[.b] Software plans, including cybersecurity.
- %swe[.c] Any design items that the project identified for software peer review or software inspections according to the software development plans.
- %swe[.d] Software code as defined in the software and or project plans.
- %swe[.e] Software test procedures.

> Note: Software peer reviews or software inspections are recommended best practices for all safety and mission-success related software components. Recommended best practices and guidelines for software formal inspections are contained in NASA-STD-8739.9, Software Formal Inspection Standard.

%swe[SWE-088 section=5.3.3 classes=A,B,C authority=Center applies=always title="Software Peer Reviews and Inspections - Checklist Criteria and Tracking" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695473/SWE-088+-+Software+Peer+Reviews+and+Inspections+-+Checklist+Criteria+and+Tracking] The project manager shall, for each planned software peer review or software inspection:

- %swe[.a] Use a checklist or formal reading technique (e.g., perspective-based reading) to evaluate the work products.
- %swe[.b] Use established readiness and completion criteria.
- %swe[.c] Track actions identified in the reviews until they are resolved.
- %swe[.d] Identify the required participants.

%swe[SWE-089 section=5.3.4 classes=A,B,C,F authority=Center authority_f=CIO applies=always title="Software Peer Reviews and Inspections - Basic Measurements" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695474/SWE-089+-+Software+Peer+Reviews+and+Inspections+-+Basic+Measurements] The project manager shall, for each planned software peer review or software inspection, record necessary measurements.

## 5.4 Software Measurements

5.4.1 Software measurement is a primary tool for managing software processes and evaluating the quality of software products. Analysis of measures provides insight into the capability of the software organization and identifies opportunities for software process and product improvements. Software measurement programs at multiple levels are established to meet measurement objectives. The requirements below are designed to reinforce the use of measurement at the project, Center software organization, and NASA Chief Engineer levels to assist in managing projects, assuring quality, and improving software engineering practices. Measurement programs are designed to meet the following goals:

a. Improve future software planning and software cost estimation.

b. Describe and record information about a software product during its life cycle.

c. Assist usability and maintainability of a software product.

d. Monitor and control software life cycle processes.

e. Communicate information about the system, software product, or service.

f. Provide a history, including lessons learned, during the development and maintenance to support management and process improvement.

g. Provide evidence that the processes were followed.

h. Provide indicators of software quality.

i. Track the status of software engineering improvement and assurance programs.

j. Report the status of software engineering improvements and assurance programs to Center software organizations and Center SMA.

%swe[SWE-090 section=5.4.2 classes=A,B,C authority=Center applies=always title="Management and Technical Measurements" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695475/SWE-090+-+Management+and+Technical+Measurements] The project manager shall establish, record, maintain, report, and utilize software management and technical measurements.

> Note: The NASA-HDBK-2203 contains a set of candidate management indicators that may be used on a software development project. The NASA Chief Engineer may identify and document additional Center measurement objectives, software measurements, collection procedures and guidelines, and analysis procedures for selected software projects and software development organizations. The software measurement process includes collecting software technical measurement data from the project’s software developer(s).

%swe[SWE-093 section=5.4.3 classes=A,B,C authority=Center applies=always title="Analysis of Measurement Data" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695480/SWE-093+-+Analysis+of+Measurement+Data] The project manager shall analyze software measurement data collected using documented project-specified and Center/organizational analysis procedures.

%swe[SWE-094 section=5.4.4 classes=A,B,C authority=Center applies=always title="Reporting of Measurement Analysis" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695481/SWE-094+-+Reporting+of+Measurement+Analysis] The project manager shall provide access to the software measurement data, measurement analyses, and software development status as requested to the sponsoring Mission Directorate, the NASA Chief Engineer, the Center Technical Authorities, HQ SMA, and other organizations as appropriate.

%swe[SWE-199 section=5.4.5 classes=A,B,C authority=Center applies=always title="Performance Measures" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695532/SWE-199+-+Performance+Measures] The project manager shall monitor measures to ensure the software will meet or exceed performance and functionality requirements, including satisfying constraints.

> Note: The metrics could include planned and actual use of computer hardware resources (such as processor capacity, memory capacity, input/output device capacity, auxiliary storage device capacity, and communications/network equipment capacity, bus traffic, partition allocation) over time. As part of the verification of the software detailed design, the developer will update the estimation of the technical resource metrics. As part of the verification of the coding, testing, and validation, the technical resource metrics will be updated with the measured values and will be compared to the margins.

%swe[SWE-200 section=5.4.6 classes=A,B authority=Center applies=always title="Software Requirements Volatility Metrics" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695533/SWE-200+-+Software+Requirements+Volatility+Metrics] The project manager shall collect, track, and report software requirements volatility metrics.

## 5.5 Software Non-conformance or Defect Management

%swe[SWE-201 section=5.5.1 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Software Non-Conformances" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695535/SWE-201+-+Software+Non-Conformances] The project manager shall track and maintain software non-conformances (including defects in tools and appropriate ground software).

%swe[SWE-202 section=5.5.2 classes=A,B,C,F authority=Center authority_f=CIO applies=always title="Software Severity Levels" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695536/SWE-202+-+Software+Severity+Levels] The project manager shall define and implement clear software severity levels for all software non-conformances (including tools, COTS, GOTS, MOTS, OSS, reused software components, and applicable ground systems).

> Note: At a minimum, classes should include loss of life or loss of vehicle, mission success, visible to the user with operational workarounds, and an ‘other’ class that does not meet previous criteria.

%swe[SWE-203 section=5.5.3 classes=A,B,C authority=Center applies=always title="Mandatory Assessments for Non-Conformances" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695537/SWE-203+-+Mandatory+Assessments+for+Non-Conformances] The project manager shall implement mandatory assessments of reported non-conformances for all COTS, GOTS, MOTS, OSS, and/or reused software components.

> Note: This includes operating systems, run-time systems, device drivers, code generators, compilers, math libraries, and build and Configuration Management (CM) tools. It should be performed pre-flight, with mandatory code audits for critical defects.

%swe[SWE-204 section=5.5.4 classes=A,B authority=Center applies=always title="Process Assessments" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695538/SWE-204+-+Process+Assessments] The project manager shall implement process assessments for all high-severity software non-conformances (closed loop process).
