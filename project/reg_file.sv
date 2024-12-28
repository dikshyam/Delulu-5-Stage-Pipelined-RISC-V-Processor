// // module RegisterFile (
// //     input  logic clk,
// //     input  logic reset,
// //     input  logic [63:0] initial_stackptr, // Initial value for the stack pointer

// //     // Register addresses for read and write
// //     input  logic [4:0] rs1_addr,          // Read address 1
// //     input  logic [4:0] rs2_addr,          // Read address 2
// //     input  logic [4:0] writeback_addr,    // Writeback address

// //     // Data for writeback
// //     input  logic [63:0] writeback_data,   // Data to be written
// //     input  logic reg_write_enable,        // Enable signal for writeback

// //     // Outputs for read data
// //     output logic [63:0] rs1_data,         // Data from rs1
// //     output logic [63:0] rs2_data,         // Data from rs2

// //     // Outputs for system calls or debugging
// //     output logic [63:0] reg_a0,           // Register a0 (argument 0 / return value)
// //     output logic [63:0] reg_a1,
// //     output logic [63:0] reg_a2,
// //     output logic [63:0] reg_a3,
// //     output logic [63:0] reg_a4,
// //     output logic [63:0] reg_a5,
// //     output logic [63:0] reg_a6,
// //     output logic [63:0] reg_a7,

// //     // Explicit register file (separate input and output)
// //     input  logic [63:0] registers_in [0:31], // Input register file
// //     output logic [63:0] registers_out [0:31] // Output register file
// // );

// //     integer i;

// //     // Copy input registers to an internal register array for manipulation
// //     logic [63:0] registers [0:31];

// //     always_comb begin
// //         for (i = 0; i < 32; i++) begin
// //             registers[i] = registers_in[i];
// //         end
// //     end

// //     // Read logic
// //     assign rs1_data = (rs1_addr != 5'b0) ? registers[rs1_addr] : 64'h0; // Return 0 for address 0
// //     assign rs2_data = (rs2_addr != 5'b0) ? registers[rs2_addr] : 64'h0;

// //     // Debugging or system call access (specific argument registers)
// //     assign reg_a0 = registers[10]; // a0 register
// //     assign reg_a1 = registers[11]; // a1 register
// //     assign reg_a2 = registers[12]; // a2 register
// //     assign reg_a3 = registers[13]; // a3 register
// //     assign reg_a4 = registers[14]; // a4 register
// //     assign reg_a5 = registers[15]; // a5 register
// //     assign reg_a6 = registers[16]; // a6 register
// //     assign reg_a7 = registers[17]; // a7 register

// //     // Write logic
// //     // Write logic
// //     always_ff @(posedge clk) begin
// //         if (reset) begin
// //             // Reset all registers to 0
// //             for (i = 0; i < 32; i++) begin
// //                 registers[i] <= 64'h0;
// //             end

// //             // Initialize stack pointer (sp)
// //             registers[2] <= initial_stackptr;

// //             // Debug prints
// //             $display("[REGISTER AT RESET] initial_stackptr %h", initial_stackptr);
// //             for (i = 0; i < 32; i++) begin
// //                 $display("[REGISTER AT RESET] Register x%0d updated to %h", i, registers[i]);
// //             end

// //             $display("[REGISTER RESET] All registers reset and stack pointer initialized");
// //         end 

// //         else if (reg_write_enable) begin
// //             if (writeback_addr != 5'b0) begin // Prevent writing to x0 (hardwired to 0)
// //                 registers[writeback_addr] <= writeback_data;
// //                 $display("[REGISTER WRITE] Register x%0d updated to %h at time %t",
// //                         writeback_addr, writeback_data, $time);
// //             end
// //         end
// //     end


// //     // Assign updated registers back to output
// //     always_comb begin
// //         for (i = 0; i < 32; i++) begin
// //             registers_out[i] = registers[i];
// //         end
// //     end
// // endmodule
// module RegisterFile (
//     input  logic clk,
//     input  logic reset,

//     // Register Addresses
//     input  logic [4:0] rs1_addr,          // Read address 1
//     input  logic [4:0] rs2_addr,          // Read address 2
//     input  logic [4:0] writeback_addr,    // Writeback address

//     // Data for Writeback
//     input  logic [63:0] writeback_data,   // Data to be written
//     input  logic reg_write_enable,        // Enable signal for writeback

//     // Register Values (Input from Top)
//     input  logic [63:0] registers_in [0:31], 

//     // Updated Registers (Output to Top)
//     output logic [63:0] registers_out [0:31], 

//     // Outputs for Read Data
//     output logic [63:0] rs1_data,         // Data from rs1
//     output logic [63:0] rs2_data          // Data from rs2
// );

//     logic [63:0] registers_internal [0:31];

//     // Initialize Registers Internally
//     always_ff @(posedge clk) begin
//         if (reset) begin
//             for (int i = 0; i < 32; i++) begin
//                 registers_internal[i] <= 64'h0;
//             end
//         end else if (reg_write_enable && (writeback_addr != 5'b0)) begin
//             registers_internal[writeback_addr] <= writeback_data;
//             $display("[REGISTER WRITE] Register x%0d <= %h", writeback_addr, writeback_data);
//         end
//     end

//     // Read Logic
//     assign rs1_data = (rs1_addr != 5'b0) ? registers_internal[rs1_addr] : 64'h0;
//     assign rs2_data = (rs2_addr != 5'b0) ? registers_internal[rs2_addr] : 64'h0;

//     // Output Updated Registers
//     assign registers_out = registers_internal;

// endmodule

