# Architecture and verification contract

## Stages and interfaces

IF presents byte-addressed PC to combinational instruction memory. ID decodes and
reads a 32x32 register file. EX applies forwarding, computes arithmetic/address, and
resolves branches. MEM uses combinational read data and rising-edge stores. WB retires
the instruction and writes a register. A valid bit distinguishes bubbles from NOPs.

Reset is synchronous active-high; clears registers, PC, valid bits, fault and counters.
Data memory is external and is initialized by the testbench, not reset by the core.
x0 always reads as zero and ignores writes. Arithmetic wraps modulo 2^32.

Newest EX/MEM ALU result has priority over MEM/WB. EX/MEM loads never bypass an
address as loaded data. A decoded true source dependency on a load in EX freezes
PC and IF/ID, and injects a bubble in ID/EX. The load advances and forwards from WB
one cycle later. Store data and branch comparison use the same forwarded operands.

Taken branches resolve in EX, discard both younger instructions, and redirect PC.
Branch flush takes priority over a younger decode fault and over a load-use stall.
An older WB producer is also bypassed into ID to avoid simulator scheduling ambiguity.

## Scope

No multiply/divide, jumps, shifts, byte/halfword memory operations, CSR, interrupts,
caches, variable latency, MMU, compressed instructions, or precise exceptions.
Unsupported instructions and unaligned accesses set a sticky diagnostic fault and
stop the pipeline. This is not a precise architectural trap: older in-flight
instructions are not guaranteed to drain. Reset is required to resume.

The core assumes a valid mapped address; the test environment contains 16 KiB
instruction memory and 1 KiB data memory. All positive tests stay inside those ranges.
This core is suitable for simulation/teaching; FPGA or ASIC implementation requires
memory adaptation, synthesis, timing constraints, and physical verification.

## Counting

`cycles` counts each active post-reset clock until the requested final retirement.
`retired` counts every valid instruction, including stores, branches, and architectural
NOPs. IPC includes pipeline fill, interlocks, and branch flush penalties. The test
runner stops on a predetermined retirement count and pads younger instructions with
NOPs. Negative fault tests are not used as performance benchmarks.

## ModelSim / Questa alternative

Generate the program images once with the Python regression (or use its encoders).
From the repository directory, after creating `build/`, use:

```tcl
vlib work
vlog rtl/core.v tests/tb_core.v
vsim -c work.tb_core +PROGRAM=build/forwarding.hex +COUNT=8 +VCD -do "run -all; quit -f"
```

This is a compatible command recipe; only simulators listed in the checked-in
validation report have actually been executed for this package.

Encoding reference: [official RV32I specification](https://docs.riscv.org/reference/isa/unpriv/rv32.html).
