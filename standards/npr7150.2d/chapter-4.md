<!-- NPR 7150.2D, NASA Software Engineering Requirements (effective March 08, 2022), from https://nodis3.gsfc.nasa.gov/displayDir.cfm?Internal_ID=N_PR_7150_002D_&page_name=Chapter4, retrieved 2026-11-22. Taken by tools/npr7150 in skein's repository (zig build npr7150), and kept by hand from here when NASA revises the NPR. -->

# Chapter 4: Software Engineering Life Cycle Requirements

## 4.1 Software Requirements

4.1.1 The requirements phase is one of the most critical phases of software engineering. Studies show that the top problems in the software industry are due to poor requirements elicitation, inadequate requirements specification, and inadequate management of changes to requirements. Requirements provide the foundation for the entire life cycle, as well as for the software product. Requirements also provide a basis for planning, estimating, and monitoring. Requirements are based on customer, user, and other stakeholder needs and design and development constraints. The development of requirements includes elicitation, analysis, documentation, verification, and validation. Ongoing customer validation of the requirements to ensure the end products meet customer needs is an integral part of the life cycle process. Customer validation can be accomplished via rapid prototyping and customer-involved reviews of iterative and final software requirements.

%swe[SWE-050 section=4.1.2 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Software Requirements" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695421/SWE-050+-+Software+Requirements] The project manager shall establish, capture, record, approve, and maintain software requirements, including requirements for COTS, GOTS, MOTS, OSS, or reused software components, as part of the technical specification.

> Note: The software technical requirements definition process is used to transform the baselined stakeholder expectations into unique, quantitative, and measurable technical software requirements that can be used for defining a design solution for the software end products and related enabling products. This process also includes validation of the requirements to ensure that the requirements are well-formed (clear and unambiguous), complete (agrees with customer and stakeholder needs and expectations), consistent (conflict free), and individually verifiable and traceable to a higher level requirement. Recommended content for a software specification can be found in NASA-HDBK-2203.

%swe[SWE-051 section=4.1.3 classes=A,B,C authority=Center applies=always title="Software Requirements Analysis" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695426/SWE-051+-+Software+Requirements+Analysis] The project manager shall perform software requirements analysis based on flowed-down and derived requirements from the top-level systems engineering requirements, safety and reliability analyses, and the hardware specifications and design.

%swe[SWE-184 section=4.1.4 classes=A,B,C authority=Center applies=always title="Software-related Constraints and Assumptions" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695520/SWE-184+-+Software-related+Constraints+and+Assumptions] The project manager shall include software related safety constraints, controls, mitigations, and assumptions between the hardware, operator, and software in the software requirements documentation.

%swe[SWE-053 section=4.1.5 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Manage Requirements Changes" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695435/SWE-053+-+Manage+Requirements+Changes] The project manager shall track and manage changes to the software requirements.

%swe[SWE-054 section=4.1.6 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Corrective Action for Inconsistencies" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695439/SWE-054+-+Corrective+Action+for+Inconsistencies] The project manager shall identify, initiate corrective actions, and track until closure inconsistencies among requirements, project plans, and software products.

%swe[SWE-055 section=4.1.7 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Requirements Validation" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695440/SWE-055+-+Requirements+Validation] The project manager shall perform requirements validation to ensure that the software will perform as intended in the customer environment.

## 4.2 Software Architecture

4.2.1 Experience confirms that the quality and longevity of a software-reliant system is primarily determined by its architecture. The software architecture underpins a system’s software design and code; it represents the earliest design decisions, ones that are difficult and costly to change later. The transformation of the derived and allocated requirements into the software architecture results in the basis for all software development work.

4.2.2 A software architecture:

a. Formalizes precise subsystem decompositions.

b. Defines and formalizes the dependencies among software work products within the integrated system.

c. Serves as the basis for evaluating the impacts of proposed changes.

d. Maintains rules for use by subsequent software engineers that ensure a consistent software system as the work products evolve.

e. Provides a stable structure for use by future groups through the documentation of the architecture, its views and patterns, and its rules.

f. Follows guidelines created by the NASA Space Asset and the Enterprise Protection Program to protect mission architectures.

g. Documents the valid and invalid modes or states of operation within the software requirements.

%swe[SWE-057 section=4.2.3 classes=A,B,C authority=Center applies=always title="Software Architecture" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695442/SWE-057+-+Software+Architecture] The project manager shall transform the requirements for the software into a recorded software architecture.

> Note: A documented software architecture that describes: the software’s structure; identifies the software qualities (i.e., performance, modifiability, and security); identifies the known interfaces between the software components and the components external to the software (both software and hardware); identifies the interfaces between the software components and identifies the software components. Reference NASA’s Software Architecture Review Board (SARB) paper NTRS ID 20160005787, “Quality Attributes for Mission Flight Software: A Reference for Architects.”

%swe[SWE-143 section=4.2.4 classes=A,B,C authority=Center applies=always title="Software Architecture Review" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695501/SWE-143+-+Software+Architecture+Review] The project manager shall perform a software architecture review on the following categories of projects:

- %swe[.a] Category 1 Projects as defined in NPR 7120.5.
- %swe[.b] Category 2 Projects as defined in NPR 7120.5, that have Class A or Class B payload risk classification per NPR 8705.4.

## 4.3 Software Design

4.3.1 Software design is the process of defining the software architecture, components, modules, interfaces, and data for a software system to satisfy specified requirements. The software architecture is the fundamental organization of a system embodied in its components, their relationships to each other and the environment, and the principles guiding its design and evolution. The software architectural design is concerned with creating a strong overall structure for software entities that fulfill the allocated system and software-level requirements. Typical views captured in an architectural design include the decomposition of the software subsystem into design entities, computer software configuration items, definitions of external and internal interfaces, dependency relationships among entities and system resources, and finite state machines. The design should be further refined into lower-level entities that permit the implementation by coding in a programming language. Typical attributes that are documented for lower-level entities include the identifier, type, purpose, function, constraints, subordinates, dependencies, interface, resources, processing, and data. Rigorous specification languages, graphical representations, and related tools have been developed to support the evaluation of critical properties at the design level. Projects are encouraged to take advantage of these improved design techniques to prevent and eliminate errors as early in the life cycle as possible. Software, developed or purchased, has additional requirements to comply with from Section 508 of the Rehabilitation Act, as defined inNPR 2800.2.

%swe[SWE-058 section=4.3.2 classes=A,B,C authority=Center applies=always title="Detailed Design" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695443/SWE-058+-+Detailed+Design] The project manager shall develop, record, and maintain a software design based on the software architectural design that describes the lower-level units so that they can be coded, compiled, and tested.

## 4.4 Software Implementation

4.4.1 Software implementation consists of implementing the requirements and design into code, data, and records. Software implementation also consists of following coding methods and standards. Unit testing is also usually a part of software implementation (unit testing can also be conducted during the testing phase).

%swe[SWE-060 section=4.4.2 classes=A,B,C,F authority=Center authority_f=CIO applies=always title="Coding Software" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695444/SWE-060+-+Coding+Software] The project manager shall implement the software design into software code.

%swe[SWE-061 section=4.4.3 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Coding Standards" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695445/SWE-061+-+Coding+Standards] The project manager shall select, define, and adhere to software coding methods, standards, and criteria.

%swe[SWE-135 section=4.4.4 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Static Analysis" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695494/SWE-135+-+Static+Analysis] The project manager shall use static analysis tools to analyze the code during the development and testing phases to, at a minimum, detect defects, software security, code coverage, and software complexity.

> Note: Although no maximum cyclomatic complexity score is required for non-safety critical software, all software projects should regularly collect and maintain complexity metrics and use them to manage risk, either when high-complexity code must be modified, or proactively to improve the overall quality and maintenance of the code base. For safety critical software, the analysis should take into account the requirements for cyclomatic complexity and code coverage as defined in 3.7.5 and 3.7.4 respectively.

%swe[SWE-062 section=4.4.5 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Unit Test" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695446/SWE-062+-+Unit+Test] The project manager shall unit test the software code.

> Note: For safety critical software, the unit testing should follow the requirement established in 3.7.4 of this document.

%swe[SWE-186 section=4.4.6 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Unit Test Repeatability" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695522/SWE-186+-+Unit+Test+Repeatability] The project manager shall assure that the unit test results are repeatable.

%swe[SWE-063 section=4.4.7 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Release Version Description" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695447/SWE-063+-+Release+Version+Description] The project manager shall provide a software version description for each software release.

%swe[SWE-136 section=4.4.8 classes=A,B,C authority=Center applies=always title="Software Tool Accreditation" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695495/SWE-136+-+Software+Tool+Accreditation] The project manager shall validate and accredit the software tool(s) required to develop or maintain software.

> Note: All software development tools contain some number of software defects. Validation and accreditation of the critical software development and maintenance tools ensure that the tools being used during the software development life cycle do not generate or insert errors in the software executable components. Software tool accreditation is the certification that a software tool is acceptable for use for a specific purpose. Accreditation is conferred by the organization best positioned to make the judgment that the software tool in question is acceptable. The likelihood that work products will function properly is enhanced, and the risk of error is reduced if the tools used in the development and maintenance processes have been validated and accredited themselves.

## 4.5 Software Testing

4.5.1 The purpose of testing is to verify the software functionality and remove defects. Testing verifies the code against the requirements and the design to ensure that the requirements are implemented. Testing also identifies problems and defects that are corrected and tracked to closure before product delivery. Testing also validates that the software operates appropriately in the intended environment. Please note for Class A software there are additional software test requirements and software integration requirements as defined in NPR 8705.2.

%swe[SWE-065 section=4.5.2 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Test Plan, Procedures, Reports" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695448/SWE-065+-+Test+Plan+Procedures+Reports] The project manager shall establish and maintain:

- %swe[.a] Software test plan(s).
- %swe[.b] Software test procedure(s).
- %swe[.c] Software test(s), including any code specifically written to perform test procedures.
- %swe[.d] Software test report(s).

%swe[SWE-066 section=4.5.3 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Perform Testing" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695449/SWE-066+-+Perform+Testing] The project manager shall test the software against its requirements.

> Note: A best practice for Class A, B, and C software projects is to have formal software testing planned, conducted, witnessed, and approved by an independent organization outside of the development team.

%swe[SWE-187 section=4.5.4 classes=A,B,C,F authority=Center authority_f=CIO applies=always title="Control of Software Items" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695523/SWE-187+-+Control+of+Software+Items] The project manager shall place software items under configuration management prior to testing.

> Note: This includes the software components being tested and the software components being used to test the software, including components such as support software, models, simulations, ground support software, COTS, GOTS, MOTS, OSS, or reused software components.

%swe[SWE-068 section=4.5.5 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Evaluate Test Results" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695451/SWE-068+-+Evaluate+Test+Results] The project manager shall evaluate test results and record the evaluation.

%swe[SWE-070 section=4.5.6 classes=A,B,C authority=Center applies=always title="Models, Simulations, Tools" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695452/SWE-070+-+Models+Simulations+Tools] The project manager shall use validated and accredited software models, simulations, and analysis tools required to perform qualification of flight software or flight equipment.

> Note: Information regarding specific V&V techniques and the analysis of models and simulations can be found in NASA-STD-7009, Standard for Models and Simulations, NASA-HDBK-7009, Handbook for Models and Simulations, or discipline-specific recommended practice guides.

%swe[SWE-071 section=4.5.7 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Update Test Plans and Procedures" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695453/SWE-071+-+Update+Test+Plans+and+Procedures] The project manager shall update the software test and verification plan(s) and procedure(s) to be consistent with software requirements.

%swe[SWE-073 section=4.5.8 classes=A,B,C authority=Center applies=always title="Platform or Hi-Fidelity Simulations" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695454/SWE-073+-+Platform+or+Hi-Fidelity+Simulations] The project manager shall validate the software system on the targeted platform or high-fidelity simulation.

> Note: Typically, a high-fidelity simulation has the exact processor, processor performance, timing, memory size, and interfaces as the target system.

%swe[SWE-189 section=4.5.9 classes=A,B,C,D authority=Center applies=always title="Code Coverage Measurements" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695524/SWE-189+-+Code+Coverage+Measurements] The project manager shall ensure that the code coverage measurements for the software are selected, implemented, tracked, recorded, and reported.

> Note: This requirement can be met by running unit, integration, and validation tests; measuring the code coverage; and achieving the code coverage by additional (requirement based) tests, inspection, or analysis.

If the project does not get 100 percent structural coverage, it means one of four things and each requires action on the project manager’s part:

- Requirement missing - the code that hasn’t been covered is performing an essential activity, but no requirement indicates that this should be done;
- Test missing - the code that hasn’t been covered relates to an existing requirement, but no test was implemented for it;
- Extraneous/dead code – the code that hasn’t been covered is not traceable to any requirement and isn’t needed by the software;
- Deactivated code - the code that hasn’t been covered isn’t traceable to any requirements for the current system, but is intended to be executed in specific configurations.

The code coverage data and any rationale for uncovered code should be presented and reviewed at major project milestones.

%swe[SWE-190 section=4.5.10 classes=A,B,C authority=Center applies=always title="Verify Code Coverage" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695525/SWE-190+-+Verify+Code+Coverage] The project manager shall verify code coverage is measured by analysis of the results of the execution of tests.

> Note: If it can be justified that the required percentage cannot be achieved by test execution, the analysis, inspection, or review of design can be applied to the non-covered code. The goal of the complementary analysis is to assess that the non-covered code behavior is as expected.

%swe[SWE-191 section=4.5.11 classes=A,B,C,F authority=Center authority_f=CIO applies=always title="Software Regression Testing" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695526/SWE-191+-+Software+Regression+Testing] The project manager shall plan and conduct software regression testing to demonstrate that defects have not been introduced into previously integrated or tested software and have not produced a security vulnerability.

%swe[SWE-192 section=4.5.12 classes=A,B,C,D authority=Center applies=always title="Software Hazardous Requirements" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695527/SWE-192+-+Software+Hazardous+Requirements] The project manager shall verify through test the software requirements that trace to a hazardous event, cause, or mitigation technique.

%swe[SWE-193 section=4.5.13 classes=A,B,F authority=Center authority_f=CIO applies=always title="Acceptance Testing for Affected System and Software Behavior" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695528/SWE-193+-+Acceptance+Testing+for+Affected+System+and+Software+Behavior] The project manager shall develop acceptance tests for loaded or uplinked data, rules, and code that affects software and software system behavior.

> Note: These acceptance tests should validate and verify the data, rules, and code for nominal and off-nominal scenarios.

%swe[SWE-211 section=4.5.14 classes=A,B,C authority=Center applies=always title="Test Levels of Non-Custom Developed Software" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695542/SWE-211+-+Test+Levels+of+Non-Custom+Developed+Software] The project manager shall test embedded COTS, GOTS, MOTS, OSS, or reused software components to the same level required to accept a custom developed software component for its intended use.

## 4.6 Software Operations, Maintenance, and Retirement

4.6.1 Planning for operations, maintenance, and retirement are typically considered throughout the software life cycle. Operational concepts and scenarios are derived from customer requirements and validated in the operational or simulated environment. Software maintenance activities sustain the software product after the product is delivered to the customer until retirement.

%swe[SWE-075 section=4.6.2 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Plan Operations, Maintenance, Retirement" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695456/SWE-075+-+Plan+Operations+Maintenance+Retirement] The project manager shall plan and implement software operations, maintenance, and retirement activities.

%swe[SWE-077 section=4.6.3 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Deliver Software Products" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695457/SWE-077+-+Deliver+Software+Products] The project manager shall complete and deliver the software product to the customer with appropriate records, including as-built records, to support the operations and maintenance phase of the software’s life cycle.

%swe[SWE-194 section=4.6.4 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Delivery Requirements Verification" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695529/SWE-194+-+Delivery+Requirements+Verification] The project manager shall complete, prior to delivery, verification that all software requirements identified for this delivery have been met or dispositioned, that all approved changes have been implemented, and that all defects designated for resolution prior to delivery have been resolved.

%swe[SWE-195 section=4.6.5 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Software Maintenance Phase" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695530/SWE-195+-+Software+Maintenance+Phase] The project manager shall maintain the software using standards and processes per the applicable software classification throughout the maintenance phase.

%swe[SWE-196 section=4.6.6 classes=A,B,C,D,F authority=Center authority_f=CIO applies=always title="Software Retirement Archival" handbook=https://swehb.nasa.gov/spaces/SWEHBVD/pages/102695531/SWE-196+-+Software+Retirement+Archival] The project manager shall identify the records and software tools to be archived, the location of the archive, and procedures for access to the products for software retirement or disposal.
