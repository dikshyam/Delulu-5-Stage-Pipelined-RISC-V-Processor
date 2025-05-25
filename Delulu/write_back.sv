`include "control_signals_struct.svh"
`include "enums.sv"

module write_back (
input  logic clk,
input  logic reset,
input  logic enable,
output logic complete,

input  logic [63:0] mem_load_data,
input  logic [63:0] alu_result,
input  decoder_output control_signals,
input  logic [63:0] registers [31:0],

output logic [4:0]  regWriteAddr,
output logic [63:0] regWriteData,
output logic        regWriteEn,
input logic regWriteDone,
output logic [4:0]  regClearAddr,
input logic enable_logging


);

// ECALL state
logic ecall_done;
logic [2:0] ecall_counter;
logic ecall_active;
logic [63:0] ecall_data_out, a2;


always_ff @(posedge clk) begin
    if (reset) begin
        ecall_done <= 0;
        ecall_active <= 0;
        // ecall_data_out <= 0;
    end else if (enable && control_signals.is_ecall) begin
        ecall_active <= 1;
        if (!ecall_done) begin
            // ecall_active <= 1;

            do_ecall(
                registers[17], registers[10], registers[11], registers[12],
                registers[13], registers[14], registers[15], registers[16],
                ecall_data_out
            );
            ecall_done <= 1;
            // DEBUG PRINT
            // $display("[WB] ECALL triggered — PC=%h", control_signals.pc);
            // $display("[WB] ECALL arguments:");
            // $display("  a7(x17) = %0d", registers[17]);
            // $display("  a0(x10) = %0d", registers[10]);
            // $display("  a1(x11) = %0d", registers[11]);
            // $display("  a2(x12) = %0d", registers[12]);
            // $display("  a3(x13) = %0d", registers[13]);
            // $display("  a4(x14) = %0d", registers[14]);
            // $display("  a5(x15) = %0d", registers[15]);
            // $display("  a6(x16) = %0d", registers[16]);
            // $display("[WB] ECALL result (to a0): 0x%0h", ecall_data_out);
            
        end else begin
            ecall_active <= 0;
        end
    end else begin
        ecall_done <= 0;
    end
end


always_comb begin
    if (reset) begin
    // Defaults
        regWriteAddr = 5'd0;
        regWriteData = 64'd0;
        regWriteEn   = 1'b0;
        complete     = 1'b0;
        
    end
    
    else if (enable) begin
        // NOP Handling
        if (control_signals.instruction == 32'b0) begin
            regWriteAddr = 5'd0;
            regWriteData = 64'd0;
            regWriteEn   = 1'b0;
            complete     = 1'b1;
            // $display("[WB] NOP detected. No writeback performed.");
        end

        // Regular instruction
        else if (!regWriteDone) begin
            
            case (control_signals.op_code)

                OP_STORE, OP_BRANCH, OP_MISC_MEM: begin
                    regWriteAddr = 5'b0;
                    regWriteData = 64'b0;
                    regWriteEn   = 1;

                    // register_write_data = 64'b0;
                    // register_write_addr = 5'b0;
                    // register_write_enable = 1;
                    // $display("[WB SKIP] Store/Branch/Fence | PC=%h", control_signals.pc);
                end

                OP_LOAD: begin
                    regWriteAddr = control_signals.rd;
                    regWriteData = mem_load_data;
                    regWriteEn   = 1;
                    // $display("[WB] LOAD | x%0d <= %h | PC=%h", regWriteAddr, regWriteData, control_signals.pc);
                end

                OP_OP, OP_OP_32, OP_OP_IMM, OP_IMM_32, OP_LUI, OP_AUIPC: begin
                    regWriteAddr = control_signals.rd;
                    regWriteData = alu_result;
                    regWriteEn   = 1;
                    // $display("[WB] ALU | x%0d <= %h | PC=%h", regWriteAddr, regWriteData, control_signals.pc);
                    if (control_signals.alu_width_32) begin
                        if (regWriteData[63:32] !== {32{regWriteData[31]}}) begin
                            // $display("ERROR: ALU 32-bit result not properly sign-extended! PC=%h", control_signals.pc);
                            // $finish;
                        end
                    end
                
                    // $display("[WB] ALU | x%0d <= %h | PC=%h", regWriteAddr, regWriteData, control_signals.pc);
                
                end

                OP_JAL, OP_JALR: begin
                    regWriteAddr = control_signals.rd;
                    regWriteData = alu_result;
                    regWriteEn   = (regWriteAddr != 5'd0);
                    // $display("[WB] JUMP | x%0d <= %h | PC=%h", regWriteAddr, regWriteData, control_signals.pc);
                end

                OP_SYSTEM: begin
                    if (control_signals.is_ecall) begin  // ECALL
                        if (ecall_done) begin
                            regWriteAddr = control_signals.rd;
                            regWriteData = ecall_data_out;
                            regWriteEn   = 1;
                            // if (ecall_data_out==24) begin

                            //     $finish;
                            // end
                            // $display("[WB] ECALL DONE | x%0d <= %h | PC=%h", regWriteAddr, regWriteData, control_signals.pc);
                        end else begin
                            regWriteEn = 0;
                            // $display("[WB] ECALL WAIT | Awaiting completion. PC=%h", control_signals.pc);
                        end
                    end else begin
                        // CSR write (dummy)
                        regWriteAddr = control_signals.rd;
                        regWriteData = 64'd0;
                        regWriteEn   = 1;
                        // $display("[WB] SYSTEM | x%0d <= 0 | PC=%h", regWriteAddr, control_signals.pc);
                    end
                end

                default: begin
                    regWriteEn = 0;
                    // $display("[WB SKIP] Unknown Opcode %b | PC=%h", control_signals.op_code, control_signals.pc);
                end

            endcase
        end else begin
            regWriteEn = 0;
            complete = 1;
            regClearAddr = regWriteAddr;
        end 
    end else begin
        complete = 0;
    end




        // // Complete if ECALL is done or it's not an ECALL
        // if ((control_signals.instruction == 8'd57 && ecall_done) ||
        //     (control_signals.instruction != 8'd57)) begin
        //     complete = 1;
        // end
end

// Register update tracking data structure
typedef struct packed {
    logic [63:0] timestamp;      // Time of update
    logic [63:0] pc;             // PC of instruction causing the update
    logic [31:0] instruction;    // The instruction that caused the update
    logic [4:0]  rd;             // Destination register being updated
    logic [63:0] prev_value;     // Previous register value
    logic [63:0] new_value;      // New register value
    logic [2:0]  update_type;    // 0=ALU, 1=MEM_LOAD, 2=ECALL, 3=JAL/JALR
} reg_update_t;

// Configuration for register update logging
parameter REG_UPDATE_LOG_SIZE = 1024;  // Size of circular buffer
reg_update_t reg_update_log [REG_UPDATE_LOG_SIZE-1:0];
logic [$clog2(REG_UPDATE_LOG_SIZE)-1:0] reg_update_ptr;

// Last instruction that modified each register
reg_update_t reg_history [32];  // One entry per register (x0-x31)

// File handle for register update log
integer reg_logfile;

// Initialize logging (add to your initial block)
initial begin
    // Open log file for writing
    reg_logfile = $fopen("/home/dimohanty/CPU/logs/register_updates.log", "w");
    if (!reg_logfile) begin
        $display("[WB] ERROR: Failed to open register update log file");
    end else begin
        $fwrite(reg_logfile, "TIME,PC,INSTRUCTION,REG_DEST,PREV_VALUE,NEW_VALUE,UPDATE_TYPE\n");
        // $display("[WB] Register update logging enabled to register_updates.log");
    end
    
    // Initialize log pointer and history
    reg_update_ptr = 0;
    for (int i = 0; i < 32; i++) begin
        reg_history[i].timestamp = 0;
        reg_history[i].pc = 0;
        reg_history[i].instruction = 0;
        reg_history[i].rd = i;
        reg_history[i].prev_value = 0;
        reg_history[i].new_value = 0;
        reg_history[i].update_type = 0;
    end
end

// Add this to your write_back module's always_ff block to log register updates
always_ff @(posedge clk) begin
    if (reset) begin
        reg_update_ptr <= 0;
    end else if (regWriteEn && regWriteAddr != 5'b0 && enable_logging) begin // Don't log writes to x0
        // Record the transaction in the log
        reg_update_log[reg_update_ptr].timestamp = $time;
        reg_update_log[reg_update_ptr].pc = control_signals.pc;
        reg_update_log[reg_update_ptr].instruction = control_signals.instruction;
        reg_update_log[reg_update_ptr].rd = regWriteAddr;
        reg_update_log[reg_update_ptr].prev_value = registers[regWriteAddr];
        reg_update_log[reg_update_ptr].new_value = regWriteData;
        
        // Determine update type based on control signals
        if (control_signals.op_code == OP_LOAD) begin
            reg_update_log[reg_update_ptr].update_type = 3'd1; // MEM_LOAD
        end else if (control_signals.is_ecall) begin
            reg_update_log[reg_update_ptr].update_type = 3'd2; // ECALL
        end else if (control_signals.op_code == OP_JAL || control_signals.op_code == OP_JALR) begin
            reg_update_log[reg_update_ptr].update_type = 3'd3; // JAL/JALR
        end else begin
            reg_update_log[reg_update_ptr].update_type = 3'd0; // ALU
        end
        
        // Update the register history
        reg_history[regWriteAddr] <= reg_update_log[reg_update_ptr];
        
        // Write to log file
        if (reg_logfile) begin
            $fwrite(reg_logfile, "%0d,", $time);
            $fwrite(reg_logfile, "%h,", control_signals.pc);
            $fwrite(reg_logfile, "%h,", control_signals.instruction);
            $fwrite(reg_logfile, "x%0d,", regWriteAddr);
            $fwrite(reg_logfile, "%h,", registers[regWriteAddr]);
            $fwrite(reg_logfile, "%h,", regWriteData);
            
            // Convert update type to string for better readability
            case (reg_update_log[reg_update_ptr].update_type)
                3'd0: $fwrite(reg_logfile, "ALU\n");
                3'd1: $fwrite(reg_logfile, "LOAD\n");
                3'd2: $fwrite(reg_logfile, "ECALL\n");
                3'd3: $fwrite(reg_logfile, "JUMP\n");
                default: $fwrite(reg_logfile, "UNKNOWN\n");
            endcase
        end
        
        // Increment pointer (circular buffer)
        reg_update_ptr <= (reg_update_ptr == REG_UPDATE_LOG_SIZE-1) ? 0 : reg_update_ptr + 1;
        
        // Optional console debug for important registers (a0, sp, etc.)
        // if (regWriteAddr == 5'd2 || regWriteAddr == 5'd10) begin // sp, a0
        //     $display("[REG_UPDATE] x%0d: %h → %h by PC=%h Instr=%h Type=%s", 
        //             regWriteAddr, registers[regWriteAddr], regWriteData, 
        //             control_signals.pc, control_signals.instruction,
        //             reg_update_log[reg_update_ptr].update_type == 0 ? "ALU" :
        //             reg_update_log[reg_update_ptr].update_type == 1 ? "LOAD" :
        //             reg_update_log[reg_update_ptr].update_type == 2 ? "ECALL" :
        //             "JUMP");
        // end
    end
end

// Add this to your final block to close the file at simulation end
final begin
    if (reg_logfile) begin
        $fclose(reg_logfile);
        // $display("[WB] Register update log file closed");
    end
end

endmodule
