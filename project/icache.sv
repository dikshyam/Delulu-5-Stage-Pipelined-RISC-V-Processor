`include "control_signals_struct.svh"

module icache #(
    parameter CACHE_SIZE = 512, //512,  // ICACHE size in bytes
    parameter LINE_SIZE = 8,     // ICACHE line size in bytes
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


    // I-ICACHE Specific Outputs
    output logic [31:0] icache_inst_out,
    output logic [ADDR_WIDTH-1:0] icache_pc_out,
    // output logic valid_cache_data,
    // output logic done,
    output logic [31:0] done_instruction,
    output logic [ADDR_WIDTH-1:0] done_pc,
    output logic done_signal,
    
    // input logic icache_in_flight,
    // output logic icache_request
    // output cache_status_struct icache_status
    // output logic icache_hit,
    output logic icache_request,
    output logic icache_in_flight,
    output logic icache_hit, 
    input logic new_data_request,
    input logic arbiter_icache_grant


    // input logic icache_in_flight
);
    logic icache_hit, icache_done;
    // Aligned instruction MISS_REQUEST address (8-byte aligned)
    logic [ADDR_WIDTH-1:0] fetch_address;
    assign fetch_address = icache_pc & 64'hFFFFFFFFFFFFFFF8;  // Clear lower 3 bits

    // Selects which half (upper/lower) of the 64-bit ICACHE line to use
    logic select_upper_half;
    assign select_upper_half = icache_pc[2];

    // Holds the final selected 32-bit instruction from ICACHE
    logic [31:0] icache_inst_out_v2;


    // Internal Registers
    logic [ADDR_WIDTH-1:0] fetch_pc, curr_pc, prev_pc;
    logic read_request_pending;
    logic terminate_simulation;
    logic [15:0] timeout_counter;
    logic [7:0] num_transfers;
    logic [63:0] current_instruction, previous_instruction;

    // ICACHE Storage
    logic [DATA_WIDTH-1:0] cache_data [NUM_SETS-1:0][NUM_WAYS-1:0];
    logic [51:0] cache_tags [NUM_SETS-1:0][NUM_WAYS-1:0]; 
    logic cache_valid [NUM_SETS-1:0][NUM_WAYS-1:0];

    // Address Breakdown (Calculated Separately)
    logic [5:0] fetch_index, f_index;
    logic [51:0] fetch_tag, f_tag;
    logic signed [31:0] way_to_update;  // Declare as logic
    
    // assign icache_request = !valid_cache_data && !read_request_pending;
    // assign request = (!valid_cache_data && !read_request_pending);
    // assign done    = done;
    
    // always_ff @(posedge clk) begin
    //     if (reset) begin
    //         icache_in_flight <= 0;
    //     end else begin
    //         case (fsm_state)
    //             MISS_REQUEST, WAIT_FOR_MEMORY, FILL_CACHE_LINE: icache_in_flight <= 1;
    //             ICACHE_CHECK: icache_in_flight <= 0;
    //             default: icache_in_flight <= icache_in_flight;
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


    // Calculate MISS_REQUEST index and tag using dynamic bit ranges
    assign fetch_index = curr_pc[$clog2(NUM_SETS) + $clog2(LINE_SIZE) - 1 : $clog2(LINE_SIZE)];
    assign fetch_tag = curr_pc[ADDR_WIDTH-1 : $clog2(NUM_SETS) + $clog2(LINE_SIZE)];

    // typedef struct packed {
    //     logic miss;
    //     logic request;      // I-cache needs to make a memory request
    //     logic request_granted;
    //     logic icache_in_flight;    // A memory request is ongoing
    //     logic done;         // A cache line was successfully loaded
    //     logic hit;          // A cache hit occurred for the current pc
    // } icache_status;
// CACHE_IDLE 
//    ↓   (new request → request = 1)
//    ICACHE_CHECK 
//       ↓   (hit?)              ↓ (miss + AXI ready)
//    [CACHE_IDLE]          → MISS_REQUEST 
//                               ↓
//                        WAIT_FOR_DATA 
//                               ↓
//                        CACHE_UPDATE 
//                               ↓
//                         CACHE_IDLE
    // FSM States Definition
    typedef enum logic [2:0] {
        ICACHE_IDLE, //0
        ICACHE_CHECK,       //1 Check if instruction is in ICACHE (was ICACHE_CHECK)
        MISS_REQUEST,      //2 Issue memory request on miss (was MISS_REQUEST)
        WAIT_FOR_MEMORY,   //3 Wait for AXI memory response (was WAIT_FOR_MEMORY)
        FILL_CACHE_LINE,   //4 Store received data into ICACHE (was FILL_CACHE_LINE)
        ICACHE_HALT        //5 Simulation stop (was ICACHE_HALT)
    } fsm_state_t;


    fsm_state_t fsm_state, fsm_next_state;


    always_comb begin
        // Default outputs
        icache_hit       = 1'b0;
        icache_request   = 1'b0;
        icache_inst_out  = 32'b0;

    
        // Perform lookup ONLY during ICACHE_CHECK
        if (icache_done) begin
            for (int i = 0; i < NUM_WAYS; i++) begin
                if (cache_valid[f_index][i] && cache_tags[f_index][i] == f_tag) begin
                    icache_hit = 1'b1;
                    icache_inst_out = select_upper_half
                                        ? cache_data[f_index][i][63:32]
                                        : cache_data[f_index][i][31:0];
                    icache_pc_out = icache_pc;
                    $display("[ICACHE] HIT  | PC=%h | Index=%0d | Tag=%h", icache_pc, f_index, f_tag);
                    $display("[ICACHE] INST | %h", icache_inst_out);
                    break;
                end
            end
        end
    
        // If not a hit, trigger memory request
        if (fsm_state == ICACHE_CHECK && !icache_hit && !read_request_pending) begin
            icache_request = 1'b1;
            $display("[ICACHE] MISS | PC=%h | Index=%0d | Tag=%h", icache_pc, f_index, f_tag);
        end
    end
    
    
    
    always_ff @(posedge clk) begin
        // Print ICACHE Debug Information
        $display("[ICACHE SIZE] [SET %0d | WAY %0d]", 
                    NUM_SETS, NUM_WAYS);
        $display("\n================= ICACHE DEBUG STATE =================");
        
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
    // always_ff @(posedge clk) begin
    //     if (reset) begin
    //         fsm_state <= ICACHE_CHECK;
    //         read_request_pending <= 0;
    //         m_axi_arvalid <= 0;
    //         m_axi_rready <= 0;
    //         terminate_simulation <= 0;
    //         fetch_pc <= icache_pc;
    //         done <= 0; // Reset ICACHE line readiness
    //         // Initialize done instruction and PC
    //         done_instruction <= 64'b0;
    //         done_pc <= 64'b0;
    //         done_signal <= 1'b0;
    //         num_transfers <= 7'b0;
    //         current_instruction <= 64'b0;
    //         previous_instruction <= 64'b0;
    //         curr_pc <= 64'b0;
    //         prev_pc <= 64'b0;

    //             // Clear status flags
    //         icache_in_flight <= 0;
    //         request    <= 0;
    //         done       <= 0;
    //         // hit <= 0;
            
    //         for (int i = 0; i < NUM_SETS; i++) begin
    //             for (int j = 0; j < NUM_WAYS; j++) begin
    //                 cache_data[i][j] = 0;
    //                 cache_tags[i][j] = 0;
    //                 cache_valid[i][j] = 0;
    //             end
    //         end


    //     end else begin
    //         // Only trigger FSM if there is a ICACHE miss
    //         if (!hit) begin
    //             // done <= 0; // Mark ICACHE line as not ready if there's a miss
    //             case (fsm_state)
    //                 ICACHE_CHECK: begin
    //                     if (!read_request_pending && m_axi_arready) begin
    //                         // ICACHE miss detected, and no pending read requests
    //                         fsm_state <= MISS_REQUEST;
    //                     end else begin
    //                         fsm_state <= ICACHE_CHECK;
    //                     end
    //                 end

    //                 // Correct fetch_pc update
    //                 MISS_REQUEST: begin
    //                     if (!read_request_pending && !m_axi_arvalid) begin
    //                         m_axi_araddr  <= fetch_pc;
    //                         m_axi_arvalid <= 1;
    //                         m_axi_arlen   <= 8'd7;         // 8 transfers = 64 bytes
    //                         m_axi_arsize  <= 3'b010;       // 8 bytes per transfer (64-bit)
    //                         m_axi_arburst <= 2'b10;        // INCR burst type
                    
    //                         $display("[ICACHE MISS_REQUEST] Issued Read | PC=%h | Index=%0d | Tag=%h",
    //                                  fetch_pc, fetch_index, fetch_tag);
    //                     end 
    //                     else if (m_axi_arvalid && m_axi_arready) begin
    //                         m_axi_arvalid <= 0;
    //                         read_request_pending <= 1;
    //                         fsm_state <= WAIT_FOR_MEMORY;
                    
    //                         $display("[ICACHE MISS_REQUEST] Read accepted by AXI | PC=%h", fetch_pc);
    //                     end
    //                 end
                    

    //                 WAIT_FOR_MEMORY: begin
                        
    //                     if (m_axi_rvalid) begin
    //                         m_axi_rready <= 1;
                    
    //                         // Shift the instruction pipeline
    //                         if (current_instruction != 32'b0) begin
    //                             previous_instruction <= current_instruction;
    //                             prev_pc <= curr_pc;
    //                         end
                    
    //                         current_instruction <= m_axi_rdata;
    //                         curr_pc <= fetch_pc;
                    
    //                         $display("[ICACHE WAIT_FOR_MEMORY] Received Transfer | Data=%h | PC=%h", m_axi_rdata, fetch_pc);
                    
    //                         fsm_state <= FILL_CACHE_LINE;
    //                     end else begin
    //                         timeout_counter <= timeout_counter + 1;
    //                         if (timeout_counter > 16'hFFFF) begin
    //                             $display("[ICACHE WAIT_FOR_MEMORY] Timeout reached! Halting simulation.");
    //                             fsm_state <= ICACHE_HALT;
    //                         end
    //                     end
    //                 end
                    
                    
    //                 FILL_CACHE_LINE: begin
    //                     m_axi_rready <= 0;  // Deassert ready after data received
                    
    //                     // Choose way to update
    //                     for (int i = 0; i < NUM_WAYS; i++) begin
    //                         if (!cache_valid[fetch_index][i]) begin
    //                             way_to_update = i;
    //                             break;
    //                         end
    //                     end
                    
    //                     // Fallback if all valid
    //                     if (way_to_update == -1)
    //                         way_to_update = 0;
                    
    //                     // Store data
    //                     cache_data[fetch_index][way_to_update] = current_instruction;
    //                     cache_tags[fetch_index][way_to_update] = fetch_tag;
    //                     cache_valid[fetch_index][way_to_update] = 1'b1;
                    
    //                     $display("[ICACHE FILL_CACHE_LINE] Way=%d | Addr=%h | Index=%0d | Tag=%h | Data=%h",
    //                              way_to_update, fetch_pc, fetch_index, fetch_tag, current_instruction);
                    
    //                     // Handle line completion
    //                     if (m_axi_rdata == 64'b0) begin  // Using 0 data as 'done'?
    //                         done_instruction <= (previous_instruction[63:32] != 32'b0) 
    //                                             ? previous_instruction[63:32] 
    //                                             : previous_instruction[31:0];
    //                         done_pc <= curr_pc;
    //                         done_signal <= 1'b1;
    //                         done <= 1'b1;
    //                         read_request_pending <= 0;
    //                         num_transfers <= 0;
    //                         fsm_state <= ICACHE_CHECK;
                    
    //                         $display("[ICACHE] Last Transfer Complete | Done Inst=%h | PC=%h", 
    //                                   done_instruction, done_pc);
    //                     end else if (num_transfers > 0 && ((num_transfers + 1) % 8 == 0)) begin
    //                         fetch_pc <= fetch_pc + 8;
    //                         num_transfers <= num_transfers + 1;
    //                         read_request_pending <= 0;
    //                         fsm_state <= MISS_REQUEST;
                    
    //                         $display("[ICACHE] Transition to MISS_REQUEST | Transfers=%0d | Next PC=%h", 
    //                                   num_transfers, fetch_pc);
    //                     end else if (num_transfers == MAX_TRANSFERS) begin
    //                         done <= 1'b1;
    //                         read_request_pending <= 0;
    //                         num_transfers <= 0;
    //                         fsm_state <= ICACHE_CHECK;
                    
    //                         $display("[ICACHE] Max Transfers Reached | PC=%h", fetch_pc);
    //                     end else begin
    //                         fetch_pc <= fetch_pc + 8;
    //                         num_transfers <= num_transfers + 1;
    //                         fsm_state <= WAIT_FOR_MEMORY;
                    
    //                         $display("[ICACHE] Continuing Read | fetch_pc=%h | Transfers=%0d", 
    //                                   fetch_pc, num_transfers);
    //                     end
    //                 end
                    
                    
                

    //                 ICACHE_HALT: begin
    //                     $display("Simulation halted. ");
    //                     $finish;
    //                 end

    //                 default: begin
    //                     $display("ERROR: Undefined FSM state!");
    //                     fsm_state <= ICACHE_HALT;
    //                 end
    //             endcase
    //         end else begin
    //             done <= 1; // Keep ICACHE line ready until there's a miss
    //         end
    //     end
    // end

    // always_ff @(posedge clk) begin
    //     if (reset) begin
    //         fsm_state <= ICACHE_CHECK;
    //     end else begin
    //         fsm_state <= fsm_next_state;
    //     end
    // end
    
    always_ff @(posedge clk) begin
        if (reset) begin
            fsm_state <= ICACHE_IDLE;
            read_request_pending <= 1'b0;
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
            terminate_simulation <= 1'b0;
    
            fetch_pc <= icache_pc;
            // icache_done <= 1'b0;
    
            done_instruction <= 64'b0;
            done_pc <= 64'b0;
            done_signal <= 1'b0;
    
            num_transfers <= 7'b0;
            current_instruction <= 64'b0;
            previous_instruction <= 64'b0;
            curr_pc <= 64'b0;
            prev_pc <= 64'b0;
            
            icache_in_flight <= 1'b0;
            // request   <= 1'b0;
            icache_done      <= 1'b0;
            // hit       <= 1'b0;
    
            for (int i = 0; i < NUM_SETS; i++) begin
                for (int j = 0; j < NUM_WAYS; j++) begin
                    cache_data[i][j] = 0;
                    cache_tags[i][j] = 0;
                    cache_valid[i][j] = 0;
                end
            end
        end else begin
            // fsm_state <= fsm_next_state;
    
            // --- Optional: add status tracking ---    
            case (fsm_state)
                ICACHE_IDLE: begin
                    // Maybe optional logic to enter ICACHE_CHECK when needed
                    if (new_data_request) begin
                        fsm_state <= ICACHE_CHECK;                    
                    end else begin
                        fsm_state <= ICACHE_IDLE;
                    end
    
                end
    
                ICACHE_CHECK: begin
                    if (icache_hit) begin
                        fsm_state <= ICACHE_IDLE;
                    end else if (arbiter_icache_grant) begin
                        fsm_state <= MISS_REQUEST;
                        icache_in_flight <= (fsm_next_state != ICACHE_CHECK);
                        icache_done <= 0;
                    end
                end
                
                MISS_REQUEST: begin
                    if (!read_request_pending && !m_axi_arvalid) begin
                        m_axi_araddr  <= fetch_pc;
                        m_axi_arvalid <= 1;
                        m_axi_arlen   <= 8'd7;
                        m_axi_arsize  <= 3'b010;
                        m_axi_arburst <= 2'b10;
                        $display("[ICACHE MISS_REQUEST] Issued Read | PC=%h | Index=%0d | Tag=%h",
                                 fetch_pc, fetch_index, fetch_tag);
                    end else if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 0; 
                        read_request_pending <= 1;
                        fsm_state <= WAIT_FOR_MEMORY;
                        $display("[ICACHE MISS_REQUEST] Read accepted by AXI | PC=%h", fetch_pc);
                    end
                end
    
                WAIT_FOR_MEMORY: begin
                    if (m_axi_rvalid) begin
                        m_axi_rready <= 1;
                        
                        if (current_instruction != 32'b0) begin
                            previous_instruction <= current_instruction;
                            prev_pc <= curr_pc;
                        end
    
                        current_instruction <= m_axi_rdata;
                        curr_pc <= fetch_pc;
                        fsm_state <= FILL_CACHE_LINE;
                        $display("[ICACHE WAIT_FOR_MEMORY] Received Transfer | Data=%h | PC=%h", m_axi_rdata, fetch_pc);
                    end
                    // else begin
                    //     timeout_counter <= timeout_counter + 1;
                    //     if (timeout_counter > 16'hFFFF) begin
                    //         $display("[ICACHE WAIT_FOR_MEMORY] Timeout reached! Halting simulation.");
                    //         fsm_state <= ICACHE_HALT;
                    //     end
                    // end
                end
    
                FILL_CACHE_LINE: begin
                    m_axi_rready <= 0;
    
                    // Find an invalid way to update
                    way_to_update = -1;
                    for (int i = 0; i < NUM_WAYS; i++) begin
                        if (!cache_valid[fetch_index][i]) begin
                            way_to_update = i;
                            break;
                        end
                    end
                    if (way_to_update == -1) way_to_update = 0;
    
                    cache_data[fetch_index][way_to_update] = current_instruction;
                    cache_tags[fetch_index][way_to_update] = fetch_tag;
                    cache_valid[fetch_index][way_to_update] = 1'b1;
    
                    $display("[ICACHE FILL_CACHE_LINE] Way=%d | Addr=%h | Index=%0d | Tag=%h | Data=%h",
                             way_to_update, fetch_pc, fetch_index, fetch_tag, current_instruction);
                    
                    // Only set done signal if actual payload is 0 (as per your original logic)
                    if (m_axi_rdata == 64'b0) begin
                        done_instruction <= (previous_instruction[63:32] != 32'b0) 
                                        ? previous_instruction[63:32] 
                                        : previous_instruction[31:0];
                        done_pc         <= prev_pc;
                        done_signal     <= 1'b1;
                        $display("[ICACHE DONE] Sentinel transfer detected, done_instruction=%h, done_pc=%h",
                                done_instruction, done_pc);
                    end

                    // Completion cases
                    // if (m_axi_rdata == 64'b0) begin
                    //     done_instruction <= (previous_instruction[63:32] != 32'b0) 
                    //         ? previous_instruction[63:32] 
                    //         : previous_instruction[31:0];
                    //     done_pc <= curr_pc;
                    //     done_signal <= 1'b1;
                    //     icache_done <= 1'b1;
                    //     read_request_pending <= 0;
                    //     num_transfers <= 0;
                    // end else if (num_transfers > 0 && ((num_transfers + 1) % 8 == 0)) begin
                    //     fetch_pc <= fetch_pc + 8;
                    //     num_transfers <= num_transfers + 1;
                    //     read_request_pending <= 0;
                    //     icache_done <= 1'b1;
                    // end else if (num_transfers == MAX_TRANSFERS) begin
                    //     icache_done <= 1'b1;
                    //     read_request_pending <= 0;
                    //     num_transfers <= 0;
                    // end else begin
                    //     fetch_pc <= fetch_pc + 8;
                    //     num_transfers <= num_transfers + 1;
                    // end
                    $display("[ICACHE FILL_CACHE_LINE] Way=%d | PC=%h | Index=%0d | Tag=%h | Data=%h", way_to_update, fetch_pc, fetch_index, fetch_tag, current_instruction);

                    if (m_axi_rlast & (num_transfers ==7)) begin //num transfers starts at 0
                        $display("[ICACHE] Last AXI Transfer (RLAST=1) | Transfers=%0d", num_transfers);
                        icache_done <= 1'b1;
                        read_request_pending <= 0;
                        num_transfers <= 0;
                        fsm_state <= ICACHE_IDLE;
                    end else begin
                        fetch_pc <= fetch_pc + 8;
                        num_transfers <= num_transfers + 1;
                        fsm_state <= WAIT_FOR_MEMORY;
                end
            end
    
                ICACHE_HALT: begin
                    $display("[ICACHE HALT] Halting simulation...");
                    $finish;
                end
    
            endcase
        end
    end
    
    // always_comb begin
    //     // fsm_next_state = fsm_state; // default to stay
    
    //     case (fsm_state)
    
    //         ICACHE_IDLE: begin
    //             // Maybe optional logic to enter ICACHE_CHECK when needed
    //             if (new_data_request) begin
    //                 fsm_next_state = ICACHE_CHECK;                    
    //             end else begin
    //                 fsm_next_state = ICACHE_IDLE;
    //             end

    //         end
    
    //         ICACHE_CHECK: begin
    //             if (icache_hit) begin
    //                 fsm_next_state = ICACHE_IDLE;
    //             end else if (arbiter_icache_grant) begin
    //                 fsm_next_state = MISS_REQUEST;
    //             end
    //         end
    
    //         MISS_REQUEST: begin
    //             if (m_axi_arvalid && m_axi_arready) begin
    //                 fsm_next_state = WAIT_FOR_MEMORY;
    //             end else begin
    //                 fsm_next_state = MISS_REQUEST;
    //             end
    //         end
    
    //         WAIT_FOR_MEMORY: begin
    //             if (m_axi_rvalid) begin
    //                 fsm_next_state = FILL_CACHE_LINE;
    //             end else begin
    //                 fsm_next_state = WAIT_FOR_MEMORY;
    //             end

    //         end
    
    //         FILL_CACHE_LINE: begin
    //             if (icache_done) begin
    //                 fsm_next_state = ICACHE_CHECK; // After storing, recheck
    //             end else begin
    //                 fsm_next_state = WAIT_FOR_MEMORY;
    //             end

    //             end
    
    //         ICACHE_HALT: begin
    //             fsm_next_state = ICACHE_HALT;
    //         end
    
    //         default: begin
    //             fsm_next_state = ICACHE_HALT;
    //         end
    //     endcase
    // end
    
    


endmodule
