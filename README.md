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

- **RV64IM Instruction Set** – Supports integer and multiply/divide operations
- **Branch Prediction** – Static "predict-not-taken" model
- **Forwarding Logic** – Minimizes stalls due to data hazards
- **Instruction and Data Caches** – Simple cache structures with invalidation support
- **System Calls** – Handled via `do_ecall(...)` from the commit stage
- **Memory Write Queue** – Uses `do_pending_write(...)` for store management
- **Cache Invalidation** – Handles `MakeInvalid` transactions to maintain coherence

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
