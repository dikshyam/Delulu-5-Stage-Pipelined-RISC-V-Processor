// module instr_mem (
//     input  logic [63:0] addr,          // Address input
//     output logic [31:0] instruction,   // Fetched instruction
//     output logic valid,                // Instruction valid signal
//     output logic last_instr            // Last instruction signal
// );

//     // Simple ROM storing instructions
//     logic [31:0] memory [0:255]; // 256 words = 1 KB of instruction memory

//     // Initialize instructions
//     initial begin
//         memory[0]  = 32'hfe010113; // addi sp, sp, -32
//         memory[1]  = 32'h00113c23; // sd ra, 24(sp)
//         memory[2]  = 32'h00813823; // sd s0, 16(sp)
//         memory[3]  = 32'h02010413; // addi s0, sp, 32
//         memory[4]  = 32'hfea42623; // sw a0, -20(s0)
//         memory[5]  = 32'hfeb43023; // sd a1, -32(s0)
//         memory[6]  = 32'h000007b7; // lui a5, 0x0
//         memory[7]  = 32'h00078513; // mv a0, a5
//         memory[8]  = 32'h00000317; // auipc t1, 0x0
//         memory[9]  = 32'h000300e7; // jalr t1
//         memory[10] = 32'h00000793; // li a5, 0
//         memory[11] = 32'h00078513; // mv a0, a5
//         memory[12] = 32'h01813083; // ld ra, 24(sp)
//         memory[13] = 32'h01013403; // ld s0, 16(sp)
//         memory[14] = 32'h02010113; // addi sp, sp, 32
//         memory[15] = 32'h00008067; // ret (Last Instruction)
//     end

//     // Read instruction from memory
//     always_comb begin
//         if (addr[9:2] < 256) begin
//             instruction = memory[addr[9:2]];  // Word-aligned fetch
//             valid = 1'b1;
//             last_instr = (addr[9:2] == 15);   // Check for last instruction
//         end else begin
//             instruction = 32'b0;             // Default to NOP on out-of-bounds
//             valid = 1'b0;
//             last_instr = 1'b0;
//         end
//     end

// endmodule
