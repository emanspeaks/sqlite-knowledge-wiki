+++
document = "SW-SCD"
revision = "Draft"
+++

# Safety-critical software determination

The determination, with the safety and mission assurance organization, of whether the project's software is safety-critical (SWE-205; %[SA-205]), by the criteria of section 4.2 of NASA-STD-8739.8B. It is made and recorded for every project, whatever its class: software found not safety-critical has this record, saying so and why, and nothing more is required of it for safety; software found safety-critical brings the safety tasks of the standard, and the template's `safety-critical` option is set to `true` in `.skein/config.toml`.

## Criteria

Software is safety-critical if it meets at least one of these (NASA-STD-8739.8B, section 4.2), as the hazard analysis shows:

| Criterion | Met? | Basis (hazard report, analysis) |
| --- | --- | --- |
| a. Causes or contributes to a system hazardous condition/event | | |
| b. Provides control or mitigation for a system hazardous condition/event | | |
| c. Controls safety-critical functions | | |
| d. Mitigates damage if a hazardous condition/event occurs | | |
| e. Detects, reports, and takes corrective action if the system reaches a potentially hazardous state | | |

## Determination

For each software component: safety-critical or not, the criteria it meets, and the hazards it is part of. A component found not safety-critical says on what that rests (no hazard analysis traces to it; the system has no hazards it can cause or control).

## Concurrence

Who made the determination with the safety and mission assurance organization, the software assurance concurrence, and the date. The determination is made again when the system's hazard analysis changes.
