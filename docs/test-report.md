+++
document = "SW-STR"
revision = "Draft"
item = "PRD-08"
maturity = "D"
+++

# Software test report

The results of testing (%[SWE-065], %[SWE-068]), after handbook topic 5.11.

## Overview

Conclusions; remaining deficiencies, limitations and constraints, and their impact; the effect of the test environment.

## Results

The requirements verified, from the results recorded against the procedures. The tests' results are not kept in the repository: each release publishes those of the run that made it (`sqlite-knowledge-wiki-vX-test-results.toml`) and what Skein makes of them (`-coverage.txt`), and `skein coverage --results FILE` reads a downloaded results file. Without one, the table below counts only results kept in the repository:

```skein
coverage
```

## Problems and deviations

Problems met, deviations from the procedures, and the non-conformances written ([problem reports](problem-reports.md)).

## Test log

Dates, places, software versions, configuration and setup, people and witnesses.
