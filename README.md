# Five-stage 32-bit RISC pipeline

An educational Verilog core with EX/MEM and MEM/WB forwarding, a one-cycle load-use
interlock, and EX-stage branch resolution. Tests compare retired instructions and
data-memory contents against an independent sequential Python interpreter.

This is a new reference reconstruction; see [provenance](PROVENANCE.md).
The original project's ISA was not supplied. This implementation uses a documented
RV32I-encoding subset and does **not** claim full RISC-V compliance.

## Run the regression

```sh
python scripts/verify.py
```

Requires Python 3.10+ and Icarus Verilog (`iverilog`, `vvp`). No Python dependencies.
Reports, per-test retirement traces, and a forwarding waveform are written to `build/`.
The testbench clock is 20 ns. This establishes a simulation stimulus, not hardware Fmax.

## Datapath

```mermaid
flowchart LR
  IF["IF: instruction + PC"] --> ID["ID: decode + registers"]
  ID --> EX["EX: bypass + ALU + branch"]
  EX --> MEM["MEM: load / store"]
  MEM --> WB["WB: register write + retire"]
  MEM -. "ALU result" .-> EX
  WB -. "writeback data" .-> EX
  WB -. "same-cycle bypass" .-> ID
  EX -. "taken branch flush" .-> IF
```

| Supported instructions | Notes |
|---|---|
| ADD, SUB, AND, OR, XOR | 32-bit register operations |
| ADDI | Sign-extended 12-bit immediate; NOP = ADDI x0,x0,0 |
| LW, SW | Aligned 32-bit accesses |
| BEQ, BNE | Signed PC-relative offset; taken targets word aligned |

See [architecture and limitations](docs/ARCHITECTURE.md), [RTL](rtl/core.v),
[test runner](scripts/verify.py), and [reference ISA model](scripts/isa.py).
The regression checks dependency priority, store-data forwarding, load-to-branch,
load-to-store, wrong-path stores/illegal instructions, backward branches, x0,
negative immediates, and 12 fixed-seed randomized programs.

IPC is reported per workload with an explicit measurement window; 0.85 is not hardcoded.

## Measured validation

**26 scenarios passed**, including 3,000 randomized instructions. The ALU forwarding
sequence had zero load-use stalls; each directed immediate load-dependency sequence
had one. Per-workload IPC, cycle counts, and retirement traces are in the
[validation report](results/VALIDATION.md).
