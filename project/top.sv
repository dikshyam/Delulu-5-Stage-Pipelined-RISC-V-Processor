`include "Sysbus.defs"
`include "enums.sv"
`include "decoder.sv"
`include "alu.sv"
`include "pipeline_registers.sv"
`include "reg_file.sv"
`include "fetch.sv"
`include "memory.sv"
`include "arbiter.sv"

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






logic [63:0] clk_counter; // Counts once per clock cycle

// Increment the tick counter on every positive clock edge
always_ff @(posedge clk or posedge reset) begin
if (reset) begin
    clk_counter <= 64'b0; // Reset the counter
    $display("RESET: clk_counter reset to 0 at time %t", $time);
    $display("RESET: stackptr at time %t, %h", $time, stackptr);
end else begin
    clk_counter <= clk_counter + 1;
end
end

logic [63:0] f_pc;           // Program Counter
logic [31:0] f_instruction;  // Fetched instruction
logic [31:0] current_instruction, last_instruction;
logic f_stall;               // Fetch stall signal
logic done_signal, last_instruction_signal;
logic [63:0] done_pc;
logic [31:0] done_instruction;


logic icache_request, dcache_request;

// =============================== Arbiter ===============================

always_ff @(posedge clk) begin
    $display("[TOP] icache_req=%b dcache_req=%b => icache_grant=%b dcache_grant=%b",
                icache_request, dcache_request, grant_icache, grant_dcache);
end

cache_arbiter arbiter (
    .clk            (clk),
    .reset          (reset),
    .icache_req     (icache_request && !icache_in_flight),
    .dcache_req     (dcache_request),
    // .bus_idle       (bus_idle),
    // .ar_hshake      (ar_hshake),
    // .rlast_hshake   (rlast_hshake),
    .icache_grant   (grant_icache),
    .dcache_grant   (grant_dcache)
);

// =============================== Arbiter END ===============================


// Fetch Variables

// signals for fetch/decode hs
// logic fetch_stage_enable, fetch_stage_complete;

// logic if_id_status; //if_id not blocked by stalls
// logic [31:0] in_if_id_instruction, out_if_id_instruction;
// logic [63:0] in_if_id_pc, out_if_id_pc, initial_pc;


// ---------------------------
// FETCH STAGE REGISTERS
// ---------------------------

// Fetch input/output and handshake signals
logic [63:0] fetch_pc_input;                          // PC input to Fetch stage (updated on branch/jump)
logic [31:0] fetch_instruction;                       // Output instruction from Fetch
logic [63:0] jump_or_branch_address;                  // Branch/jump target
logic        jump_or_branch_mux;                      // Branch/jump selector
logic        fetch_stage_enable, fetch_stage_complete;// Fetch enable and handshake complete

// IF/ID pipeline register
logic [31:0] in_if_id_instruction, out_if_id_instruction; // Latched instruction
logic [63:0] in_if_id_pc, out_if_id_pc;                   // Latched PC
logic        if_id_status;                                 // IF/ID stage has valid data

// Stall and reset management
logic        upstream_stall, fetch_reset_done;       // Upstream stall control
logic        ecall_signal;                           // ECALL signal from fetch
logic [4:0]  reg_reset_busy_addr, destination_reg;   // Reset destination reg tracking

// Enable signals for downstream pipeline stages
logic        decode_enable, execute_enable;          // Enables for Decode and Execute
// logic        memory_enable;                        // (Uncomment if needed)


// Stall and control flags
logic downstream_stall, counter_stall, stall_start;

// Fetch control
logic fetch_toggle;  // Selects upper/lower half of cache line

// Pipeline flush / recovery
logic back_signal;


// =================== FETCH BLOCK START =======================


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

    .out_fetch_instruction(out_if_id_instruction),
    .out_fetch_pc(out_if_id_pc),
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

    .ecall_detected(ecall_signal),
    .m_axi_icache_request(icache_request),
    .icache_in_flight(icache_in_flight),
    .arbiter_icache_grant(grant_icache),
    .last_instruction(done_instruction),
    .last_instruction_pc(last_instruction_pc),
    .last_instruction_signal(done_signal)


// Arbiter-related output
// .icache_status(icache_status)

);

always_comb begin
    if (out_if_id_instruction==done_instruction) begin
        assign last_instruction_signal = done_signal;
        assign last_instruction = done_instruction;
    end
end

// =================== FETCH BLOCK END =======================

// ==================== Pipeline Registers for Fetch/Decode Stage Start ====================


//   always_ff @(posedge clk) begin
//     if (reset) begin
//         f_pc <= entry;              // Reset PC to the entry point
//         fetch_toggle <= 1'b0;       // Reset toggle
//         downstream_stall <= 1'b0;   // Clear stall signal
//         back_signal <= 1'b0;
//         counter_stall <= 2'b00;
//         stall_start <= 1'b0;
//         $display("RESET: f_pc set to entry point %h, clk_counter=%0d", entry, clk_counter);
//     end else if (f_stall) begin
//         // Stall if needed
//         $display("FETCH: Stalled at PC %h, clk_counter=%0d | f_stall=%b | cache_line_ready=%b | valid_cache_data=%b", 
//         f_pc, clk_counter, f_stall, cache_line_ready, cache_valid);
//    end else if (cache_line_ready && cache_valid && !f_stall) begin
//         downstream_stall <= 1'b0;  // Clear downstream stall
//         f_instruction = current_instruction;

//         $display("FETCH: Fetched instruction: %h, clk_counter=%0d, PC: %h", 
//                     f_instruction, clk_counter, f_pc);
//         // Advance PC for next fetch (increment by 8 bytes after two 32-bit instructions)
//         if (fetch_toggle) begin
//             //if (back_signal) begin
//                 //f_pc <= f_pc + 4;
//             //end else begin  
//             f_pc <= f_pc + 4;  
//             //end
//             $display("FETCH: PC updated to %h, clk_counter=%0d", f_pc, clk_counter);
//         end

//         // Toggle fetch for next instruction half
//         fetch_toggle <= ~fetch_toggle;
//         $display("FETCH TOGGLE: fetch_toggle updated to %b at clk_counter=%0d", 
//                     fetch_toggle, clk_counter);
//     end else begin
//         // Wait for the cache line to be ready
//         $display("FETCH: Waiting for cache line to be ready, PC=%h, clk_counter=%0d", 
//                     f_pc, clk_counter);
//         downstream_stall <= 1'b1;  // Stall until cache line is ready
//     end
//     end



//     // assign fetch_wr_en = (fetch_has_new_data == 1'b1) || (fetch_has_new_data == 1'b0 && wrote_low_instr == 1'b1);
//     assign fetch_wr_en = !f_stall && fetch_toggle && m_axi_rvalid && m_axi_rready;
always_ff @(posedge clk) begin
    if (reset) begin
        in_if_id_instruction <= 32'b0;
        in_if_id_pc          <= 64'b0;
        fetch_pc_input        <= entry;
        jump_or_branch_address <= 64'b0;
        jump_or_branch_mux    <= 1'b0;
        fetch_stage_enable    <= 1'b1;
        fetch_reset_done      <= 1'b0;
        upstream_stall        <= 1'b0;
        ecall_signal          <= 1'b0;
        if_id_status           <= 1'b0;
        reg_reset_busy_addr   <= 5'b0;
        destination_reg       <= 5'b0;

        decode_enable         <= 1'b0;
        execute_enable        <= 1'b0;
        memory_enable         <= 1'b0;

    end else begin
        if (!fetch_stage_enable) begin
            if (upstream_stall) begin
                in_if_id_instruction <= 32'b0;
                in_if_id_pc          <= 64'b0;
                if_id_status           <= 1'b0;
                fetch_reset_done      <= 1'b1;
                jump_or_branch_mux    <= 1'b0;
                reg_reset_busy_addr   <= destination_reg;
                destination_reg       <= 5'b0;

                if (fetch_reset_done) begin
                    fetch_stage_enable <= 1'b1;
                    decode_enable      <= 1'b1;
                    execute_enable     <= 1'b1;
                    memory_enable      <= 1'b1;
                    fetch_reset_done   <= 1'b0;
                    upstream_stall     <= 1'b0;
                end
            end
        end else begin
            if (fetch_stage_complete && !ecall_signal) begin
                in_if_id_instruction <= out_if_id_instruction;
                in_if_id_pc          <= out_if_id_pc;
                if_id_status           <= 1; //update later

                if (1) begin
                    fetch_pc_input <= fetch_pc_input + 4;
                    if_id_status           <= 0;
                end
            end else if (fetch_stage_complete && ecall_signal) begin
                fetch_stage_enable <= 1'b0;
                
            end
        end
    end
end




// =================== FETCH BLOCK END =======================

// ==================== Pipeline Registers for Fetch/Decode Stage Start ====================


// logic [63:0] in_if_id_pc;
// logic [31:0] in_if_id_instruction;
// logic if_id_done_signal_in;
// logic if_id_done_signal_out;

// always_comb begin
//     if (f_pc == 0) begin
//         in_if_id_pc = f_pc;
//     end else begin
//         in_if_id_pc = fetch_toggle ? f_pc - 4 : f_pc - 8;
//     end
// end
// Debugging: Monitor decode stage behavior
always_ff @(posedge clk) begin
    if (reset) begin
        $display("[DEBUG DECODE] @%0t: Resetting Decode Stage", $time);
    end else begin
    //   if(back_signal) begin
    //     in_if_id_pc = back_pc;
    //     in_if_id_instruction = back_instruction;
    //   end else begin
    //     in_if_id_pc = f_pc;
    //     in_if_id_instruction = f_instruction;
    //   end
    end
end
// assign in_if_id_pc = f_pc;
// assign in_if_id_instruction = f_instruction;
// assign if_id_done_signal_in = last_instruction_signal;
// Pipeline Control Signals
// logic if_id_status;
// logic decode_stall, fetch_stall, branch_flush;

// Define Pipeline Control Logic
// assign decode_stall = 0;   // Example: Replace with real stall signal
// assign fetch_stall  = 0;   // Example: Replace with fetch stall logic
// assign branch_flush = 0;   // Example: Branch or Jump Flush Signal

// IF/ID Valid Logic
// assign if_id_status = !(decode_stall || fetch_stall || branch_flush);
// assign if_id_status = 1'b1;

logic if_id_gen_bubble;

// IF_ID if_id_inst (
//     .clk(clk),
//     .reset(reset),
//     //.wr_en(!last_instruction_signal),
//     .wr_en(1'b1),
//     .gen_bubble(id_ex_gen_bubble),
//     .done_signal_in(if_id_done_signal_in),
//     // .pc_in(!fetch_toggle? f_pc: f_pc+4), // update this
//     .pc_in(f_pc), // update this

//     //.pc_in(in_if_id_pc), // Adjust based on fetch_toggle
//     .instruction_in(in_if_id_instruction),
//     .pc_out(in_if_id_pc),
//     .instruction_out(in_if_id_instruction),
//     .done_signal_out(if_id_done_signal_out)
// );
// Debugging block for IF_ID
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        $display("[DEBUG IF_ID] @%0t: RESET -> PC_OUT=%h, INST_OUT=%h", $time, in_if_id_pc, in_if_id_instruction);
    end else begin
        $display("[DEBUG IF_ID] @%0t: PC_IN=%h, INST_IN=%h | PC_OUT=%h, INST_OUT=%h",
            $time, in_if_id_pc, in_if_id_instruction, in_if_id_pc, in_if_id_instruction);
    end
end
// ==================== Pipeline Registers for Fetch/Decode Stage END ====================
// =================== REG FILE ===================




// Register file signals
logic [63:0] rs1_data, rs2_data;
logic reg_write_complete;
logic raw_hazard;
logic [63:0] rf_regs [31:0]; // For debug

register_file rf_inst (
    .clk(clk),
    .reset(reset),
    .stackptr(stackptr),

    // Reads (from decoder)
    .rs1_addr(decoded_inst.rs1),
    .rs2_addr(decoded_inst.rs2),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),

    // Writeback (from WB stage)
    .reg_write_en(out_mem_wb_reg_write),
    .rd_addr(out_mem_wb_rd),
    .rd_data(mem_wb_result),
    .reg_write_complete(reg_write_complete),

    // RAW hazard tracking
    .mark_busy_addr(decoded_inst.rd),         // In decode stage
    .clear_busy_addr(out_mem_wb_rd),          // In WB stage
    .raw_hazard(raw_hazard),

    // Debug
    .registers(rf_regs)
);
// =================== REG FILE END ===================

// =================== DECODE STAGE START =========================
// Logic for decode stage
logic [63:0] id_ex_pc_out;
logic [31:0] id_ex_instruction_out;
// logic id_ex_wr_en, id_ex_gen_bubble;
logic decode_stall;

// Control signals for ID/EX pipeline stage
assign id_ex_wr_en = !decode_stall;   // Write enabled only if no stall
//assign id_ex_gen_bubble = decode_stall; // Generate bubble on stall
assign gen_trap = 0;         // No trap generated for now
assign gen_trap_cause = 64'b0;
assign gen_trap_val = 64'b0;

// Output from the Decoder
decoder_output decoded_inst; // Struct from Decoder module

// Stall logic for decode stage
assign decode_stall = downstream_stall; // Include downstream stall condition

// Instantiate Decoder
Decoder decode_inst (
    .inst(in_if_id_instruction),      // Instruction from IF/ID pipeline
    .valid(!decode_stall),             // Valid only if not stalled
    .pc(in_if_id_pc),                 // Program Counter from IF/ID pipeline
    .clk_counter(clk_counter),         // Pass clk_counter
//   .rs1_data(rs1_data),        //  From register_file
//   .rs2_data(rs2_data),        // From register_file
//   .registers(registers),
    .out(decoded_inst),                // Decoded instruction output
    .curr_priv_mode(2'b00),            // Default privilege mode; update as needed
    .gen_trap(gen_trap),
    .gen_trap_cause(gen_trap_cause),
    .gen_trap_val(gen_trap_val)
);

// Debugging: Monitor decode stage behavior
always_ff @(posedge clk) begin
    if (reset) begin
        $display("[DEBUG DECODE] @%0t: Resetting Decode Stage", $time);
    end else begin
        $display("[DEBUG DECODE] @%0t: PC=%h, Instruction=%h, Decoded=%p",
                $time, in_if_id_pc, in_if_id_instruction, decoded_inst);
    end
end

always_ff @(posedge clk) begin
$display("[DEBUG DECODE] @%0d: Decoding PC=%h, instruction=%h", clk_counter, in_if_id_pc, in_if_id_instruction);
end
// =================== DECODE STAGE END =========================
//   assign decode_stall = 0; // Testing - No decode stall
//   assign downstream_stall = 0; // Testing - Ignore downstream stalls
assign id_ex_wr_en = 1; // Testing - Always enable pipeline writes
//assign id_ex_gen_bubble = 0; // Testing - No bubble generation

// always_ff @(posedge clk or posedge reset) begin
//     if (reset) begin
//         // Reset ID/EX pipeline registers
//         id_ex_pc_reg <= 64'b0;
//         id_ex_instruction_reg <= 32'b0;
//         id_ex_decoded_inst_reg <= '0;
//       //   $display("RESET: Clearing ID/EX pipeline register at clk_counter=%0d", clk_counter);
//     end else if (id_ex_wr_en) begin
//         if (id_ex_gen_bubble) begin
//             // Generate bubble
//             id_ex_pc_reg <= 64'b0;
//             id_ex_instruction_reg <= 32'b0;
//             id_ex_decoded_inst_reg <= '0;
//           //   $display("ID_EX: Generating bubble at clk_counter=%0d", clk_counter);
//         end else begin
//             // Write to ID/EX pipeline register
//             id_ex_pc_reg <= in_if_id_pc;
//             id_ex_instruction_reg <= in_if_id_instruction;
//             id_ex_decoded_inst_reg <= decoded_inst;
//           //   $display("ID_EX: Writing to pipeline register. PC=%d, Instruction=%h at clk_counter=%0d",
//           //           in_if_id_pc, in_if_id_instruction, clk_counter);
//         end
//     end
// end

// // Outputs from ID/EX Pipeline Register
// assign id_ex_pc_out = id_ex_pc_reg;
// assign id_ex_instruction_out = id_ex_instruction_reg;



// Temporary signals for tracing decoded_inst.rs1 and decoded_inst.rs2
logic [4:0] temp_rs1, temp_rs2;

always_ff @(posedge clk) begin
    if (reset) begin
        temp_rs1 <= 5'b0;  // Reset temporary signals
        temp_rs2 <= 5'b0;
        $display("[RESET] Decoded rs1 and rs2 reset to 0");
    end else begin
        temp_rs1 <= decoded_inst.rs1;  // Track rs1 address
        temp_rs2 <= decoded_inst.rs2;  // Track rs2 address
        $display("[DEBUG DECODED_RS] @%0t: rs1=%d, rs2=%d", $time, temp_rs1, temp_rs2);
    end
end






// =================== ID/EX Pipeline Registers ===================

// Inputs to the pipeline register
logic [63:0] in_id_ex_pc;          // Input Program Counter (PC)
logic [31:0] in_id_ex_instruction; // Input Instruction
logic [63:0] in_id_ex_rs1_data;    // Input data for rs1
logic [63:0] in_id_ex_rs2_data;    // Input data for rs2
logic [63:0] in_id_ex_immed;       // Immediate value
decoder_output in_id_ex_decoded_inst; // Control signals from Decoder
logic id_ex_done_signal_in;

// Outputs from the pipeline register
logic [63:0] out_id_ex_pc;         // Output Program Counter (PC)
logic [31:0] out_id_ex_instruction; // Output Instruction
logic [63:0] out_id_ex_rs1_data;   // Output data for rs1
logic [63:0] out_id_ex_rs2_data;   // Output data for rs2
logic [63:0] out_id_ex_immed;      // Output Immediate value
decoder_output out_id_ex_decoded_inst; // Output control signals
logic id_ex_wr_en;                 // Write Enable for pipeline
logic id_ex_gen_bubble;            // Generate bubble (flush values)
logic id_ex_done_signal_out;
logic [4:0] id_ex_rs1_out;
logic [4:0] id_ex_rs2_out;
logic [4:0] id_ex_rd_out;

assign id_ex_wr_en = 1;  // Enable writing for testing
//assign id_ex_gen_bubble = 0;  // No bubble generation for testing

always_ff @(posedge clk or posedge reset) begin
if (reset) begin
    // Reset all pipeline registers
    out_id_ex_pc <= 64'b0;
    out_id_ex_instruction <= 32'b0;
    out_id_ex_rs1_data <= 64'b0;
    out_id_ex_rs2_data <= 64'b0;
    out_id_ex_immed <= 64'b0;
    out_id_ex_decoded_inst <= '0;
end else if (id_ex_wr_en) begin
    if (id_ex_gen_bubble) begin
        // Flush pipeline registers
        out_id_ex_pc <= 64'b0;
        out_id_ex_instruction <= 32'b0;
        out_id_ex_rs1_data <= 64'b0;
        out_id_ex_rs2_data <= 64'b0;
        out_id_ex_immed <= 64'b0;
        out_id_ex_decoded_inst <= '0;
    end else begin
        // Pass values to the pipeline register
        out_id_ex_pc <= in_id_ex_pc;
        out_id_ex_instruction <= in_id_ex_instruction;
        out_id_ex_rs1_data <= in_id_ex_rs1_data;
        out_id_ex_rs2_data <= in_id_ex_rs2_data;
        out_id_ex_immed <= in_id_ex_immed;
        out_id_ex_decoded_inst <= in_id_ex_decoded_inst;
    end
end
end


// Assign input signals
assign in_id_ex_pc = in_if_id_pc;
assign in_id_ex_instruction = in_if_id_instruction;
assign in_id_ex_rs1_data = rs1_data;              // From Register File
assign in_id_ex_rs2_data = rs2_data;              // From Register File
assign in_id_ex_immed = decoded_inst.immed;       // Immediate value from Decoder
assign in_id_ex_decoded_inst = decoded_inst;      // Control signals from Decoder

// Debugging information
// back beginning
logic [63:0] back_pc;
logic [31:0] back_instruction;

always_ff @(posedge clk) begin
    $display("[DEBUG ID_EX PIPELINE] @%0t: PC=%h, Instruction=%h, rs1=%h, rs2=%h, immed=%h",
            $time, out_id_ex_pc, out_id_ex_instruction, decoded_inst.rs1, decoded_inst.rs2, out_id_ex_immed);

if (counter_stall > 0) begin
    counter_stall <= counter_stall - 1;
    f_stall <= 1'b1;
    id_ex_gen_bubble <= 1'b1;
    stall_start <= 1'b1;
end else if ((decoded_inst.rs1 != 0 && ex_mem_rs1_out != 0 && mem_wb_rs1_out != 0 && 
                (decoded_inst.rs1 == ex_mem_rs1_out || decoded_inst.rs1 == mem_wb_rs1_out)) || 
                (decoded_inst.rs2 != 0 && ex_mem_rs2_out != 0 && mem_wb_rs2_out != 0 && 
                (decoded_inst.rs2 == ex_mem_rs2_out || decoded_inst.rs2 == mem_wb_rs2_out))) begin
    counter_stall <= 3;
    id_ex_gen_bubble <= 1'b1;
    if_id_gen_bubble <= 1'b1;
    ex_mem_gen_bubble <= 1'b1;
    back_pc <= in_if_id_pc - 4;
    back_instruction <= in_if_id_instruction;
    f_stall <= 1'b1;
    stall_start <= 1'b1;
    if (!fetch_toggle) begin
        f_pc <= f_pc - 8;
    end else begin
        f_pc <= f_pc - 0;
        //fetch_toggle <= 1'b1;
    end
end else begin
    if (stall_start) begin
        back_signal <= 1'b1;
        stall_start <= 1'b0;
    end else begin
        back_signal <= 1'b0;
    end
    id_ex_gen_bubble <= 1'b0;
    if_id_gen_bubble <= 1'b0;
    ex_mem_gen_bubble <= 1'b0;
    f_stall <= 1'b0;
end
// if((decoded_inst.rs1 != 0 && ex_mem_rs1_out != 0 && mem_wb_rs1_out != 0 && (decoded_inst.rs1 == ex_mem_rs1_out || decoded_inst.rs1 == mem_wb_rs1_out)) || 
//     (decoded_inst.rs2 != 0 && ex_mem_rs2_out != 0 && mem_wb_rs2_out != 0 && (decoded_inst.rs2 == ex_mem_rs2_out || decoded_inst.rs2 == mem_wb_rs2_out)))begin
//     id_ex_gen_bubble <= 1'b1;
//     //ex_mem_gen_bubble <= 1'b1;
//    // mem_wb_gen_bubble <= 1'b1;
//     back_pc <= in_if_id_pc;
//     back_instruction <= out_id_ex_instruction;
//     f_stall <= 1'b1;
// end else begin
//     id_ex_gen_bubble <= 1'b0;
//     //ex_mem_gen_bubble <= 1'b0;
//     //mem_wb_gen_bubble <= 1'b0;
//     f_stall <= 1'b0;
//     back_signal <= 1'b1;
// end
end

// =================== ID/EX Pipeline Module ===================
ID_EX_pipeline_reg id_ex_inst (
    .clk(clk),
    .reset(reset),
    .if_id_pc_out(in_if_id_pc),
    .if_id_instruction_out(in_if_id_instruction),
    .decoded_inst(decoded_inst),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data),
    .rs1(decoded_inst.rs1),
    .rs2(decoded_inst.rs2),
    .rd(decoded_inst.rd),
    .id_ex_wr_en(id_ex_wr_en),
    .id_ex_gen_bubble(id_ex_gen_bubble),
    .if_id_valid(if_id_status),
    .clk_counter(clk_counter),
    .done_signal_in(if_id_done_signal_out),
    .id_ex_valid(id_ex_valid),
    .id_ex_pc_reg(out_id_ex_pc),
    .id_ex_instruction_reg(out_id_ex_instruction),
    .id_ex_rs1_data(out_id_ex_rs1_data),
    .id_ex_rs2_data(out_id_ex_rs2_data),
    .id_ex_decoded_inst_reg(out_id_ex_decoded_inst),
    .done_signal_out(id_ex_done_signal_out),
    .id_ex_rs1(id_ex_rs1_out),
    .id_ex_rs2(id_ex_rs2_out),
    .id_ex_rd(id_ex_rd_out)
);
// // =================== ID_EX PIPELINE REGISTER Start ===================

// // =================== ID_EX PIPELINE REGISTER END ===================

// =================== EX STAGE SIGNALS ===================
logic [63:0] in_ex_operand1, in_ex_operand2;   // ALU Operands
logic [3:0]  in_ex_alu_op;                     // ALU Operation Code
logic [63:0] out_ex_alu_result;                // ALU Result
logic        out_ex_alu_zero;                  // Zero Flag
logic [63:0] in_ex_alu_pc;          // Input Program Counter (PC)
logic [31:0] in_ex_alu_instruction; // Input Instruction
// Assign inputs from ID/EX Pipeline Register
assign in_ex_operand1 = out_id_ex_rs1_data;       // First Operand (Register rs1)
assign in_ex_operand2 = (out_id_ex_decoded_inst.alu_use_immed) 
                        ? out_id_ex_immed       // Use immediate value if set
                        : out_id_ex_rs2_data;   // Otherwise, use Register rs2
assign in_ex_alu_op = out_id_ex_decoded_inst.alu_op;  // ALU Operation Code
assign in_ex_alu_instruction = out_id_ex_instruction;
assign in_ex_alu_pc = out_id_ex_pc;

// ALU Instance
ALU alu_inst (
    .operand1(in_ex_operand1),
    .operand2(in_ex_operand2),
    .alu_op(in_ex_alu_op),
    .alu_32(out_id_ex_decoded_inst.alu_width_32),
    .instruction(in_ex_alu_instruction),
    .pc(in_ex_alu_pc),
    .result(out_ex_alu_result),
    .zero(out_ex_alu_zero)
);


// =================== DEBUG LOGS ===================
always_ff @(posedge clk) begin
    $display("[DEBUG EX STAGE] @%0t: PC=%h, ALU_OP=%h, Operand1=%h, Operand2=%h, Result=%h",
            $time, out_id_ex_pc, in_ex_alu_op, in_ex_operand1, in_ex_operand2, out_ex_alu_result);
end


// =================== EX_MEM PIPELINE REGISTER ===================
logic [63:0] in_ex_mem_alu_result, out_ex_mem_alu_result;
logic [63:0] in_ex_mem_rs2_data, out_ex_mem_rs2_data;
logic [4:0]  in_ex_mem_rd, out_ex_mem_rd;

// Control Signals for EX_MEM
logic in_ex_mem_mem_write, out_ex_mem_mem_write;
logic in_ex_mem_mem_read, out_ex_mem_mem_read;
logic in_ex_mem_reg_write, out_ex_mem_reg_write;
logic in_ex_mem_mem_to_reg, out_ex_mem_mem_to_reg;

// Instruction and PC Tracking
logic [31:0] in_ex_mem_instruction, out_ex_mem_instruction;
logic [63:0] in_ex_mem_pc, out_ex_mem_pc;

logic [4:0] ex_mem_rs1_in;
logic [4:0] ex_mem_rs2_in;
logic [4:0] ex_mem_rs1_out;
logic [4:0] ex_mem_rs2_out;
logic [4:0] ex_mem_rd_in;
logic [4:0] ex_mem_rd_out;

assign ex_mem_rs1_in = id_ex_rs1_out;
assign ex_mem_rs2_in = id_ex_rs2_out;
assign ex_mem_rd_in = id_ex_rd_out;


// =================== Pass Results to EX_MEM Pipeline ===================
assign in_ex_mem_alu_result = out_ex_alu_result;    // Direct ALU result
assign in_ex_mem_rd = out_id_ex_decoded_inst.rd;    // Destination Register
assign in_ex_mem_rs2_data = out_id_ex_rs2_data;     // Data for Store Instruction

// Control Signals from ID/EX Pipeline
assign in_ex_mem_mem_write = out_id_ex_decoded_inst.mem_write; 
assign in_ex_mem_mem_read  = out_id_ex_decoded_inst.mem_read;  
assign in_ex_mem_reg_write = out_id_ex_decoded_inst.reg_write;
assign in_ex_mem_mem_to_reg = out_id_ex_decoded_inst.mem_to_reg;

assign in_ex_mem_instruction = out_id_ex_instruction;
assign in_ex_alu_pc = out_id_ex_pc;
assign in_ex_mem_pc = out_id_ex_pc;

// Pipeline Control Signals
logic ex_mem_wr_en, ex_mem_gen_bubble;
assign ex_mem_wr_en = 1;        // Always write for testing
//assign ex_mem_gen_bubble = 0;   // No bubble generation for now
//assign ex_mem_wr_en = id_ex_valid && !ex_mem_gen_bubble;

// Decoder Output Struct
decoder_output out_ex_decoded_inst;

logic ex_mem_done_signal_in;
logic ex_mem_done_signal_out;

// Instantiate EX_MEM Pipeline Register
EX_MEM ex_mem_inst (
    // System Signals
    .clk(clk),
    .reset(reset),

    // Pipeline Control
    .wr_en(ex_mem_wr_en),
    .gen_bubble(ex_mem_gen_bubble),

    // Inputs from Execute Stage
    .alu_result_in(in_ex_mem_alu_result),    // ALU result from Execute Stage
    .rs2_data_in(in_ex_mem_rs2_data),        // Store data from Execute Stage
    //.rd_in(in_ex_mem_rd),                    // Destination register
    .mem_write_in(in_ex_mem_mem_write),      // Memory write signal
    .mem_read_in(in_ex_mem_mem_read),        // Memory read signal
    .reg_write_in(in_ex_mem_reg_write),      // Register write-back signal
    .mem_to_reg_in(in_ex_mem_mem_to_reg),    // Memory-to-register select
    .ex_decoded_inst_in(id_ex_decoded_inst), // Decoded instruction
    .instruction_in(in_ex_mem_instruction),  // Pass instruction
    .pc_in(in_ex_mem_pc),                    // Pass program counter
    .done_signal_in(id_ex_done_signal_out),
    .rs1_in(ex_mem_rs1_in),
    .rs2_in(ex_mem_rs2_in),
    .rd_in(ex_mem_rd_in),

    // Outputs to MEM/WB Stage
    .alu_result_out(out_ex_mem_alu_result),
    .rs2_data_out(out_ex_mem_rs2_data),
    //.rd_out(out_ex_mem_rd),
    .mem_write_out(out_ex_mem_mem_write),
    .mem_read_out(out_ex_mem_mem_read),
    .reg_write_out(out_ex_mem_reg_write),
    .mem_to_reg_out(out_ex_mem_mem_to_reg),
    .ex_decoded_inst_out(out_ex_decoded_inst),
    .instruction_out(out_ex_mem_instruction), // Forward instruction
    .pc_out(out_ex_mem_pc),                    // Forward PC
    .done_signal_out(ex_mem_done_signal_out),
    .rs1_out(ex_mem_rs1_out),
    .rs2_out(ex_mem_rs2_out),
    .rd_out(ex_mem_rd_out)
);

// =================== DEBUG LOGS ===================
always_ff @(posedge clk) begin
    if (reset) begin
        $display("[EX/MEM RESET] Pipeline reset at clk=%0t", $time);
    end else if (ex_mem_wr_en) begin
        $display("[DEBUG EX/MEM] @%0t:", $time);
        $display("  - PC                : %h", out_ex_mem_pc);
        $display("  - Instruction       : %h", out_ex_mem_instruction);
        $display("  - ALU Result        : %h", out_ex_mem_alu_result);
        $display("  - RS2 Data          : %h", out_ex_mem_rs2_data);
        $display("  - Write Register    : x%0d", out_ex_mem_rd);
        $display("  - Reg Write Enable  : %b", out_ex_mem_reg_write);
        $display("  - Mem Write Enable  : %b", out_ex_mem_mem_write);
        $display("  - Mem Read Enable   : %b", out_ex_mem_mem_read);
        $display("  - Mem To Reg        : %b", out_ex_mem_mem_to_reg);
        $display("  - Decoded Instruction:");
        $display("      - rs1           : x%0d", out_ex_decoded_inst.rs1);
        $display("      - rs2           : x%0d", out_ex_decoded_inst.rs2);
        $display("      - rd            : x%0d", out_ex_decoded_inst.rd);
        $display("      - ALU OP        : %d", out_ex_decoded_inst.alu_op);
        $display("      - Reg Write     : %b", out_ex_decoded_inst.reg_write);
        $display("      - Mem Write     : %b", out_ex_decoded_inst.mem_write);
        $display("      - Mem Read      : %b", out_ex_decoded_inst.mem_read);
    end
end


// =================== DEBUG LOGS ===================
always_ff @(posedge clk) begin
    $display("[DEBUG EX/MEM] @%0t: PC=%h, ALU_RESULT=%h, RD=%d, MEM_WRITE=%b, MEM_READ=%b, REG_WRITE=%b, MEM_TO_REG=%b", 
            $time, out_ex_mem_pc, out_ex_mem_alu_result, out_ex_mem_rd, 
            out_ex_mem_mem_write, out_ex_mem_mem_read, 
            out_ex_mem_reg_write, out_ex_mem_mem_to_reg);
end


// =================== Memory Stage ========================
// MEMORY STARTS
logic out_memory_done, memory_ready, memory_enable;

logic [63:0] mem_wb_loaded_data;
logic mem_wb_valid_reg;
control_signals_struct mem_wb_control_signals_reg;
logic [63:0] mem_wb_alu_data;
logic memory_ecall_clean;
logic top_stall_core;
logic [63:0] ex_mem_pc_plus_I_offset_reg;
logic [63:0] ex_mem_alu_data;
logic [63:0] ex_mem_reg_b_data;
decoder_output ex_mem_control_signal_struct;
logic ecall_detected;

always_ff @(posedge clk or posedge reset) begin
    if (reset) mem_wb_valid_reg <= 0;
    else       mem_wb_valid_reg <= out_memory_done;
end

Memory memory_stage (
    .clk(clk),
    .reset(reset),
    .memory_enable(memory_enable),
    .pc_I_offset(memory_pc_plus_I_input),
    .reg_b_contents(memory_reg_b_data_input),
    .alu_data(memory_alu_data_input),
    .control_signals(memory_control_signals_struct_input),
    .mem_wb_pipeline_valid(mem_wb_valid_reg),
    .instruction_cache_reading(instruction_cache_reading),

    .loaded_data_out(mem_wb_loaded_data),
    .memory_done(memory_done),

    // AXI Read Interface
    .mem_read_addr(m_axi_araddr_dcache),
    .mem_read_valid(m_axi_arvalid_dcache),
    .mem_read_data(m_axi_rdata),
    .mem_read_ready(m_axi_rvalid),

    // AXI Write - unused, set to defaults inside memory.sv
    .m_axi_awready(m_axi_awready),
    .m_axi_wready(m_axi_wready),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_bready(m_axi_bready),

    // AXI Snoop - stubbed inside memory
    .m_axi_acvalid(m_axi_acvalid),
    .m_axi_acready(m_axi_acready),
    .m_axi_acaddr(m_axi_acaddr),
    .m_axi_acsnoop(m_axi_acsnoop),
    .snoop_stall(top_stall_core),

    .ecall_clean(1'b0),                // Currently not supported
    .data_cache_reading(data_cache_reading)             // Not used
);


// Register inputs to memory module
assign memory_pc_plus_I_input = ex_mem_pc_plus_I_offset_reg;
assign memory_alu_data_input = ex_mem_alu_data;
assign memory_reg_b_data_input = ex_mem_reg_b_data;
assign memory_control_signals_struct_input = ex_mem_control_signal_struct;
assign memory_ecall_clean = ecall_detected;

// Register outputs from memory stage
assign mem_wb_control_signals_reg = ex_mem_control_signal_struct;
assign mem_wb_alu_data = ex_mem_alu_data;
// /* verilator lint_off UNOPTFLAT */
// assign mem_wb_valid_reg = memory_done;
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        mem_wb_valid_reg <= 1'b0;
    end else begin
        mem_wb_valid_reg <= memory_done;
    end
end

/* verilator lint_on UNOPTFLAT */

// assign mem_wb_valid_reg = memory_done;

// ======================== Memory Ends



// =================== MEM/WB PIPELINE REGISTER ===================

// Declare MEM/WB pipeline stage signals
logic [63:0] in_mem_wb_result, out_mem_wb_result;
logic [31:0] in_mem_wb_instruction, out_mem_wb_instruction;
logic [63:0] in_mem_wb_pc, out_mem_wb_pc;
logic [4:0]  in_mem_wb_rd, out_mem_wb_rd;
logic [63:0] in_mem_wb_rs2_data, out_mem_wb_rs2_data;
logic        in_mem_wb_reg_write, out_mem_wb_reg_write;
logic        in_mem_wb_mem_write, out_mem_wb_mem_write;
logic        in_mem_wb_mem_to_reg, out_mem_wb_mem_to_reg;
logic        in_mem_wb_mem_read, out_mem_wb_mem_read;  // Corrected Signal

logic mem_wb_done_signal_in;
logic mem_wb_done_signal_out;
logic [4:0] mem_wb_rs1_in;
logic [4:0] mem_wb_rs2_in;
logic [4:0] mem_wb_rs1_out;
logic [4:0] mem_wb_rs2_out;
logic [4:0] mem_wb_rd_in;
logic [4:0] mem_wb_rd_out;

assign mem_wb_rs1_in = ex_mem_rs1_out;
assign mem_wb_rs2_in = ex_mem_rs2_out;
assign mem_wb_rd_in = ex_mem_rd_out;

wb_output wb_out;
// Assignments from EX/MEM Stage
// assign in_mem_wb_result        = out_ex_mem_alu_result; 
assign in_mem_wb_result = out_ex_mem_mem_to_reg 
                        ? mem_wb_loaded_data 
                        : out_ex_mem_alu_result;
    
assign in_mem_wb_instruction   = out_ex_mem_instruction; 
assign in_mem_wb_pc            = out_ex_mem_pc;                  
//assign in_mem_wb_rd            = out_ex_mem_rd;
assign in_mem_wb_rd = ex_mem_rd_out;
assign in_mem_wb_rs2_data      = out_ex_mem_rs2_data;
assign in_mem_wb_reg_write     = out_ex_mem_reg_write;
assign in_mem_wb_mem_write     = out_ex_mem_mem_write;
assign in_mem_wb_mem_to_reg    = out_ex_mem_mem_to_reg;
assign in_mem_wb_mem_read      = out_ex_mem_mem_read;  // Corrected Assignment


// Pipeline Control Signals
//assign mem_wb_wr_en            = (out_ex_mem_reg_write || out_ex_mem_mem_write) && !ex_mem_gen_bubble;
assign mem_wb_wr_en = 1;
logic mem_wb_gen_bubble;
//assign mem_wb_gen_bubble       = 0;  // No bubble insertion for now

// Instantiate MEM/WB Pipeline Register
MEM_WB_pipeline_reg mem_wb_inst (
    .clk(clk),
    .reset(reset),

    // Pipeline Control Signals
    .mem_wb_wr_en(mem_wb_wr_en),               
    .mem_wb_gen_bubble(mem_wb_gen_bubble),
    .done_signal_in(ex_mem_done_signal_out),
    .done_signal_out(mem_wb_done_signal_out),
    .rs1_in(mem_wb_rs1_in),
    .rs2_in(mem_wb_rs2_in),
    .rd_in(mem_wb_rd_in),
    .rs1_out(mem_wb_rs1_out),
    .rs2_out(mem_wb_rs2_out),
    .rd_out(mem_wb_rd_out),

    // Inputs from MEM Stage
    .mem_result(in_mem_wb_result),                   
    .mem_instruction(in_mem_wb_instruction), 
    .mem_pc(in_mem_wb_pc),  
    .mem_rd(in_mem_wb_rd), 
    .mem_rs2_data(in_mem_wb_rs2_data),          
    .mem_wb_reg_write_in(in_mem_wb_reg_write),   
    .mem_wb_mem_to_reg_in(in_mem_wb_mem_to_reg),  
    .mem_wb_mem_read_in(in_mem_wb_mem_read),   // Corrected Connection
    .mem_wb_is_store_in(in_mem_wb_mem_write),  // Correctly Linked

    // Outputs to Writeback Stage
    .wb_out(wb_out)
);

logic [63:0] out_mem_wb_mem_read_data;
assign mem_wb_mem_read_data_reg = 64'b0;
// Extract destination register (rd) from the decoded instruction
assign out_mem_wb_rd = wb_out.rd;
assign out_mem_wb_instruction = wb_out.instruction;

// Select between Memory Read Data and ALU Result based on control signal
logic [63:0] mem_wb_result;
assign mem_wb_result = wb_out.mem_to_reg 
                        ? out_mem_wb_mem_read_data 
                        : wb_out.result;

// =================== DEBUG LOGS ===================
always_ff @(posedge clk) begin
    if (reset) begin
        $display("[MEM/WB RESET] Pipeline reset at clk=%0t", $time);
    end else if (mem_wb_wr_en) begin
        $display("[MEM/WB DEBUG] clk=%0t", $time);
        $display("  - PC                : %h", wb_out.pc);
        $display("  - Instruction       : %h", wb_out.instruction);
        $display("  - ALU Result        : %h", wb_out.result);
        $display("  - RS2 Data          : %h", wb_out.rs2_data);
        $display("  - Write Register    : x%0d", wb_out.rd);
        $display("  - Reg Write Enable  : %b", wb_out.reg_write);
        $display("  - Mem To Reg        : %b", wb_out.mem_to_reg);
    end
end
// Writeback Stage Logic

// Writeback Stage Logic
// always_ff @(posedge clk or posedge reset) begin
//     if (reset) begin
//         $display("[RESET] Writeback stage reset at clk_counter=%0d", clk_counter);
//     end else begin
//         if (wb_out.reg_write && wb_out.rd != 5'b0) begin
//             // Perform Register Writeback
//             $display("[WB] Register x%0d <= %h | PC=%h | clk_counter=%0d", 
//                     wb_out.rd, wb_out.result, wb_out.pc, clk_counter);
//         end else begin
//             // Skip Register Writeback
//             $display("[WB SKIP] No Register Writeback | RegWrite=%b | RD=%d | PC=%h", 
//                     wb_out.reg_write, wb_out.rd, wb_out.pc);
//         end

//         if (wb_out.is_store) begin
//             // Perform Store Writeback
//             $display("[WRITEBACK] Memory Write: Addr=%h | Value=%h | Size=%0d | PC=%h", 
//                     wb_out.result, wb_out.rs2_data, 8, wb_out.pc);
//             do_pending_write(wb_out.result, wb_out.rs2_data, 8);
//         end else begin
//             // Skip Memory Writeback
//             $display("[MEM SKIP] No Memory Write | is_store=%b | PC=%h", 
//                     wb_out.is_store, wb_out.pc);
//         end
//     end
// end
always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        $display("[RESET] Writeback stage reset at clk_counter=%0d", clk_counter);
    end else if (mem_wb_wr_en) begin
        if (wb_out.is_store) begin
            $display("[MEMORY WRITE] Addr=%h | Value=%h | Size=%0d | PC=%h", 
                    wb_out.result, wb_out.rs2_data, 8, wb_out.pc);
            do_pending_write(wb_out.result, wb_out.rs2_data, 8);
        end else if (wb_out.reg_write && wb_out.rd != 5'b0) begin
            $display("[WB] Register x%0d <= %h | PC=%h | clk_counter=%0d", 
                    wb_out.rd, wb_out.result, wb_out.pc, clk_counter);
        end else begin
            $display("[WB SKIP] No Writeback | RegWrite=%b | MemWrite=%b | RD=%d | PC=%h", 
                    wb_out.reg_write, wb_out.is_store, wb_out.rd, wb_out.pc);
        end

        if((out_mem_wb_instruction == last_instruction) && (last_instruction != 32'b0)) begin
            $display("[WB] LAST INSTRUCTION PROCESSED");
            // for (int i = 0; i < 32; i++) begin
            //     $display("[RESET] Register x%0d initialized to %h", i, registers[i]);
            // end
            for (int i = 0; i < 32; i++) begin
                $display("[FINAL] REGISTER[%0d] = 0x%0h", i, rf_regs[i]);
            end
            $finish;
        end
    end
end

// Writeback Control Signals
assign out_mem_wb_reg_write = wb_out.reg_write;
assign out_mem_wb_rd = wb_out.rd;
// assign mem_wb_result = wb_out.result;
// if else - register memory 
// do ecall will be in write back
// m_axi write cables -- do_pending_write
// 
// for (int i = 0; i < 32; i++) begin
//     $display("[FINAL] REGISTER[%0d] = 0x%0h", i, rf_regs[i]);
// end

endmodule
