`include "Sysbus.defs"
`include "enums.sv"
`include "decoder.sv"
`include "execute.sv"
`include "pipeline_registers.sv"
`include "reg_file.sv"
`include "fetch.sv"
`include "memory.sv"
`include "arbiter.sv"

/* verilator lint_off UNOPTFLAT */
// // include enums, decoder, alu, regfile, pipe_reg, hazard, memory_system, mem_stage, privilege
// Summary of Pipeline Stages
// Fetch →
// IF/ID Pipeline Register →
// Decode →
// ID/EX Pipeline Register →
// Execute →
// EX/MEM Pipeline Register →
// Memory →
// MEM/WB Pipeline Register →
// Write-Back 
// Instruction Cache - Fetch
// Data Cache - Memory (Load & Store)

module top
#(
ID_WIDTH = 13,
ADDR_WIDTH = 64,
DATA_WIDTH = 64,
STRB_WIDTH = DATA_WIDTH / 8
)
(
input  clk,
    reset,
    hz32768timer,

// 64-bit addresses of the program entry point and initial stack pointer
input  [63:0] entry,
input  [63:0] stackptr,
input  [63:0] satp,

// interface to connect to the bus
output  wire [ID_WIDTH-1:0]    m_axi_awid,
// aw: write address
output  wire [ADDR_WIDTH-1:0]  m_axi_awaddr,
output  wire [7:0]             m_axi_awlen,
output  wire [2:0]             m_axi_awsize,
output  wire [1:0]             m_axi_awburst,
output  wire                   m_axi_awlock,
output  wire [3:0]             m_axi_awcache,
output  wire [2:0]             m_axi_awprot,
output  wire                   m_axi_awvalid,
input   wire                   m_axi_awready,
// w: write data
output  wire [DATA_WIDTH-1:0]  m_axi_wdata,
output  wire [STRB_WIDTH-1:0]  m_axi_wstrb,
output  wire                   m_axi_wlast,
output  wire                   m_axi_wvalid,
input   wire                   m_axi_wready,
// b: write response(signal)
input   wire [ID_WIDTH-1:0]    m_axi_bid,
input   wire [1:0]             m_axi_bresp,
input   wire                   m_axi_bvalid,
output  wire                   m_axi_bready,
// ar: read address
output  wire [ID_WIDTH-1:0]    m_axi_arid,
output  wire [ADDR_WIDTH-1:0]  m_axi_araddr,
output  wire [7:0]             m_axi_arlen,
output  wire [2:0]             m_axi_arsize,
output  wire [1:0]             m_axi_arburst,
output  wire                   m_axi_arlock,
output  wire [3:0]             m_axi_arcache,
output  wire [2:0]             m_axi_arprot,
output  wire                   m_axi_arvalid,
input   wire                   m_axi_arready,
// r: read data
input   wire [ID_WIDTH-1:0]    m_axi_rid,
input   wire [DATA_WIDTH-1:0]  m_axi_rdata,
input   wire [1:0]             m_axi_rresp,
input   wire                   m_axi_rlast,
input   wire                   m_axi_rvalid,
output  wire                   m_axi_rready,

input   wire                   m_axi_acvalid,
output  wire                   m_axi_acready,
input   wire [ADDR_WIDTH-1:0]  m_axi_acaddr,
input   wire [3:0]             m_axi_acsnoop
);


// =============================== Arbiter ===============================

// Inputs to arbiter (logic signals used as conditions)
logic icache_request;
logic dcache_request;
logic icache_in_flight;
logic dcache_in_flight;

// Outputs from arbiter (grants)
logic grant_icache;
logic grant_dcache;

// FOR LOGGING
logic enable_log;
assign enable_log = 0;

// always_ff @(posedge clk) begin
//     $display("[TOP ARBITER DEBUG @ %0t] clk=%b | icache_req=%b dcache_req=%b => icache_grant=%b dcache_grant=%b",
//             $time, clk, icache_request, dcache_request, grant_icache, grant_dcache);
// end

cache_arbiter arbiter (
    .clk            (clk),
    .reset          (reset),
    // .icache_req     (icache_request && !icache_in_flight),
    // .dcache_req     (dcache_request && !dcache_in_flight),
    .icache_req(icache_request && !icache_in_flight && !dcache_in_flight),
    .dcache_req(dcache_request && !icache_in_flight && !dcache_in_flight),

    // .bus_idle       (bus_idle),
    // .ar_hshake      (ar_hshake),
    // .rlast_hshake   (rlast_hshake),
    .icache_grant   (grant_icache),
    .dcache_grant   (grant_dcache)
);

// =============================== Arbiter END ===============================


// logic [63:0] f_pc;           // Program Counter
// logic [31:0] f_instruction;  // Fetched instruction
// logic [31:0] current_instruction, last_instruction;
// logic f_stall;               // Fetch stall signal
// logic done_signal, last_instruction_signal;
// logic [63:0] done_pc;
// logic [31:0] done_instruction;
// logic flush_pipeline_initiate, flush_pipeline_complete;

// logic icache_request, dcache_request;

// FLUSHING LOGIC

logic flushing;
logic [1:0] flush_state;
localparam FLUSH_IDLE = 2'd0,
        FLUSH_WAIT = 2'd1,
        FLUSH_DONE = 2'd2;

// always_ff @(posedge clk ) begin
//     if (reset) begin
//         flush_state              <= FLUSH_IDLE;
//         flushing                 <= 0;
//         flush_pipeline_complete  <= 0;
//         fetch_stage_enable       <= 1;
//         decode_stage_enable      <= 1;
//         execute_stage_enable     <= 1;
//         upstream_stall           <= 0;
//     end else begin
//         case (flush_state)

//             FLUSH_IDLE: begin
//                 if (flush_pipeline_initiate) begin
//                     fetch_stage_enable       <= 0;
//                     decode_stage_enable      <= 0;
//                     execute_stage_enable     <= 0;
//                     // upstream_stall           <= 1;
//                     flushing                 <= 1;
//                     flush_pipeline_complete  <= 0;
//                     flush_state              <= FLUSH_WAIT;
//                     // out_id_ex_rd_data <= 0;

//                 end
//             end

//             FLUSH_WAIT: begin
//                 // One cycle delay or wait for confirm
//                 flush_pipeline_complete  <= 1;
//                 flush_state              <= FLUSH_DONE;
//             end

//             FLUSH_DONE: begin
//                 fetch_stage_enable       <= 1;
//                 decode_stage_enable      <= 1;
//                 execute_stage_enable     <= 1;
//                 flush_pipeline_complete  <= 0;
//                 flushing                 <= 0;
//                 upstream_stall           <= 0;
//                 flush_state              <= FLUSH_IDLE;
//                 flush_pipeline_initiate <= 0;
//             end

//         endcase
//     end
// end
                


// =================== FETCH BLOCK START =======================

// ---------------------------
// FETCH STAGE REGISTERS
// ---------------------------

// --- Control signals ---
// logic fetch_stage_enable;
// logic [63:0] fetch_pc_input;
// logic [63:0] jump_or_branch_address;
// logic jump_or_branch_mux;
// logic fetch_stage_complete;

// --- Fetch outputs to IF/ID pipeline ---
// logic [31:0] if_id_instruction;
// logic [63:0] if_id_pc;
// logic if_id_status;

// --- ECALL support ---
logic ecall_req_received;

logic stall_top_snoop_in_progress;
logic upstream_stall;

// --- Cache control ---
// logic icache_request;
// logic icache_in_flight;


// Instantiate Fetch stage
Fetch fetch_stage (
    .clk(clk),
    .reset(reset),
    .fetch_stage_enable(fetch_stage_enable),
    .in_fetch_pc(fetch_pc_input),
    .jump_or_branch_address(jump_or_branch_address),
    .jump_or_branch_mux(jump_or_branch_mux),
    .if_id_valid(if_id_status),

    .upstream_disable(upstream_stall),

    .out_fetch_instruction(if_id_instruction),
    .out_fetch_pc(if_id_pc),
    .fetch_stage_complete(fetch_stage_complete),

    // AXI signals
    .m_axi_arready(m_axi_arready),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_rready(m_axi_rready),

    .ecall_detected(ecall_req_received),
    .m_axi_icache_request(icache_request),
    .icache_in_flight(icache_in_flight),
    .arbiter_icache_grant(grant_icache),
    .wb_inst_ecall(wb_inst_ecall)
    // .last_instruction(done_instruction),
    // .last_instruction_pc(last_instruction_pc),
    // .last_instruction_signal(done_signal)


// Arbiter-related output
// .icache_status(icache_status)

);



// =================== FETCH BLOCK END =======================

// ==================== Pipeline Registers for Fetch/Decode Stage Start ====================


// --- IF/ID pipeline outputs ---
logic [31:0] out_if_id_instruction;
logic [63:0] out_if_id_pc;
logic if_id_status;

// --- Inputs from Fetch stage ---
logic [31:0] if_id_instruction;
logic [63:0] if_id_pc;
logic fetch_stage_complete;

// --- Fetch-related control ---
logic fetch_stage_enable;
logic [63:0] fetch_pc_input;
logic jump_or_branch_mux;
logic [63:0] jump_or_branch_address;

// --- ECALL control ---
// logic ecall_req_received;

// --- Upstream stall + reset control ---
// logic upstream_stall;
logic jump_flush_initiate, jump_flush_initiate_clk1, jump_flush_initiate_clk2;
logic flush_pipeline_initiate;


always_ff @(posedge clk) begin
    if (reset) begin
        out_if_id_instruction <= 32'b0;
        out_if_id_pc          <= 64'b0;
        fetch_pc_input        <= entry;
        jump_or_branch_address <= 64'b0;
        jump_or_branch_mux    <= 1'b0;
        fetch_stage_enable    <= 1'b1;
    end else begin
        if (!fetch_stage_enable) begin
            if (upstream_stall) begin
                out_if_id_instruction <= 32'b0;
                out_if_id_pc          <= 64'b0;
                if_id_status           <= 1'b0;
                jump_flush_initiate_clk1      <= 1'b1;
                jump_flush_initiate_clk2      <= 1'b0;

                jump_or_branch_mux    <= 1'b0;
                
                // if (jump_flush_initiate_clk1 && !icache_in_flight) begin
                //     jump_flush_initiate_clk1 <= 0;
                //     jump_flush_initiate_clk2 <= 1;
                // end

                if (jump_flush_initiate_clk1 && !icache_in_flight) begin
                    fetch_stage_enable <= 1'b1;
                    decode_stage_enable      <= 1'b1;
                    execute_stage_enable     <= 1'b1;
                    // memory_stage_enable      <= 1'b1;
                    jump_flush_initiate_clk2   <= 1'b0;
                    jump_flush_initiate_clk1 <= 0;
                    upstream_stall     <= 1'b0;
                end
            end
        end else begin
            if (fetch_stage_complete && !ecall_req_received) begin
                out_if_id_instruction <= if_id_instruction;
                out_if_id_pc          <= if_id_pc;
                if_id_status           <= 1'b1; 
                
                if (!ecall_req_received && !ex_mem_control_signals.jump_signal) begin
                    fetch_pc_input <= fetch_pc_input + 4;
                    // if_id_status           <= 0;
                end
            end else if (fetch_stage_complete && ecall_req_received) begin
                fetch_stage_enable <= 1'b0;
                // fetch_module_enable <= 0;
                
            end
        end
    end
end

// ==================== Pipeline Registers for Fetch/Decode Stage END ====================

// always_ff @(posedge clk) begin
//     if (reset) begin
//         $display("[IF/ID RESET] Pipeline reset at clk=%0t", $time);
//     end else if (if_id_status) begin
//         $display("[DEBUG IF/ID] @%0t:", $time);
//         $display("  - PC          : %h", out_if_id_pc);
//         $display("  - Instruction : %h", out_if_id_instruction);
//     end
// end


// =================== REG FILE ===================

// --- Inputs to register file ---

// --- Read port (from decode stage / ID/EX) ---
logic [63:0] rs1_data;
logic [63:0] rs2_data;

// --- Writeback stage signals ---
logic reg_write_complete;

// --- Hazard detection ---
logic [4:0] reg_clear_addr;
logic raw_hazard;

// --- Debugging ---
logic [63:0] rf_regs [31:0];

register_file rf_inst (
    .clk(clk),
    .reset(reset),
    .stackptr(stackptr),

    // Reads (from decoder)
    .rs1_addr(id_ex_rs1_addr),
    .rs2_addr(id_ex_rs2_addr),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),

    // Writeback (from WB stage)
    .reg_write_en(wb_reg_wr_en),
    .rd_addr(wb_reg_update_addr),
    .rd_data(wb_reg_update_data),
    .reg_write_complete(reg_write_complete),

    // RAW hazard tracking
    .mark_busy_addr(out_id_ex_rd_data),         // In decode stage (UNUSED)
    .clear_busy_addr(wb_reg_clear_addr),          // In case of jumps / branches (UNUSED)
    .raw_hazard(raw_hazard), // (UNUSED) - Forwarding logic in place

    // Debug
    .registers(rf_regs),
    .enable_logging(enable_log)
);
// =================== REG FILE END ===================

// =================== DECODE STAGE START =========================
logic [31:0] in_id_ex_instruction;     // Instruction input from IF/ID pipeline
logic [63:0] in_id_ex_pc;              // Corresponding PC value


// Register addresses extracted during decode
logic [4:0] id_ex_rs1_addr;
logic [4:0] id_ex_rs2_addr;
logic [4:0] rd_data;                   // Destination register address

// Decoded control struct
decoder_output in_decoded_inst;       // Assuming this typedef is already included

// removed flush logic from modules / handling directly in top
always_comb begin
    if (!decode_stage_enable) begin
        if (upstream_stall) begin
                in_decoded_inst = '0;
                rd_data = 0;
        end
    end
end

// Instantiate Decoder
Decoder decode_inst (
    .clk(clk),
    .reset(reset),
    .inst(in_id_ex_instruction),       // Instruction from IF/ID pipeline
    .decode_enable(decode_module_enable),       // Enable signal to start decode
    .pc(in_id_ex_pc),                  // Program Counter from IF/ID pipeline
    .rs1_data(id_ex_rs1_addr),
    .rs2_data(id_ex_rs2_addr),
    .rd(rd_data),
    .out(in_decoded_inst),                // Decoded instruction output
    .decode_complete(decode_stage_complete),  // Handshake output to signal decode completion
    .enable_logging(enable_log)
    // .curr_priv_mode(2'b00),         // Default privilege mode; can be connected later
    // .gen_trap(gen_trap),
    // .gen_trap_cause(gen_trap_cause),
    // .gen_trap_val(gen_trap_val)
);
// =================== DECODE STAGE END =========================




always_comb begin
    if (upstream_stall && !execute_stage_enable) begin
        // // Zero Decode stage outputs -- next cycle?
        ex_mem_control_signals     = '0;

        // Optionally zero ALU outputs or jump_pc if driven combinationally
        alu_result   = 64'b0;
        ex_mem_pc_plus_offset        = 64'b0;
    end else begin
        if (!execute_stage_complete) begin
            if (ecall_req_received && id_ex_status) begin
                rd_data = 0;
            end
        end
    end

// if (upstream_stall && !decode_stage_enable) begin
//     in_decoded_inst = '0;
// end
end



// =================== ID_EX PIPELINE REGISTER Start ===================

logic [4:0] out_id_ex_rs1_addr, out_id_ex_rs2_addr, out_id_ex_rd_data;
logic [63:0] out_id_ex_pc;
logic [31:0] out_id_ex_instruction;
logic [63:0] out_id_ex_rs1_data;
logic [63:0] out_id_ex_rs2_data;


// decoder_output in_decoded_inst;  // Output of decoder
decoder_output out_id_ex_decoded_inst;

logic decode_stage_complete;
logic decode_module_enable;
logic decode_stage_enable;
logic id_ex_raw_hazard;          // RAW hazard detection signal
logic id_ex_status;              // Latch signal from decode to execute

always_ff @(posedge clk) begin
    if (reset) begin
        // Reset all pipeline registers
        out_id_ex_pc <= 64'b0;
        out_id_ex_instruction <= 32'b0;
        out_id_ex_rs1_data <= 64'b0;
        out_id_ex_rs2_data <= 64'b0;
        // out_id_ex_immed <= 64'b0;
        out_id_ex_decoded_inst <= '0;
        decode_stage_enable <= 1;
        // decode_module_enable <= 0;
        // id_ex_status <= 0;
    end else if (!decode_stage_enable) begin
        if (upstream_stall) begin
                // Flush pipeline registers
                in_id_ex_pc <= 64'b0;
                in_id_ex_instruction <= 32'b0;

                out_id_ex_pc <= 64'b0;
                out_id_ex_instruction <= 32'b0;

                out_id_ex_rs1_data <= 64'b0;
                out_id_ex_rs2_data <= 64'b0;
                out_id_ex_rs1_addr <= 5'd0;
                out_id_ex_rs2_addr <= 5'd0; 
                out_id_ex_rd_data <= 0;
                // out_id_ex_immed <= 64'b0;
                out_id_ex_decoded_inst <= '0;
                // in_decoded_inst <= '0;
                // decode_stage_enable <= 0;
                decode_module_enable <= 0;
                id_ex_status <=0;
                // forward_registers <= 0;
            end 
        end else begin
            if (!decode_stage_complete) begin
                if (if_id_status) begin
                    in_id_ex_instruction <= out_if_id_instruction;
                    in_id_ex_pc <= out_if_id_pc;
                    // decode_stage_enable <= 1;
                    decode_module_enable <= 1;
                    if_id_status <= 0;
                end
            end else begin 
                // stall in decode
                if (in_id_ex_instruction == 32'b0) begin
                    // decode_stage_enable <= 0;
                    decode_module_enable <= 0;
                    id_ex_status <= 0;
                end else begin
                    if (!id_ex_raw_hazard) begin
                        out_id_ex_instruction <= in_id_ex_instruction;
                        out_id_ex_pc <= in_id_ex_pc;
                        out_id_ex_decoded_inst <= in_decoded_inst;
                        out_id_ex_rs1_addr <= id_ex_rs1_addr;
                        out_id_ex_rs2_addr <= id_ex_rs2_addr;
                        
                        if (!ecall_req_received) begin
                            out_id_ex_rs1_data <= rs1_data;
                            out_id_ex_rs2_data <= rs2_data;
                            out_id_ex_rd_data <= rd_data;
                        end
                
                        id_ex_status <= 1;
                        decode_module_enable <= 0;
                    end else begin
                        // $display("[DECODE STALL] RAW hazard — holding ID/EX pipeline regs");
                        // $display("[DEBUG ID/EX] PC=%h | Inst=%h | RegWrite=%b | ALU_OP=%s",
                        //         in_id_ex_pc, in_id_ex_instruction,
                        //         in_decoded_inst.reg_write, alu_op_to_string(in_decoded_inst.alu_op));
                    end
                end
            end
        end
            // Pass values to the pipeline register
            // out_id_ex_pc <= in_if_id_instruction;
            // out_id_ex_instruction <= in_id_ex_instruction;
            // out_id_ex_rs1_data <= in_id_ex_rs1_data;
            // out_id_ex_rs2_data <= in_id_ex_rs2_data;
            // out_id_ex_immed <= in_id_ex_immed;
            // out_id_ex_decoded_inst <= in_id_ex_decoded_inst;
            // if_id_status <= 0;
end



// =================== ID_EX PIPELINE REGISTER END ===================

// always_ff @(posedge clk) begin
//     if (reset) begin
//         $display("[ID/EX RESET] Pipeline reset at clk=%0t", $time);
//     end else if (id_ex_status) begin
//         $display("[DEBUG ID/EX] @%0t:", $time);
//         $display("  - PC          : %h", out_id_ex_pc);
//         $display("  - Instruction : %h", out_id_ex_instruction);
//         $display("  - RS1 Data    : %h", out_id_ex_rs1_data);
//         $display("  - RS2 Data    : %h", out_id_ex_rs2_data);

//         // Decoded control signals
//         $display("  - Decoded Instruction:");
//         $display("      - rs1            : x%0d", out_id_ex_decoded_inst.rs1);
//         $display("      - rs2            : x%0d", out_id_ex_decoded_inst.rs2);
//         $display("      - rd             : x%0d", out_id_ex_decoded_inst.rd);
//         $display("      - Opcode         : %0d", out_id_ex_decoded_inst.op_code);
//         $display("      - ALU OP         : %0d", out_id_ex_decoded_inst.alu_op);
//         $display("      - Reg Write      : %b", out_id_ex_decoded_inst.reg_write);
//         $display("      - Mem Read       : %b", out_id_ex_decoded_inst.mem_read);
//         $display("      - Mem Write      : %b", out_id_ex_decoded_inst.mem_write);
//         $display("      - Mem To Reg     : %b", out_id_ex_decoded_inst.mem_to_reg);
//         $display("      - Jump Signal    : %b", out_id_ex_decoded_inst.jump_signal);
//         $display("      - Jump Absolute  : %b", out_id_ex_decoded_inst.jump_absolute);
//         $display("      - Immediate Value: %h", out_id_ex_decoded_inst.immed);
//         $display("      - Data Size      : %0d", out_id_ex_decoded_inst.data_size);
//         $display("      - ALU Width 32?  : %b", out_id_ex_decoded_inst.alu_width_32);
//         $display("      - Signed Type    : %b", out_id_ex_decoded_inst.signed_type);
//     end
// end


// =================== EXECUTE STAGE END ===================

// Inputs to Execute
// logic [31:0] in_ex_mem_instruction;
// logic [63:0] in_ex_mem_pc;
// logic [63:0] in_ex_mem_rs1_data, in_ex_mem_rs2_data;
// decoder_output in_ex_mem_control_signals;

// Outputs from Execute
logic [63:0] alu_result;
logic [63:0] ex_mem_pc_plus_offset;
decoder_output ex_mem_control_signals;

// logic execute_stage_complete;
// logic execute_stage_enable;     // Control from outside to EX pipeline (global)

// logic execute_module_enable;    // Used as execute_enable

Execute execute_stage (
    .clk                (clk),
    .reset              (reset),
    .execute_enable     (execute_module_enable),
    .instruction_current (in_ex_mem_instruction),
    .pc_current         (in_ex_mem_pc),
    .reg_a_contents     (in_ex_mem_rs1_data),
    .reg_b_contents     (in_ex_mem_rs2_data),
    .control_signals    (in_ex_mem_control_signals),
    .alu_data_out       (alu_result),//o/p
    .jump_pc    (ex_mem_pc_plus_offset), //o/p
    .control_signals_out(ex_mem_control_signals),//o/p
    .execute_done       (execute_stage_complete),
    .flush(flush_pipeline_initiate),
    .enable_logging(enable_log)
);




// =================== EXECUTE STAGE END ===================

// =================== FORWARDING LOGIC ===================


// Forwarded values
logic [63:0] out_id_ex_rs1_data_temp;
logic [63:0] out_id_ex_rs2_data_temp;

// Forwarding & hazard control
logic forward_registers;
// logic id_ex_raw_hazard;

// Source and destination register addresses (from ID/EX stage)
// logic [4:0] out_id_ex_rs1_addr;
// logic [4:0] out_id_ex_rs2_addr;

// always_comb begin
//     id_ex_raw_hazard      = 0;

//     // ---------------------------------
//     // Only update if EX hasn’t latched inputs
//     // ---------------------------------
//     if (!execute_module_enable  && id_ex_status) begin
//         // ---------------------------------
//         // Defaults (pass-through values)
//         // ---------------------------------
//         out_id_ex_rs1_data_temp = out_id_ex_rs1_data;
//         out_id_ex_rs2_data_temp = out_id_ex_rs2_data;
//         forward_registers       = 0;
        

        
//         // ---------------------------------
//         // RAW Hazard Detection: Load-Use
//         // ---------------------------------
//         if (in_mem_wb_control_signals.mem_to_reg &&
//             ((in_mem_wb_control_signals.rd == out_id_ex_rs1_addr && out_id_ex_rs1_addr != 0) ||
//             (in_mem_wb_control_signals.rd == out_id_ex_rs2_addr && out_id_ex_rs2_addr != 0))) begin
            
//             if (!memory_stage_complete &&
//                 !( (out_mem_wb_control_signals.rd == out_id_ex_rs1_addr && out_id_ex_rs1_addr != 0) ||
//                     (out_mem_wb_control_signals.rd == out_id_ex_rs2_addr && out_id_ex_rs2_addr != 0) )) begin
//                 // Still waiting for load to complete - STALL
//                 id_ex_raw_hazard = 1;
//                 // $display("[RAW STALL] Load-use hazard detected: rd = x%0d (load not yet completed)",
//                 //             in_mem_wb_control_signals.rd);
            
//             // end else begin
//             //     // Load data available (forwarded from MEM/WB) - NO STALL
//             //     id_ex_raw_hazard = 0;
//             //     // $display("[RAW FORWARD] Load completed and data ready for rs1/rs2 from rd = x%0d",
//             //     //             out_mem_wb_control_signals.rd);
//             // end
//         end else if (wb_reg_wr_en &&
//                 ((wb_reg_update_addr == out_id_ex_rs1_addr && out_id_ex_rs1_addr != 0) ||
//                 (wb_reg_update_addr == out_id_ex_rs2_addr && out_id_ex_rs2_addr != 0))) begin
//             // Register being updated in WB stage - stall until complete
//             if (!reg_write_complete) begin
//                 id_ex_raw_hazard = 1;
//             end
//         end
//     end

//         // // ---------------------------------
//         // // RAW Hazard Detection: Store buffer not complete
//         // // ---------------------------------
//         // else if (out_ex_mem_control_signals.mem_to_reg && !memory_stage_complete) begin
//         //     id_ex_raw_hazard = 1;
//         //     $display("[RAW STALL] Store hazard: write not complete");
//         // end

//         // ---------------------------------
//         // Forwarding Logic (only if no stall)
//         // ---------------------------------
//         if (!id_ex_raw_hazard) begin

//             // Forward RS1
//             if (out_id_ex_rs1_addr != 0) begin
//                 if (out_ex_mem_control_signals.reg_write &&
//                     out_ex_mem_control_signals.rd == out_id_ex_rs1_addr &&
//                     !out_ex_mem_control_signals.mem_to_reg) begin

//                     out_id_ex_rs1_data_temp = out_ex_mem_alu_result;
//                     forward_registers = 1;
//                     // $display("[RAW FORWARD] RS1 <- EX/MEM: x%0d (ALU RESULT) = 0x%0h ", out_id_ex_rs1_addr, out_ex_mem_alu_result);

//                 end else if (out_mem_wb_control_signals.mem_to_reg &&
//                             out_mem_wb_control_signals.rd == out_id_ex_rs1_addr) begin

//                     if (out_mem_wb_control_signals.mem_to_reg) begin
//                         out_id_ex_rs1_data_temp = out_mem_wb_loaded_data;
//                         // $display("[RAW FORWARD] RS1 <- MEM/WB: x%0d (LOADED DATA) = 0x%0h",
//                         //             out_id_ex_rs1_addr, out_mem_wb_loaded_data);
//                     end else begin
//                         out_id_ex_rs1_data_temp = out_mem_wb_alu_data;
//                         // $display("[RAW FORWARD] RS1 <- MEM/WB: x%0d (ALU RESULT) = 0x%0h",
//                         //             out_id_ex_rs1_addr, out_mem_wb_alu_data);
//                     end
//                     forward_registers = 1;
//                     // $display("[RAW FORWARD] RS1 <- MEM/WB: x%0d", out_id_ex_rs1_addr);
//                 end
//             end

//             // Forward RS2
//             if (out_id_ex_rs2_addr != 0) begin
//                 if (out_ex_mem_control_signals.reg_write &&
//                     out_ex_mem_control_signals.rd == out_id_ex_rs2_addr &&
//                     !out_ex_mem_control_signals.mem_to_reg) begin

//                     out_id_ex_rs2_data_temp = out_ex_mem_alu_result;
//                     forward_registers = 1;
//                     // $display("[RAW FORWARD] RS2 <- EX/MEM: x%0d (ALU RESULT) = 0x%0h",
//                     //         out_id_ex_rs2_addr, out_ex_mem_alu_result);

//                 end else if (out_mem_wb_control_signals.reg_write &&
//                             out_mem_wb_control_signals.rd == out_id_ex_rs2_addr) begin

//                     if (out_mem_wb_control_signals.mem_to_reg) begin
//                         out_id_ex_rs2_data_temp = out_mem_wb_loaded_data;
//                         // $display("[RAW FORWARD] RS2 <- MEM/WB: x%0d (LOADED DATA) = 0x%0h",
//                         //         out_id_ex_rs2_addr, out_mem_wb_loaded_data);
//                     end else begin
//                         out_id_ex_rs2_data_temp = out_mem_wb_alu_data;
//                         // $display("[RAW FORWARD] RS2 <- MEM/WB: x%0d (ALU RESULT) = 0x%0h",
//                         //         out_id_ex_rs2_addr, out_mem_wb_alu_data);
//                     end
//                     forward_registers = 1;
//                 end
//             end

//         end
//     end
// end

always_comb begin
    id_ex_raw_hazard = 0;

    // ---------------------------------
    // Only update if EX hasn't latched inputs
    // ---------------------------------
    if (!execute_module_enable && id_ex_status) begin
        // ---------------------------------
        // Defaults (pass-through values)
        // ---------------------------------
        out_id_ex_rs1_data_temp = out_id_ex_rs1_data;
        out_id_ex_rs2_data_temp = out_id_ex_rs2_data;
        forward_registers = 0;
        
        // ---------------------------------
        // RAW Hazard Detection: Load-Use
        // ---------------------------------
        if (in_mem_wb_control_signals.mem_to_reg &&
            ((in_mem_wb_control_signals.rd == out_id_ex_rs1_addr && out_id_ex_rs1_addr != 0) ||
            (in_mem_wb_control_signals.rd == out_id_ex_rs2_addr && out_id_ex_rs2_addr != 0))) begin
            
            if (!memory_stage_complete &&
                !((out_mem_wb_control_signals.rd == out_id_ex_rs1_addr && out_id_ex_rs1_addr != 0) ||
                  (out_mem_wb_control_signals.rd == out_id_ex_rs2_addr && out_id_ex_rs2_addr != 0))) begin
                // Still waiting for load to complete - STALL
                id_ex_raw_hazard = 1;
            end
        end 
        // Check for general register write in WB stage
        else if (wb_reg_wr_en &&
                ((wb_reg_update_addr == out_id_ex_rs1_addr && out_id_ex_rs1_addr != 0) ||
                (wb_reg_update_addr == out_id_ex_rs2_addr && out_id_ex_rs2_addr != 0))) begin
            // Register being updated in WB stage - stall until complete
            if (!reg_write_complete) begin
                id_ex_raw_hazard = 1;
            end
        end

        // ---------------------------------
        // Forwarding Logic (only if no stall)
        // ---------------------------------
        if (!id_ex_raw_hazard) begin
            // Forward RS1
            if (out_id_ex_rs1_addr != 0) begin
                // Forward from EX/MEM stage (ALU result)
                if (out_ex_mem_control_signals.reg_write &&
                    out_ex_mem_control_signals.rd == out_id_ex_rs1_addr &&
                    !out_ex_mem_control_signals.mem_to_reg) begin
                    out_id_ex_rs1_data_temp = out_ex_mem_alu_result;
                    forward_registers = 1;
                end 
                // Forward from MEM/WB stage (memory load or ALU result)
                else if (out_mem_wb_control_signals.reg_write &&
                         out_mem_wb_control_signals.rd == out_id_ex_rs1_addr) begin
                    if (out_mem_wb_control_signals.mem_to_reg) begin
                        out_id_ex_rs1_data_temp = out_mem_wb_loaded_data;
                    end else begin
                        out_id_ex_rs1_data_temp = out_mem_wb_alu_data;
                    end
                    forward_registers = 1;
                end
                // Check for forwarding from Writeback stage
                else if (wb_reg_wr_en && wb_reg_update_addr == out_id_ex_rs1_addr) begin
                    // Use the latest value from writeback
                    out_id_ex_rs1_data_temp = wb_reg_update_data; // Assuming this is the data being written
                    forward_registers = 1;
                end
            end

            // Forward RS2
            if (out_id_ex_rs2_addr != 0) begin
                // Forward from EX/MEM stage (ALU result)
                if (out_ex_mem_control_signals.reg_write &&
                    out_ex_mem_control_signals.rd == out_id_ex_rs2_addr &&
                    !out_ex_mem_control_signals.mem_to_reg) begin
                    out_id_ex_rs2_data_temp = out_ex_mem_alu_result;
                    forward_registers = 1;
                end 
                // Forward from MEM/WB stage (memory load or ALU result)
                else if (out_mem_wb_control_signals.reg_write &&
                         out_mem_wb_control_signals.rd == out_id_ex_rs2_addr) begin
                    if (out_mem_wb_control_signals.mem_to_reg) begin
                        out_id_ex_rs2_data_temp = out_mem_wb_loaded_data;
                    end else begin
                        out_id_ex_rs2_data_temp = out_mem_wb_alu_data;
                    end
                    forward_registers = 1;
                end
                // Check for forwarding from Writeback stage
                else if (wb_reg_wr_en && wb_reg_update_addr == out_id_ex_rs2_addr) begin
                    // Use the latest value from writeback
                    out_id_ex_rs2_data_temp = wb_reg_update_data;
                    forward_registers = 1;
                end
            end
        end
    end
end

// =================== FORWARDING LOGIC ===================



// =================== EX_MEM START ===================

// ALU and result data
logic [63:0] out_ex_mem_alu_result;
logic [63:0] out_ex_mem_pc_plus_offset;

// Instruction and PC
logic [31:0] in_ex_mem_instruction, out_ex_mem_instruction;
logic [63:0] in_ex_mem_pc, out_ex_mem_pc;

// Register data
logic [63:0] in_ex_mem_rs1_data, out_ex_mem_rs1_data;
logic [63:0] in_ex_mem_rs2_data, out_ex_mem_rs2_data;

// Register destination
logic [4:0]  in_ex_mem_rd, out_ex_mem_rd;

// Control signals (structured)
decoder_output in_ex_mem_control_signals;
decoder_output out_ex_mem_control_signals;
// decoder_output ex_mem_control_signals;


// Stage status flags
logic ex_mem_status;
logic execute_stage_complete;
logic execute_stage_enable;
logic execute_module_enable;  

always_ff @(posedge clk) begin
    if (reset) begin
        out_ex_mem_instruction      <= 32'b0;
        out_ex_mem_pc              <= 64'b0;
        out_ex_mem_pc_plus_offset  <= 64'b0;
        out_ex_mem_control_signals <= '0;
        out_ex_mem_alu_result      <= 64'b0;
        out_ex_mem_rs1_data        <= 64'b0;
        out_ex_mem_rs2_data        <= 64'b0;
        
        execute_stage_enable <= 1;
        ex_mem_status        <= 0;
    end else begin
        if (!execute_stage_enable) begin
            if (upstream_stall) begin
                // Flush inputs only
                in_ex_mem_instruction      <= 32'b0;
                in_ex_mem_pc              <= 64'b0;
                in_ex_mem_control_signals <= '0;
                in_ex_mem_rs1_data        <= 64'b0;
                in_ex_mem_rs2_data        <= 64'b0;

                execute_module_enable     <= 0;
            end
        end else begin
            // ===================================
            // Case 1: Load new instruction
            // ===================================
            if (!execute_stage_complete) begin
                if (id_ex_status && !id_ex_raw_hazard) begin
                    in_ex_mem_instruction      <= out_id_ex_instruction;
                    in_ex_mem_pc              <= out_id_ex_pc;
                    in_ex_mem_control_signals <= out_id_ex_decoded_inst;
                    in_ex_mem_rs1_data        <= out_id_ex_rs1_data_temp;
                    in_ex_mem_rs2_data        <= out_id_ex_rs2_data_temp;

                    execute_module_enable     <= 1;
                    id_ex_status              <= 0;
                end
            end
            // ===================================
            // Case 2: Execution is done — update EX/MEM outputs
            // ===================================
            else begin
                out_ex_mem_instruction      <= in_ex_mem_instruction;
                out_ex_mem_pc              <= in_ex_mem_pc;
                out_ex_mem_rs2_data        <= in_ex_mem_rs2_data;
                out_ex_mem_control_signals <= ex_mem_control_signals;
                out_ex_mem_alu_result      <= alu_result;
                out_ex_mem_pc_plus_offset <= ex_mem_control_signals.jump_signal ? ex_mem_pc_plus_offset : in_ex_mem_pc;

                // Handle branch/jump
                if (ex_mem_control_signals.jump_signal) begin

                    // Pipeline flush logic
                    jump_or_branch_mux     <= 1;
                    jump_or_branch_address <= ex_mem_pc_plus_offset;
                    fetch_pc_input         <= ex_mem_pc_plus_offset;

                    // Flush EX input pipeline
                    in_ex_mem_instruction      <= 0;
                    in_ex_mem_pc              <= 0;
                    in_ex_mem_control_signals <= '0;
                    in_ex_mem_rs1_data        <= 0;
                    in_ex_mem_rs2_data        <= 0;

                    fetch_stage_enable   <= 0;
                    decode_stage_enable  <= 0;
                    execute_stage_enable <= 0;
                    upstream_stall       <= 1;
                    // if out_fetch_instruction
                    // ecall_req_received <= 0; // clear ecall

                end else begin
                    // No jump — just proceed
                    // out_ex_mem_pc_plus_offset <= in_ex_mem_pc;

                    if (!ecall_req_received) begin
                        fetch_stage_enable   <= 0;
                        decode_stage_enable  <= 0;
                        execute_stage_enable <= 0;
                        upstream_stall       <= 0;
                    end
                end

                execute_module_enable <= 0;
                ex_mem_status         <= 1;
            end
        end
    end
end

// =================== EX_MEM END ===================


// =================== DEBUG LOGS ===================
// always_ff @(posedge clk) begin
//     if (reset) begin
//         $display("[EX/MEM RESET] Pipeline reset at clk=%0t", $time);
//     end else if (ex_mem_status) begin
//         $display("[DEBUG EX/MEM] @%0t:", $time);
//         $display("  - PC                : %h", out_ex_mem_pc);
//         $display("  - Instruction       : %h", out_ex_mem_control_signals.instruction);
//         $display("  - Opcode            : %0d", out_ex_mem_control_signals.op_code);
//         $display("  - ALU Result        : %h", out_ex_mem_alu_result);
//         $display("  - RS2 Data          : %h", out_ex_mem_rs2_data);
        
//         // Jump/Branch Specific
//         $display("  - Jump Taken        : %b", out_ex_mem_control_signals.jump_signal);
//         $display("  - Jump Target       : %h", ex_mem_pc_plus_offset);
        
//         $display("  - Decoded Instruction:");
//         $display("      - rs1           : x%0d", out_ex_mem_control_signals.rs1);
//         $display("      - rs2           : x%0d", out_ex_mem_control_signals.rs2);
//         $display("      - rd            : x%0d", out_ex_mem_control_signals.rd);
//         $display("      - ALU OP        : %d", out_ex_mem_control_signals.alu_op);
//         $display("      - Reg Write     : %b", out_ex_mem_control_signals.reg_write);
//         $display("      - Mem Write     : %b", out_ex_mem_control_signals.mem_write);
//         $display("      - Mem Read      : %b", out_ex_mem_control_signals.mem_read);
//         $display("      - Mem To Reg    : %b", out_ex_mem_control_signals.mem_to_reg);
//         $display("      - Write Register: x%0d", out_ex_mem_control_signals.rd);
//     end
// end


// =================== DEBUG LOGS ===================
// always_ff @(posedge clk) begin
//     $display("[DEBUG EX/MEM] @%0t: PC=%h, ALU_RESULT=%h, RD=%d, MEM_WRITE=%b, MEM_READ=%b, REG_WRITE=%b, MEM_TO_REG=%b", 
//             $time, out_ex_mem_pc, out_ex_mem_alu_result, out_ex_mem_rd, 
//             out_ex_mem_mem_write, out_ex_mem_mem_read, 
//             out_ex_mem_reg_write, out_ex_mem_mem_to_reg);
// end


// =================== Memory Stage ========================
// MEMORY STARTS
logic memory_stage_enable;
logic memory_stage_complete;
logic memory_ecall_clean;
logic memory_module_enable;

// Instruction and control signals
// logic [31:0] in_mem_wb_instruction;
// logic [31:0] out_mem_wb_instruction;
// decoder_output in_mem_wb_control_signals;
// decoder_output out_mem_wb_control_signals;

// Data passed between stages
logic [63:0] mem_wb_loaded_data;
logic [63:0] mem_wb_alu_data;
logic [63:0] ex_mem_pc_plus_I_offset_reg;
logic [63:0] ex_mem_alu_data;
logic [63:0] ex_mem_reg_b_data;

// D-cache signals
logic mem_clean_done;

memory memory_stage (
    .clk(clk),
    .reset(reset),

    // Core control
    .memory_enable(memory_module_enable),
    .pc(in_mem_wb_pc_plus_offset),
    .alu_data(in_mem_wb_alu_result),
    .reg_b_contents(in_mem_wb_rs2_data),
    .control_signals(in_mem_wb_control_signals),
    .mem_wb_status(mem_wb_status),
    .ecall_clean(memory_ecall_clean),

    // Arbiter & handshake
    .arbiter_dcache_grant(grant_dcache),
    .dcache_in_flight(dcache_in_flight),
    .m_axi_dcache_request(dcache_request),

    // Data outputs
    .loaded_data_out(mem_wb_loaded_data),
    .memory_done(memory_stage_complete),
    // .data_cache_reading(data_cache_reading),

    // AXI Read Interface
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arready(m_axi_arready),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rready(m_axi_rready),

    // AXI Write Interface
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wready(m_axi_wready),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bready(m_axi_bready),

    // Coherency / Snoop
    .m_axi_acvalid(m_axi_acvalid),
    .m_axi_acready(m_axi_acready),
    .m_axi_acaddr(m_axi_acaddr),
    .m_axi_acsnoop(m_axi_acsnoop),
    .snoop_stall(stall_top_snoop_in_progress),
    .enable_logging(enable_log)
);


// ======================== Memory Ends ========================



// =================== MEM/WB PIPELINE REGISTER ===================
                
                
// Stage enable/status
// logic memory_stage_enable;
// logic memory_module_enable;
// logic memory_stage_complete;
// logic memory_ecall_clean;

// Instruction and PC tracking
logic [31:0] in_mem_wb_instruction, out_mem_wb_instruction;
logic [63:0] in_mem_wb_pc, out_mem_wb_pc;
logic [63:0] in_mem_wb_pc_plus_offset;
logic [63:0] in_mem_wb_result, out_mem_wb_result;

// ALU and register data
logic [63:0] in_mem_wb_alu_result, out_mem_wb_alu_data;
logic [63:0] in_mem_wb_rs2_data, out_mem_wb_rs2_data;
logic [63:0] out_mem_wb_loaded_data;

// Control signals
decoder_output in_mem_wb_control_signals;
decoder_output out_mem_wb_control_signals;


always_ff @(posedge clk) begin
    if (reset) begin
        out_mem_wb_control_signals <= '0;
        out_mem_wb_loaded_data         <= 64'b0;
        out_mem_wb_alu_data            <= 64'b0;
        memory_stage_enable              <= 1'b1;
        memory_ecall_clean         <= 1'b0;
        // memory_module_enable <= 0;
    end else begin
        memory_ecall_clean <= 0;
        // memory_ecall_clean <= ecall_req_received; // no ecall clean needed 

        if (memory_stage_enable) begin
            if (!memory_stage_complete) begin
                if (ex_mem_status) begin
                    // memory_stage_enable              <= ex_mem_status;
                    memory_module_enable <= 1;
                    in_mem_wb_instruction <= out_ex_mem_instruction;
                    in_mem_wb_pc_plus_offset          <= out_ex_mem_pc_plus_offset;
                    in_mem_wb_alu_result            <= out_ex_mem_alu_result;
                    in_mem_wb_rs2_data          <= out_ex_mem_rs2_data;
                    in_mem_wb_control_signals <= out_ex_mem_control_signals;
                    ex_mem_status <= 0;
                    in_mem_wb_pc <= out_ex_mem_pc;

                end
            end else begin
                memory_module_enable <= 0;
                
                out_mem_wb_instruction <= in_mem_wb_instruction;
                // Clear memory access flags -- CHECK IF NEEDED
                in_mem_wb_control_signals.mem_read  <= 0;
                in_mem_wb_control_signals.mem_write <= 0;

                // Register pipeline outputs
                out_mem_wb_control_signals <= in_mem_wb_control_signals;
                out_mem_wb_loaded_data         <= (in_mem_wb_instruction == 32'b0) ? 64'b0 : mem_wb_loaded_data;
                out_mem_wb_alu_data            <= in_mem_wb_alu_result;
                out_mem_wb_rs2_data <= in_mem_wb_rs2_data;
                mem_wb_status           <= 1;
                out_mem_wb_pc <= in_mem_wb_pc;

                // Reactivate pipeline stages if not ecall
                if (!upstream_stall && (!ecall_req_received || !in_mem_wb_control_signals.is_ecall) && !dcache_in_flight) begin
                    fetch_stage_enable   <= 1;
                    decode_stage_enable  <= 1;
                    execute_stage_enable <= 1;
                    // decache_wait_disable <= 0;
                end
            end
        end
    end
end

// =================== MEM/WB PIPELINE REGISTER ===================


// =================== DEBUG LOGS ===================
// always_ff @(posedge clk) begin
//     if (reset) begin
//         $display("[MEM/WB RESET] Pipeline reset at clk=%0t", $time);
//     end else if (out_mem_wb_control_signals.reg_write || out_mem_wb_control_signals.mem_write) begin
//         $display("[MEM/WB DEBUG] clk=%0t", $time);
//         $display("  - PC                : %h", out_mem_wb_control_signals.pc);
//         $display("  - Instruction       : %h", out_mem_wb_control_signals.instruction);
//         $display("  - ALU Result        : %h", out_mem_wb_alu_data);
//         $display("  - Loaded Data        : %h", out_mem_wb_loaded_data);
//         $display("  - RS2 Data          : %h", out_mem_wb_rs2_data);
//         $display("  - Write Register    : x%0d", out_mem_wb_control_signals.rd);
//         $display("  - Reg Write Enable  : %b", out_mem_wb_control_signals.reg_write);
//         $display("  - Mem To Reg        : %b", out_mem_wb_control_signals.mem_to_reg);
//     end
// end

// Writeback Stage Logic
// =================== MEM/WB PIPELINE REGISTER ===================
logic wb_stage_enable;
logic wb_stage_complete;
logic wb_module_enable;

// Write-back data
logic [63:0] wb_mem_loaded_data;
logic [63:0] wb_alu_data;
logic [63:0] wb_reg_update_data;

// Register writeback interface
logic [4:0] wb_reg_update_addr;
logic [4:0] wb_reg_clear_addr;
logic [4:0] out_mem_wb_rd;      // From MEM/WB stage
// logic [4:0] reg_clear_addr;     // Final signal to reg file
logic wb_reg_wr_en;
// logic reg_write_complete;

// Decoder control signals and instruction tracking
decoder_output wb_control_signals;
logic [31:0] in_wb_instruction;
logic [31:0] out_wb_instruction;


write_back wb_stage(
    .clk(clk),
    .reset(reset),
    .enable(wb_module_enable),
    .complete(wb_stage_complete),
    .mem_load_data(wb_mem_loaded_data),
    .alu_result(wb_alu_data),
    .control_signals(wb_control_signals),

    .registers(rf_regs),
    .regWriteAddr(wb_reg_update_addr),
    .regWriteData(wb_reg_update_data),
    .regWriteEn(wb_reg_wr_en),
    .regWriteDone(reg_write_complete),
    .regClearAddr(wb_reg_clear_addr),
    .enable_logging(enable_log)

);

logic wb_inst_ecall;
logic ecall_completed;  // Signal from WB stage that ECALL is done
always_ff @(posedge clk) begin
    if (reset) begin
        // Reset outputs and controls
        wb_stage_enable <= 1;
        wb_mem_loaded_data          <= 64'b0;
        // wb_destReg              <= 64'b0;
        wb_alu_data <= 64'b0;
        total_ecall_counter = 0;
        ecall_completed<=0;
        // wb_module_enable <= 0;
        // mem_wb_status           <= 1'b0;

        // wb_reg_wr_en <= 0;
        // wb_out.instruction     <= 32'b0;
        // wb_out.rs2_data        <= 64'b0;
        // wb_out.rd              <= 5'd0;
        // wb_out.reg_write       <= 0;
        // wb_out.mem_to_reg      <= 0;
        // wb_out.mem_read        <= 0;
        // wb_out.is_store        <= 0;
    end else begin
        if (wb_stage_enable) begin
            if (!wb_stage_complete) begin
                if (mem_wb_status) begin
                    wb_mem_loaded_data       <= out_mem_wb_loaded_data;
                    wb_alu_data          <= out_mem_wb_alu_data;
                    wb_control_signals <= out_mem_wb_control_signals;
                    wb_module_enable <= mem_wb_status;
                    out_mem_wb_rd <= wb_reg_clear_addr;
                    in_wb_instruction <= out_mem_wb_instruction;
                    mem_wb_status <= 0;
                end
            end else begin
                if (wb_control_signals.is_ecall) begin
                    total_ecall_counter = total_ecall_counter + 1;
                    
                    out_ex_mem_control_signals <= 0;
                    out_mem_wb_control_signals <= 0;
                    if (!stall_top_snoop_in_progress) begin
                        ecall_completed <= 1;
                        wb_module_enable <= 0;

                    end
                end else begin
                    wb_module_enable <= 0;
                end
            end
            
        end
    end
end


// ECALL Flush State Machine
logic [1:0] ecall_flush_state;
logic [1:0] ecall_flush_counter;

localparam ECALL_FLUSH_IDLE = 2'b00;
localparam ECALL_FLUSH_WAIT = 2'b01; 
localparam ECALL_FLUSH_RESTART = 2'b10;

always_ff @(posedge clk) begin
    if (reset) begin
        ecall_flush_state <= ECALL_FLUSH_IDLE;
        ecall_flush_counter <= 2'b00;
        fetch_stage_enable <= 1'b1;
        decode_stage_enable <= 1'b1;
        execute_stage_enable <= 1'b1;
    end else begin
        case (ecall_flush_state)
            ECALL_FLUSH_IDLE: begin
                // Check for ECALL completion signal
                if (ecall_completed && ecall_req_received) begin
                    // Disable pipeline stages
                    fetch_stage_enable <= 1'b0;
                    decode_stage_enable <= 1'b0;
                    execute_stage_enable <= 1'b0;
                    
                    // Move to wait state
                    ecall_flush_state <= ECALL_FLUSH_WAIT;
                    ecall_flush_counter <= 2'b00;
                end
            end
            
            ECALL_FLUSH_WAIT: begin
                // Wait for 2 cycles
                if (ecall_flush_counter == 2'b10) begin
                    ecall_flush_state <= ECALL_FLUSH_RESTART;
                end else begin
                    ecall_flush_counter <= ecall_flush_counter + 1'b1;
                end
            end
            
            ECALL_FLUSH_RESTART: begin
                // Re-enable pipeline stages
                fetch_stage_enable <= 1'b1;
                decode_stage_enable <= 1'b1;
                execute_stage_enable <= 1'b1;
                
                // Clear ECALL request
                ecall_req_received <= 1'b0;
                ecall_completed <= 0;
                
                // Return to idle state
                ecall_flush_state <= ECALL_FLUSH_IDLE;
            end
            
            default: begin
                ecall_flush_state <= ECALL_FLUSH_IDLE;
            end
        endcase
    end
end


logic [31:0] total_ecall_counter;

logic [63:0] cycle_count;

// always_ff @(posedge clk) begin
//     if (reset) begin
//         cycle_count <= 0;
//     end else begin
//         cycle_count <= cycle_count + 1;
        
//         if (cycle_count == 1000000) begin  // <<< stop after 10,000 cycles (example)
//             $display("Stopping simulation after %d cycles", cycle_count);
//             $finish;
//         end
//     end
// end


// always_ff @(posedge clk) begin
//     if (wb_control_signals.instruction == 32'b0) begin
//         $finish;
//     end
// end

endmodule


