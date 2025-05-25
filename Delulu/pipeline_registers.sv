`include "pipeline_defs.sv"

// module IF_ID (
//     input  logic clk,
//     input  logic reset,
//     input  logic wr_en,              // Write enable
//     input  logic gen_bubble,         // Generate bubble (clear the pipeline register)
//     input  logic [63:0] pc_in,       // Input Program Counter (PC)
//     input  logic [31:0] instruction_in, // Input instruction
//     input  logic done_signal_in,
//     output logic [63:0] pc_out,      // Output Program Counter (PC)
//     output logic [31:0] instruction_out, // Output instruction
//     output  logic done_signal_out
// );
// // Internal pipeline registers
// logic [63:0] pc_reg;
// logic [31:0] instruction_reg;
// always_ff @(posedge clk) begin
//     if (reset) begin
//         // Clear the registers on reset
//         pc_reg <= 64'b0;
//         instruction_reg <= 32'b0;
//         $display("[DEBUG IF_ID] @%0t: Resetting IF_ID registers", $time);
//     end else if (wr_en) begin
//         if (gen_bubble) begin
//             // Generate a bubble (clear pipeline registers)
//             pc_reg <= 64'b0;
//             instruction_reg <= 32'b0;
//             $display("[DEBUG IF_ID] @%0t: Inserting bubble into IF_ID pipeline register", $time);
//         end else begin
//             // Normal write to pipeline registers
//             pc_reg <= pc_in;
//             instruction_reg <= instruction_in;
//             $display("[DEBUG IF_ID] @%0t: Writing IF_ID: PC=%h, Instruction=%h", $time, pc_in, instruction_in);
//         end
//     end else begin
//         // No write operation
//         $display("[DEBUG IF_ID] @%0t: No write to IF_ID pipeline register (wr_en=%b, gen_bubble=%b)", $time, wr_en, gen_bubble);
//     end
// end

// // Assign outputs
// assign pc_out = pc_reg;
// assign instruction_out = instruction_reg;
// assign done_signal_out = done_signal_in;

// endmodule


// module ID_EX_pipeline_reg (
//     input  logic        clk,
//     input  logic        reset,
//     input  logic [63:0] if_id_pc_out,
//     input  logic [31:0] if_id_instruction_out,
//     input  decoder_output decoded_inst,
//     input  logic [63:0] rs1_data,
//     input  logic [63:0] rs2_data,
//     input  logic        id_ex_wr_en,
//     input  logic        id_ex_gen_bubble,
//     input  logic        if_id_valid,        // Add incoming validity
//     input  logic [63:0] clk_counter,
//     input  logic done_signal_in,
//     input logic [4:0] rs1,
//     input logic [4:0] rs2,
//     input logic [4:0] rd,

//     output logic        id_ex_valid,        // Add outgoing validity
//     output logic [63:0] id_ex_pc_reg,
//     output logic [31:0] id_ex_instruction_reg,
//     output logic [63:0] id_ex_rs1_data,
//     output logic [63:0] id_ex_rs2_data,
//     output decoder_output id_ex_decoded_inst_reg,
//     output  logic done_signal_out,
//     output logic [4:0] id_ex_rs1,
//     output logic [4:0] id_ex_rs2,
//     output logic [4:0] id_ex_rd
// );

//     always_ff @(posedge clk or posedge reset) begin
//         if (reset) begin
//             id_ex_valid           <= 1'b0;
//             id_ex_pc_reg          <= 64'b0;
//             id_ex_instruction_reg <= 32'b0;
//             id_ex_rs1_data        <= 64'b0;
//             id_ex_rs2_data        <= 64'b0;
//             id_ex_decoded_inst_reg <= '0;
//             id_ex_rs1 <= 5'b0;
//             id_ex_rs2 <= 5'b0;
//             id_ex_rd <= 5'b0;
//             $display("[RESET] ID_EX pipeline reset at clk_counter=%0d", clk_counter);
//         end else if (id_ex_wr_en) begin
//             if (id_ex_gen_bubble) begin
//                 // Generate bubble and invalidate the stage
//                 id_ex_valid           <= 1'b0;
//                 id_ex_pc_reg          <= 64'b0;
//                 id_ex_instruction_reg <= 32'b0;
//                 id_ex_rs1_data        <= 64'b0;
//                 id_ex_rs2_data        <= 64'b0;
//                 id_ex_decoded_inst_reg <= '0;
//                 id_ex_rs1 <= 5'b0;
//                 id_ex_rs2 <= 5'b0;
//                 id_ex_rd <= 5'b0;
//                 $display("[ID_EX BUBBLE] Generating bubble at clk_counter=%0d", clk_counter);
//             end else begin
//                 // Update pipeline registers and propagate validity
//                 id_ex_valid           <= if_id_valid;
//                 id_ex_pc_reg          <= if_id_pc_out;
//                 id_ex_instruction_reg <= if_id_instruction_out;
//                 id_ex_rs1_data        <= rs1_data;
//                 id_ex_rs2_data        <= rs2_data;
//                 id_ex_decoded_inst_reg <= decoded_inst;
//                 id_ex_rs1 <= rs1;
//                 id_ex_rs2 <= rs2;
//                 id_ex_rd <= rd;
//                 $display("[ID_EX WRITE] PC=%h | Instruction=%h | Valid=%b | clk_counter=%0d",
//                         if_id_pc_out, if_id_instruction_out, if_id_valid, clk_counter);
//             end
//         end
//     end

//     assign done_signal_out = done_signal_in;

// endmodule



// module EX_MEM (
//     input  logic        clk,
//     input  logic        reset,
//     input  logic        wr_en,
//     input  logic        gen_bubble,

//     // Pipeline Inputs
//     input  logic [63:0] pc_in,
//     input  logic [31:0] instruction_in,   // New: Instruction tracking
//     input  logic [63:0] alu_result_in,
//     input  logic [63:0] rs2_data_in,
//     //input  logic [4:0]  rd_in,
//     input  logic        mem_write_in,
//     input  logic        mem_read_in,
//     input  logic        reg_write_in,
//     input  logic        mem_to_reg_in,
//     input  decoder_output ex_decoded_inst_in,
//     input  logic done_signal_in,
//     input logic [4:0] rs1_in,
//     input logic [4:0] rs2_in,
//     input logic [4:0] rd_in,

//     // Pipeline Outputs
//     output logic [63:0] pc_out,
//     output logic [31:0] instruction_out,  // New: Instruction output
//     output logic [63:0] alu_result_out,
//     output logic [63:0] rs2_data_out,
//     //output logic [4:0]  rd_out,
//     output logic        mem_write_out,
//     output logic        mem_read_out,
//     output logic        reg_write_out,
//     output logic        mem_to_reg_out,
//     output decoder_output ex_decoded_inst_out,
//     output  logic done_signal_out,
//     output logic [4:0] rs1_out,
//     output logic [4:0] rs2_out,
//     output logic [4:0] rd_out
// );

//     // Register declarations
//     decoder_output ex_mem_decoded_inst_reg;
//     logic [31:0] instruction_reg;

//     // Pipeline Register Behavior
//     always_ff @(posedge clk or posedge reset) begin
//         if (reset) begin
//             // Reset all registers
//             alu_result_out <= 64'b0;
//             rs2_data_out   <= 64'b0;
//             //rd_out         <= 5'b0;
//             mem_write_out  <= 1'b0;
//             mem_read_out   <= 1'b0;
//             reg_write_out  <= 1'b0;
//             mem_to_reg_out <= 1'b0;
//             ex_mem_decoded_inst_reg <= '0;
//             pc_out <= 64'b0;
//             instruction_reg <= 32'b0;
//             rs1_out <= 5'b0;
//             rs2_out <= 5'b0;
//             rd_out <= 5'b0;
//         end else if (wr_en) begin
//             if (gen_bubble) begin
//                 // Generate pipeline bubble
//                 alu_result_out <= 64'b0;
//                 rs2_data_out   <= 64'b0;
//                 //rd_out         <= 5'b0;
//                 mem_write_out  <= 1'b0;
//                 mem_read_out   <= 1'b0;
//                 reg_write_out  <= 1'b0;
//                 mem_to_reg_out <= 1'b0;
//                 ex_mem_decoded_inst_reg <= '0;
//                 pc_out <= 64'b0;
//                 instruction_reg <= 32'b0;
//                 rs1_out <= 5'b0;
//                 rs2_out <= 5'b0;
//                 rd_out <= 5'b0;
//             end else begin
//                 // Normal operation
//                 alu_result_out <= alu_result_in;
//                 rs2_data_out   <= rs2_data_in;
//                 //rd_out         <= rd_in;
//                 mem_write_out  <= mem_write_in;
//                 mem_read_out   <= mem_read_in;
//                 reg_write_out  <= reg_write_in;
//                 mem_to_reg_out <= mem_to_reg_in;
//                 ex_mem_decoded_inst_reg <= ex_decoded_inst_in;
//                 pc_out <= pc_in;
//                 instruction_reg <= instruction_in;
//                 rs1_out <= rs1_in;
//                 rs2_out <= rs2_in;
//                 rd_out <= rd_in;
//             end
//         end
//     end

//     // Assign outputs
//     assign ex_decoded_inst_out = ex_mem_decoded_inst_reg;
//     assign instruction_out = instruction_reg;
//     assign done_signal_out = done_signal_in;

// endmodule

// module MEM_WB_pipeline_reg (
//     input  logic        clk,
//     input  logic        reset,

//     // Pipeline Control Signals
//     input  logic        mem_wb_wr_en,               
//     input  logic        mem_wb_gen_bubble,          

//     // Inputs from MEM Stage
//     input  logic [63:0] mem_result,        
//     input  logic [63:0] mem_read_data,     // Add Memory Read Data
//     input  logic [31:0] mem_instruction,   
//     input  logic [63:0] mem_pc,            
//     input  decoder_output mem_wb_decoded_inst_in,  

//     // Outputs to Writeback Stage
//     output decoder_output out_mem_wb_decoded_inst, 
//     output logic [63:0] out_mem_wb_result,       
//     output logic [63:0] out_mem_wb_mem_read_data,  // Memory Read Data Output
//     output logic [31:0] out_mem_wb_instruction,  
//     output logic [63:0] out_mem_wb_pc
// );

//     // Register Declarations
//     logic [63:0] mem_wb_result_reg;
//     logic [63:0] mem_wb_mem_read_data_reg;  // Add Memory Read Data Register
//     logic [31:0] mem_wb_instruction_reg;
//     logic [63:0] mem_wb_pc_reg;
//     decoder_output mem_wb_decoded_inst_reg;
//     logic        mem_wb_reg_write_reg;
//     logic        mem_wb_mem_to_reg_reg;

//     // Pipeline Register Behavior
//     always_ff @(posedge clk or posedge reset) begin
//         if (reset) begin
//             mem_wb_result_reg <= 64'b0;
//             mem_wb_mem_read_data_reg <= 64'b0;  // Reset Memory Read Data
//             mem_wb_instruction_reg <= 32'b0;
//             mem_wb_pc_reg <= 64'b0;
//             mem_wb_decoded_inst_reg <= '0;
//         end else if (mem_wb_wr_en) begin
//             if (mem_wb_gen_bubble) begin
//                 mem_wb_result_reg <= 64'b0;
//                 mem_wb_mem_read_data_reg <= 64'b0;  // Bubble Memory Read Data
//                 mem_wb_instruction_reg <= 32'b0;
//                 mem_wb_pc_reg <= 64'b0;
//                 mem_wb_decoded_inst_reg <= '0;
//             end else begin
//                 mem_wb_result_reg <= mem_result;
//                 mem_wb_mem_read_data_reg <= mem_read_data;  // Forward Memory Read Data
//                 mem_wb_instruction_reg <= mem_instruction;
//                 mem_wb_pc_reg <= mem_pc;
//                 mem_wb_decoded_inst_reg <= mem_wb_decoded_inst_in;
//             end
//         end
//     end

//     // Assign Outputs
//     assign out_mem_wb_result = mem_wb_result_reg;
//     assign out_mem_wb_mem_read_data = mem_wb_mem_read_data_reg;  // Memory Read Data Output
//     assign out_mem_wb_instruction = mem_wb_instruction_reg;
//     assign out_mem_wb_reg_write    = mem_wb_reg_write_reg;

//     assign out_mem_wb_pc = mem_wb_pc_reg;
//     assign out_mem_wb_decoded_inst = mem_wb_decoded_inst_reg;

// endmodule
// iõi

