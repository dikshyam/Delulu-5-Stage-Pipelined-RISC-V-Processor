# Delulu – 5-Stage Pipelined RISC-V Processor

Delulu is a 5-stage pipelined processor implementing the RV64IM instruction set architecture in SystemVerilog. It features instruction and data caching, forwarding logic for data hazard mitigation, and a static branch predictor (predict-not-taken). The processor simulates realistic system-level interactions while maintaining modular and verifiable pipeline behavior.

## Architecture Overview

Delulu follows a standard 5-stage RISC pipeline:

1. **Fetch** – Retrieves instructions from memory via an instruction cache (I-Cache)
2. **Decode** – Decodes instructions and generates control signals
3. **Execute** – Performs ALU operations, with full forwarding support
4. **Memory** – Interfaces with a data cache (D-Cache) for load/store operations
5. **Writeback** – Commits results to the register file

### Key Features

- **RV64IM Instruction Set** – Supports 64-bit and 32-bit (word) arithmetic, logical operations, multiply/divide, branches, loads/stores, jumps, and system instructions
- **Branch Prediction** – Static "predict-not-taken" model
- **Forwarding Logic** – Minimizes stalls due to data hazards
- **Instruction and Data Caches** – With invalidation support
- **System Calls** – Handled via `do_ecall(...)` at commit stage
- **Memory Write Queue** – Uses `do_pending_write(...)` for consistency
- **Cache Invalidation** – Responds to `MakeInvalid` transactions
- **Arbiter Logic** – Controls shared access to memory system between dcache & icache
- **Structured Logging by Module** – Each pipeline stage and subsystem logs detailed tabular data for debugging

### Supported Instructions

Delulu supports a comprehensive set of RISC-V RV64IM instructions across the following categories:

- **R-Type Arithmetic**: `ADD`, `SUB`, `XOR`, `OR`, `AND`, `SLL`, `SRL`, `SRA`, `SLT`, `SLTU`
- **R-Type Multiply/Divide**: `MUL`, `MULH`, `MULHSU`, `MULHU`, `DIV`, `DIVU`, `REM`, `REMU`
- **I-Type Arithmetic**: `ADDI`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI`, `SLTI`, `SLTIU`
- **RV64I Word Immediate Ops**: `ADDIW`, `SLLIW`, `SRLIW`, `SRAIW`
- **RV64I Word Register Ops**: `ADDW`, `SUBW`, `SLLW`, `SRLW`, `SRAW`
- **RV64M Word Multiply/Divide**: `MULW`, `DIVW`, `DIVUW`, `REMW`, `REMUW`
- **S-Type Stores** *(for tracking)*: `SB`, `SH`, `SW`, `SD`
- **B-Type Branches**: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`
- **Control Flow and Immediate**: `JAL`, `JALR`, `LUI`, `AUIPC`, `ECALL`, `EBREAK`
- **Loads** *(for tracking)*: `LB`, `LH`, `LW`, `LBU`, `LHU`, `LWU`, `LD`
- **Default Operation**: `NOP`

These operations are defined via an `ALUop` enumeration and used consistently across decode and execute stages to direct computation and control flow.

### Logging System

Each major module logs activity in its own `.log` file in tabular format to aid with debugging and traceability. These logs follow a consistent structure across modules and include relevant execution metadata such as timestamps, instruction details, and register updates.

> **Note:** If logs are not being generated or appear incomplete, check that the log file paths are correct and accessible from the simulation environment.

## Output & Debugging

- Instruction trace output via `$display`
- Final register file state printed on simulation completion
- Pipeline flush is triggered after system calls or invalidation events

## Resources

- [RISC-V ISA Specifications](https://riscv.org/specifications/)
- [SystemVerilog Tutorial (asic-world)](http://www.asic-world.com/verilog/veritut.html)
- [GTKWave – Waveform Viewer](http://gtkwave.sourceforge.net/)
- [Verilator – Verilog Simulator](http://www.veripool.org/wiki/verilator)

## Academic Integrity Notice

This project was completed as part of a university course assignment. It is published here for documentation and educational reference purposes only.

**If you are currently taking or plan to take a similar course, do not copy or reuse any portion of this work. Doing so would constitute academic dishonesty and violate university integrity policies.** Always do your own work and use this repository only to guide your understanding.
