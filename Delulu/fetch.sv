`include "icache.sv"
`include "control_signals_struct.svh"

module Fetch (
    input  logic        clk,
    input  logic        reset,
    input  logic        fetch_stage_enable,
    input  logic [63:0] in_fetch_pc,
    input  logic [63:0] jump_or_branch_address,
    input  logic        jump_or_branch_mux,
    input  logic        if_id_valid,
    input  logic        upstream_disable,

    output logic [31:0] out_fetch_instruction,
    output logic [63:0] out_fetch_pc,
    output logic        fetch_stage_complete,

    // AXI Interface
    input  logic        m_axi_arready,
    input  logic        m_axi_rvalid,
    input  logic        m_axi_rlast,
    input  logic [63:0] m_axi_rdata,
    output logic        m_axi_arvalid,
    output logic [63:0] m_axi_araddr,
    output logic [7:0]  m_axi_arlen,
    output logic [2:0]  m_axi_arsize,
    output logic [1:0]  m_axi_arburst,
    output logic        m_axi_rready,

    output logic        ecall_detected,
    output logic icache_in_flight,
    output logic m_axi_icache_request,
    input logic arbiter_icache_grant,
    input logic wb_inst_ecall

    // output logic [31:0] last_instruction,
    // output logic [63:0] last_instruction_pc,
    // output logic last_instruction_signal
);

    // Internal wires and registers
    logic [63:0] fetch_pc, cache_request_address;
    logic [31:0] fetched_instruction;
    logic        can_issue_request, icache_request_ready, icache_resp_ack;

    // Cache status bundle
    // typedef struct packed {
    //     logic request;
    //     logic in_flight;
    //     logic done;
    // } icache_status_struct;

    // icache_status_struct icache_status;

    // assign fetch_pc = jump_or_branch_mux ? jump_or_branch_address : in_fetch_pc;

    // always_comb begin
    //     if (f_instruction==done_instruction) begin
    //         assign last_instruction_signal = done_signal;
    //         assign last_instruction = done_instruction;
    //     end
    //     end
    // Instantiate i-cache
    icache instruction_cache (
        .clk(clk),
        .reset(reset),
        .icache_pc(cache_request_address),
        .fetch_toggle(in_fetch_pc[2]),    // LSB 2 indicates lower vs upper half
        .f_stall(1'b0),

        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_rready(m_axi_rready),

        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rlast(m_axi_rlast),

        .icache_inst_out_next(out_fetch_instruction),
        .icache_pc_out_next(out_fetch_pc),
        // .valid_cache_data(),              // unused directly
        // .cache_line_ready(),              // unused directly
        .done_instruction(last_instruction),              // unused
        .done_pc(last_instruction_pc),                       // unused
        .done_signal(last_instruction_signal),                   // unused
        // .icache_in_flight(),              // unused
        // .icache_request(),                // unused
        // .icache_status(icache_status)
        // Flattened status outputs
        // .icache_hit(icache_hit),
        .icache_request(m_axi_icache_request),
        .icache_in_flight(icache_in_flight),
        .icache_result_ready(icache_result_ready),
        .new_data_request(icache_request_ready),
        .arbiter_icache_grant(arbiter_icache_grant),
        .jump_mux(jump_or_branch_mux),
        .icache_resp_ack(icache_resp_ack)
    );

    logic jump_signal;
    logic ecall_pending;

    // ECALL detection
    always_ff @(posedge clk) begin
        if (reset) begin
            ecall_detected <= 1'b0;
        end else if (fetch_stage_enable && icache_result_ready) begin
            if (out_fetch_instruction == 32'h00000073) begin
                ecall_detected <= 1'b1;
            end
        end else if (ecall_detected && jump_or_branch_mux) begin
            ecall_detected <= 0;
        end
    end
    
    logic jump_req_pending;
    logic [63:0] jump_or_branch_address_next;
    logic jump_pending;          // Jump detected but not yet processed
    logic jump_processing;       // Jump request is currently being handled
    logic [63:0] jump_target;    // Saved jump target address

    // Jump tracking state
    always_ff @(posedge clk) begin
        if (reset) begin
            jump_pending <= 1'b0;
            jump_processing <= 1'b0;
            jump_target <= 64'b0;
        end else begin
            // Detect jump
            if (jump_or_branch_mux) begin
                jump_target <= jump_or_branch_address;
                jump_pending <= 1'b1;  // Mark jump as pending, don't signal yet
            end
            
            // Track when we've issued the jump request
            if (jump_pending && icache_request_ready) begin
                jump_pending <= 1'b0;      // No longer pending, now active
                jump_processing <= 1'b1;   // Now processing the jump
            end
            
            // Clear processing flag when complete
            if (jump_processing && icache_result_ready && icache_resp_ack) begin
                jump_processing <= 1'b0;   // Jump process complete
            end
        end
    end
    
    // Main fetch logic
    always_comb begin
        // Reset condition
        if (reset) begin
            fetch_stage_complete = 0;
            cache_request_address  = 64'b0;
            icache_request_ready  = 0;
            icache_resp_ack = 0;
    
        end else begin
            if (fetch_stage_enable) begin
                if (!fetch_stage_complete && !if_id_valid) begin
                    if (!icache_in_flight) begin
                        // Only when icache is not busy
                        if (jump_pending) begin
                            // Process pending jump
                            cache_request_address = jump_target;
                            icache_request_ready = 1'b1;
                            icache_resp_ack = 0;

                        end else if (!jump_processing) begin
                            // Normal sequential fetch - only if not processing jump
                            cache_request_address = in_fetch_pc;
                            icache_request_ready = 1'b1;
                            icache_resp_ack = 0;

                        end
                    end
                end
    
                //----------------------------------
                // Phase 2: Wait for Cache Response
                //----------------------------------
                if (icache_result_ready) begin
                    icache_request_ready = 0;
                    icache_resp_ack = 1;
                    // Only complete fetch stage with valid results
                    if (!jump_pending && (jump_processing || !jump_or_branch_mux)) begin
                        // This is the result we're expecting
                        fetch_stage_complete = 1'b1;
                    end
                    // fetch_stage_complete = 1;  // Ready for pipeline

                end
    
                //----------------------------------
                // Phase 3: Wait for Decode to Accept
                //----------------------------------
                if (if_id_valid) begin
                    fetch_stage_complete = 0; // Clear to allow next fetch
                end
    
            end else begin
                // When fetch stage is disabled
                icache_request_ready = 0;
                fetch_stage_complete          = 0;
            end
        end
    end
    
endmodule
