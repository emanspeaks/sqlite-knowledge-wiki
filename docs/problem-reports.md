+++
document = "SW-PR"
revision = "Draft"
+++

# Problem reports and non-conformances

The software non-conformances, tracked to closure (%[SWE-201]), with their severity (%[SWE-202]), after handbook topic 5.01. Each is an item of the type `nonconformance`, `NCR-001` and on, of severity 1 (loss of life or vehicle) to 4, linked by `affects` to the requirements it is against; or an issue of the forge, cited as `#N`.

Each records: the software item and its configuration, the problem or change, who found it and when, the phase, its analysis and the action taken, approval, the verification of the fix and its release, safety impacts, and any workaround.

```skein
list nonconformance
```
