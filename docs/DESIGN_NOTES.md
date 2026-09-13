# Processor design decisions

## Forwarding priority

The execute operand muxes start from the decoded register values, apply MEM/WB
forwarding, then override with the newer EX/MEM ALU result. A load in EX/MEM supplies
an address, not loaded data, so it is excluded from this bypass. Store data and
branch operands share the bypass network.

## The load-use interlock

When ID consumes the destination of a load currently in EX, PC and IF/ID hold while
ID/EX becomes invalid. The load advances; on the next cycle its value is available
from WB. Source-use bits avoid treating instruction fields that are not operands
as false dependencies. Writes to x0 do not create dependencies.

## Control hazards

Branches compare forwarded operands in EX. A taken branch clears younger valid
bits and redirects fetch. Flush takes priority over a younger illegal decode,
which prevents a wrong-path instruction from causing a diagnostic fault. The
directed branch test also checks that wrong-path stores leave memory unchanged.

## Independent checks

The Python interpreter executes one architectural instruction at a time; it has no
pipeline state or forwarding logic. Its retirement PC/instruction/register results
are compared with the Verilog trace, followed by full data-memory comparison.
Fixed seeds make randomized failures reproducible. Directed timing assertions check
stall counts independently of architectural correctness.

## Performance interpretation

Measured IPC includes fetch-to-final-retirement time. Short directed programs have
large fill and branch overhead relative to their instruction count. The seeded
250-instruction programs achieve higher IPC because most instructions can overlap.
These results characterize the documented workloads, not a universal processor IPC.
