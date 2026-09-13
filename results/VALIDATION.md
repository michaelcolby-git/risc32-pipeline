# Local validation

Executed with Python 3.12.14 on Windows, Icarus Verilog 10.1 (HDL), and ngspice 47 (analog), as applicable.

**26 scenarios passed**, including **3,000 randomized instructions**, differential retirement checking and full data-memory comparison. Four ISA-model unit tests passed.

| Workload | Retired | Cycles | Stalls | Flushes | IPC |
|---|---|---|---|---|---|
| forwarding | 8 | 12 | 0 | 0 | 0.6667 |
| load_use | 5 | 10 | 1 | 0 | 0.5000 |
| load_store | 5 | 10 | 1 | 0 | 0.5000 |
| load_branch | 3 | 10 | 1 | 1 | 0.3000 |
| branch_flush | 5 | 13 | 0 | 2 | 0.3846 |
| not_taken | 5 | 9 | 0 | 0 | 0.5556 |
| zero_register | 6 | 10 | 0 | 0 | 0.6000 |
| wb_id | 5 | 9 | 0 | 0 | 0.5556 |
| loop | 18 | 30 | 0 | 4 | 0.6000 |
| offset_sign | 6 | 11 | 1 | 0 | 0.5455 |
| random_0 | 250 | 255 | 1 | 0 | 0.9804 |
| random_1 | 250 | 262 | 8 | 0 | 0.9542 |
| random_2 | 250 | 258 | 4 | 0 | 0.9690 |
| random_3 | 250 | 258 | 4 | 0 | 0.9690 |
| random_4 | 250 | 258 | 4 | 0 | 0.9690 |
| random_5 | 250 | 257 | 3 | 0 | 0.9728 |
| random_6 | 250 | 258 | 4 | 0 | 0.9690 |
| random_7 | 250 | 257 | 3 | 0 | 0.9728 |
| random_8 | 250 | 257 | 3 | 0 | 0.9728 |
| random_9 | 250 | 262 | 8 | 0 | 0.9542 |
| random_10 | 250 | 258 | 4 | 0 | 0.9690 |
| random_11 | 250 | 255 | 1 | 0 | 0.9804 |

These numbers apply to the included reference implementation and test conditions.
Local checks are not formal verification, timing closure, silicon measurements, or
a reproduction of original resume measurements. GitHub Actions must be checked
separately after publishing; no cloud run is asserted by this local report.
