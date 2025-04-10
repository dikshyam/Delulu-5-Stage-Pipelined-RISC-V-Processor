`include "control_signals_struct.svh"

module icache #(
    parameter CACHE_SIZE = 512, //512,  // Cache size in bytes
    parameter LINE_SIZE = 8,     // Cache line size in bytes
    parameter NUM_WAYS = 2,       
    parameter NUM_SETS = CACHE_SIZE / (LINE_SIZE * NUM_WAYS),
    parameter ADDR_WIDTH = 64,   
    parameter DATA_WIDTH = 64,   // Data width (8 bytes)
    parameter MAX_TRANSFERS = (NUM_SETS * NUM_WAYS)
)(
    input logic clk,
    input logic reset,

    // Entry and stack pointer from top.sv
    input logic [ADDR_WIDTH-1:0] icache_pc,
    input logic fetch_toggle,
    input logic f_stall,

    // AXI Interface - Read Address
    output logic [ADDR_WIDTH-1:0] m_axi_araddr,
    output logic [7:0] m_axi_arlen,
    output logic [2:0] m_axi_arsize,
    output logic [1:0] m_axi_arburst,
    output logic m_axi_arvalid,
    output logic m_axi_rready,

    input  logic m_axi_arready,

    // AXI Interface - Read Data
    input  logic [DATA_WIDTH-1:0] m_axi_rdata,
    input  logic m_axi_rvalid,
    input  logic m_axi_rlast,


    // I-Cache Specific Outputs
    output logic [31:0] icache_inst_out,
    // output logic valid_cache_data,
    // output logic cache_line_ready,
    output logic [31:0] done_instruction,
    output logic [ADDR_WIDTH-1:0] done_pc,
    output logic done_signal,
    
    // input logic icache_in_flight,
    // output logic icache_request
    output cache_status_struct icache_status

    // input logic icache_in_flight
);

    // Aligned instruction fetch address (8-byte aligned)
    // logic [ADDR_WIDTH-1:0] fetch_address;
    // assign fetch_address = icache_pc & 64'hFFFFFFFFFFFFFFF8;  // Clear lower 3 bits

    // Selects which half (upper/lower) of the 64-bit cache line to use
    logic select_upper_half;
    assign select_upper_half = icache_pc[2];

    // Holds the final selected 32-bit instruction from cache
    logic [31:0] icache_inst_out_v2;


    // Internal Registers
    logic [ADDR_WIDTH-1:0] fetch_pc, curr_pc, prev_pc;
    logic read_request_pending;
    logic terminate_simulation;
    logic [15:0] timeout_counter;
    logic [7:0] num_transfers;
    logic [63:0] current_instruction, previous_instruction;

    // Cache Storage
    logic [DATA_WIDTH-1:0] cache_data [NUM_SETS-1:0][NUM_WAYS-1:0];
    logic [51:0] cache_tags [NUM_SETS-1:0][NUM_WAYS-1:0]; 
    logic cache_valid [NUM_SETS-1:0][NUM_WAYS-1:0];

    // Address Breakdown (Calculated Separately)
    logic [5:0] fetch_index, f_index;
    logic [51:0] fetch_tag, f_tag;
    logic signed [31:0] way_to_update;  // Declare as logic
    
    // assign icache_request = !valid_cache_data && !read_request_pending;
    // assign icache_status.request = (!valid_cache_data && !read_request_pending);
    // assign icache_status.done    = cache_line_ready;
    
    // always_ff @(posedge clk or posedge reset) begin
    //     if (reset) begin
    //         icache_status.in_flight <= 0;
    //     end else begin
    //         case (fsm_state)
    //             FETCH, WAIT_FOR_DATA, CACHE_UPDATE: icache_status.in_flight <= 1;
    //             IDLE: icache_status.in_flight <= 0;
    //             default: icache_status.in_flight <= icache_status.in_flight;
    //         endcase
    //     end
    // end
    

    // Address Assignments (always_comb block for clarity)
    // always_comb begin
    //     fetch_index = curr_pc[11:6];  // Extract index bits
    //     fetch_tag   = curr_pc[63:12]; // Extract tag bits
    //     f_index     = icache_pc[11:6];
    //     f_tag       = icache_pc[63:12];
    // end
    assign f_index = icache_pc[$clog2(NUM_SETS) + $clog2(LINE_SIZE) - 1:$clog2(LINE_SIZE)];
    assign f_tag = icache_pc[ADDR_WIDTH-1 : $clog2(NUM_SETS) + $clog2(LINE_SIZE)];


    // Calculate fetch index and tag using dynamic bit ranges
    assign fetch_index = curr_pc[$clog2(NUM_SETS) + $clog2(LINE_SIZE) - 1 : $clog2(LINE_SIZE)];
    assign fetch_tag = curr_pc[ADDR_WIDTH-1 : $clog2(NUM_SETS) + $clog2(LINE_SIZE)];

    // FSM States Definition
    typedef enum logic [2:0] {
        IDLE, 
        FETCH, 
        WAIT_FOR_DATA, 
        CACHE_UPDATE, 
        HALT
    } fsm_state_t;

    fsm_state_t fsm_state;

    // Cache Hit Logic
    always_comb begin
        // icache_status.in_flight = (fsm_state != IDLE);
        // icache_status.done      = cache_line_ready;

        // icache_status.hit       = 0;
        // icache_inst_out         = 32'b0;
        if (cache_line_ready) begin
            // valid_cache_data = 1'b0;
            icache_inst_out = 32'b0;
            
            for (int i = 0; i < NUM_WAYS; i++) begin
                if (cache_valid[f_index][i] && cache_tags[f_index][i] == f_tag) begin
                    icache_inst_out_v2 = fetch_toggle ? cache_data[f_index][i][63:32] : cache_data[f_index][i][31:0];
                    icache_inst_out = select_upper_half ? cache_data[f_index][i][63:32] : cache_data[f_index][i][31:0];
                    $display("icache_pc = %h | select_upper_half = %b", icache_pc, icache_pc[2]);
                    icache_status.hit = 1'b1;
                    // valid_cache_data = 1'b1;
                    $display("[ICACHE] CACHE HIT | PC=%h | Index=%d | Tag=%h", icache_pc, f_index, f_tag);
                    $display("[ICACHE] CACHE HIT INSTRUCTION %h", icache_inst_out);
                    $display("[ICACHE] CACHE HIT INSTRUCTION v2 %h", icache_inst_out_v2);
                    break;
                end
            end
        end

        if (!icache_status.hit) begin
            $display("[ICACHE] CACHE MISS | PC=%h | Index=%d | Tag=%h", icache_pc, f_index, f_tag);
            icache_status.request = (!icache_status.hit && !read_request_pending);

        end
    end
    
    
    always_ff @(posedge clk) begin
        // Print Cache Debug Information
        $display("[CACHE SIZE] [SET %0d | WAY %0d]", 
                    NUM_SETS, NUM_WAYS);
        $display("\n================= CACHE DEBUG STATE =================");
        
        for (int i = 0; i < NUM_SETS; i++) begin
            for (int j = 0; j < NUM_WAYS; j++) begin
                if (cache_valid[i][j]) begin
                    $display("[SET %0d | WAY %0d] Data: %h | Tag: %h | Valid: %b", 
                    i, j, cache_data[i][j], cache_tags[i][j], cache_valid[i][j]);

                end
                end
        end
        $display("=====================================================\n");
        end
    


    // FSM Logic
    always_ff @(posedge clk) begin
        // Update I-Cache status struct
        // icache_status.in_flight <= (fsm_state != IDLE);
        // icache_status.request    <= (!valid_cache_data && !read_request_pending);
        // icache_status.done       <= cache_line_ready;

        if (reset) begin
            
            fsm_state <= IDLE;
            read_request_pending <= 0;
            m_axi_arvalid <= 0;
            m_axi_rready <= 0;
            terminate_simulation <= 0;
            fetch_pc <= icache_pc;
            cache_line_ready <= 0; // Reset cache line readiness
            // Initialize done instruction and PC
            done_instruction <= 64'b0;
            done_pc <= 64'b0;
            done_signal <= 1'b0;
            num_transfers <= 7'b0;
            current_instruction <= 64'b0;
            previous_instruction <= 64'b0;
            curr_pc <= 64'b0;
            prev_pc <= 64'b0;

                // Clear status flags
            icache_status.in_flight <= 0;
            icache_status.request    <= 0;
            icache_status.done       <= 0;
            icache_status.hit <= 0;
            
            for (int i = 0; i < NUM_SETS; i++) begin
                for (int j = 0; j < NUM_WAYS; j++) begin
                    cache_data[i][j] = 0;
                    cache_tags[i][j] = 0;
                    cache_valid[i][j] = 0;
                end
            end


        end else begin
            // Only trigger FSM if there is a cache miss
            if (!icache_status.hit) begin
                // cache_line_ready <= 0; // Mark cache line as not ready if there's a miss
                case (fsm_state)
                    IDLE: begin
                        if (!read_request_pending && m_axi_arready) begin
                            // Cache miss detected, and no pending read requests
                            fsm_state <= FETCH;
                        end else begin
                            fsm_state <= IDLE;
                        end
                    end

                    // Correct fetch_pc update
                    FETCH: begin
                        if (!read_request_pending && !m_axi_arvalid) begin
                            m_axi_araddr  <= fetch_pc;
                            m_axi_arvalid <= 1;
                            m_axi_arlen   <= 8'd7;         // 8 transfers = 64 bytes
                            m_axi_arsize  <= 3'b010;       // 8 bytes per transfer (64-bit)
                            m_axi_arburst <= 2'b10;        // INCR burst type
                    
                            $display("[ICACHE FETCH] Issued Read | PC=%h | Index=%0d | Tag=%h",
                                     fetch_pc, fetch_index, fetch_tag);
                        end 
                        else if (m_axi_arvalid && m_axi_arready) begin
                            m_axi_arvalid <= 0;
                            read_request_pending <= 1;
                            fsm_state <= WAIT_FOR_DATA;
                    
                            $display("[ICACHE FETCH] Read accepted by AXI | PC=%h", fetch_pc);
                        end
                    end
                    

                    WAIT_FOR_DATA: begin
                        
                        if (m_axi_rvalid) begin
                            m_axi_rready <= 1;
                    
                            // Shift the instruction pipeline
                            if (current_instruction != 32'b0) begin
                                previous_instruction <= current_instruction;
                                prev_pc <= curr_pc;
                            end
                    
                            current_instruction <= m_axi_rdata;
                            curr_pc <= fetch_pc;
                    
                            $display("[ICACHE WAIT_FOR_DATA] Received Transfer | Data=%h | PC=%h", m_axi_rdata, fetch_pc);
                    
                            fsm_state <= CACHE_UPDATE;
                        end else begin
                            timeout_counter <= timeout_counter + 1;
                            if (timeout_counter > 16'hFFFF) begin
                                $display("[ICACHE WAIT_FOR_DATA] Timeout reached! Halting simulation.");
                                fsm_state <= HALT;
                            end
                        end
                    end
                    
                    
                    CACHE_UPDATE: begin
                        m_axi_rready <= 0;  // Deassert ready after data received
                    
                        // Choose way to update
                        for (int i = 0; i < NUM_WAYS; i++) begin
                            if (!cache_valid[fetch_index][i]) begin
                                way_to_update = i;
                                break;
                            end
                        end
                    
                        // Fallback if all valid
                        if (way_to_update == -1)
                            way_to_update = 0;
                    
                        // Store data
                        cache_data[fetch_index][way_to_update] = current_instruction;
                        cache_tags[fetch_index][way_to_update] = fetch_tag;
                        cache_valid[fetch_index][way_to_update] = 1'b1;
                    
                        $display("[ICACHE CACHE_UPDATE] Way=%d | Addr=%h | Index=%0d | Tag=%h | Data=%h",
                                 way_to_update, fetch_pc, fetch_index, fetch_tag, current_instruction);
                    
                        // Handle line completion
                        if (m_axi_rdata == 64'b0) begin  // Using 0 data as 'done'?
                            done_instruction <= (previous_instruction[63:32] != 32'b0) 
                                                ? previous_instruction[63:32] 
                                                : previous_instruction[31:0];
                            done_pc <= curr_pc;
                            done_signal <= 1'b1;
                            cache_line_ready <= 1'b1;
                            read_request_pending <= 0;
                            num_transfers <= 0;
                            fsm_state <= IDLE;
                    
                            $display("[ICACHE] Last Transfer Complete | Done Inst=%h | PC=%h", 
                                      done_instruction, done_pc);
                        end else if (num_transfers > 0 && ((num_transfers + 1) % 8 == 0)) begin
                            fetch_pc <= fetch_pc + 8;
                            num_transfers <= num_transfers + 1;
                            read_request_pending <= 0;
                            fsm_state <= FETCH;
                    
                            $display("[ICACHE] Transition to FETCH | Transfers=%0d | Next PC=%h", 
                                      num_transfers, fetch_pc);
                        end else if (num_transfers == MAX_TRANSFERS) begin
                            cache_line_ready <= 1'b1;
                            read_request_pending <= 0;
                            num_transfers <= 0;
                            fsm_state <= IDLE;
                    
                            $display("[ICACHE] Max Transfers Reached | PC=%h", fetch_pc);
                        end else begin
                            fetch_pc <= fetch_pc + 8;
                            num_transfers <= num_transfers + 1;
                            fsm_state <= WAIT_FOR_DATA;
                    
                            $display("[ICACHE] Continuing Read | fetch_pc=%h | Transfers=%0d", 
                                      fetch_pc, num_transfers);
                        end
                    end
                    
                    
                

                    HALT: begin
                        $display("Simulation halted. ");
                        $finish;
                    end

                    default: begin
                        $display("ERROR: Undefined FSM state!");
                        fsm_state <= HALT;
                    end
                endcase
            end else begin
                cache_line_ready <= 1; // Keep cache line ready until there's a miss
            end
        end
    end

endmodule
