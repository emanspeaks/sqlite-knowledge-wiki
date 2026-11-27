+++
document = "SW-STPR"
revision = "Draft"
item = "PRD-07"
maturity = "D"
+++

# Software test procedures

The test procedures and cases (%[SWE-065]), after handbook topic 5.14. Each is an item of the type `procedure`, `TST-001` and on, linked by `verifies` to the requirements it verifies; its results are recorded with `skein result` or a results file, and summarized in the [test report](test-report.md).

## Environment and schedule

The hardware, flight components, software, simulators and test beds; the schedule.

## Test cases

For each: purpose, software versions, prerequisites, steps and setup, inputs, expected results and how they are judged, pass and fail criteria, and its grouping (required verification, hazard control verification).

%procedure[TST-001 system verifies=SRS-001] Start the software from power-off and check that it reports its safe state. (An example: replace it.)
