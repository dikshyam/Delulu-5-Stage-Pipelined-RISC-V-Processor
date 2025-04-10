module icache #(
    parameter CACHE_SIZE = 512,  // Cache size in bytes
    parameter LINE_SIZE = 4,     // Cache line size in bytes
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
    input  logic m_axi_arready,

    // AXI Interface - Read Data
    input  logic [DATA_WIDTH-1:0] m_axi_rdata,
    input  logic m_axi_rvalid,
    input  logic m_axi_rlast,
    output logic m_axi_rready,

    // I-Cache Specific Outputs
    output logic [31:0] icache_inst_out,
    output logic valid_cache_data,
    output logic cache_line_ready,
    output logic [31:0] done_instruction,
    output logic [ADDR_WIDTH-1:0] done_pc,
    output logic done_signal,
    input logic axi_icache_grant,
    output logic icache_request
);

    
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
    
    assign icache_request = (fsm_state == FETCH) && !read_request_pending;

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
        if (cache_line_ready) begin
            valid_cache_data = 1'b0;
            icache_inst_out = 32'b0;
            
            for (int i = 0; i < NUM_WAYS; i++) begin
                if (cache_valid[f_index][i] && cache_tags[f_index][i] == f_tag) begin
                    icache_inst_out = fetch_toggle ? cache_data[f_index][i][63:32] : cache_data[f_index][i][31:0];
                    valid_cache_data = 1'b1;
                    $display("[ICACHE] CACHE HIT | PC=%h | Index=%d | Tag=%h", icache_pc, f_index, f_tag);
                    $display("[ICACHE] CACHE HIT INSTRUCTION %h", icache_inst_out);
                    break;
                end
            end
        end

        if (!valid_cache_data) begin
            $display("[ICACHE] CACHE MISS | PC=%h | Index=%d | Tag=%h", icache_pc, f_index, f_tag);
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
            for (int i = 0; i < NUM_SETS; i++) begin
                for (int j = 0; j < NUM_WAYS; j++) begin
                    cache_data[i][j] = 0;
                    cache_tags[i][j] = 0;
                    cache_valid[i][j] = 0;
                end
            end


        end else begin
            // Only trigger FSM if there is a cache miss
            if (!valid_cache_data) begin
                cache_line_ready <= 0; // Mark cache line as not ready if there's a miss
                case (fsm_state)
                    IDLE: begin
                        if (!cache_line_ready && !read_request_pending && m_axi_arready) begin
                            // Cache miss detected, and no pending read requests
                            fsm_state <= FETCH;
                        end else begin
                            fsm_state <= IDLE;
                        end
                    end

                    // Correct fetch_pc update
                    FETCH: begin
                        // if (!read_request_pending && !m_axi_arvalid && m_axi_arready) begin
                        if (!read_request_pending && axi_icache_grant) begin

                            m_axi_araddr <= fetch_pc;
                            m_axi_arvalid <= 1;
                            m_axi_arlen <= 7;    // 8 transfers (64 bytes)
                            m_axi_arsize <= 3'b010;   // 64-bit transfers
                            m_axi_arburst <= 2'b10;   // Incrementing burst
                            // read_request_pending <= 1;
                            // fsm_state <= WAIT_FOR_DATA;
                            $display("[DEBUG FETCH] Issued Read | PC=%h | Index=%0d | Tag=%h", fetch_pc, fetch_index, fetch_tag);
                        end else if (m_axi_arvalid && m_axi_arready) begin
                            m_axi_arvalid <= 0;
                            read_request_pending <= 1;
                            fsm_state <= WAIT_FOR_DATA;
                            $display("[ICACHE] Read accepted by AXI | PC=%h", fetch_pc);
                        end
                    end

                    WAIT_FOR_DATA: begin
                        if (m_axi_rvalid) begin
                            m_axi_rready <= 1;
                            if (current_instruction != 32'b0) begin
                                previous_instruction <= current_instruction;
                                prev_pc <= curr_pc;
                            end
                            current_instruction <= m_axi_rdata;  // Store current transfer data
                            curr_pc <= fetch_pc;  // Store current PC for tracking
                            
                            // Debugging display
                            $display("[ICACHE] Received Transfer | Data=%h | PC=%h", m_axi_rdata, fetch_pc);
                    
                            // Transition to CACHE_UPDATE for further processing
                            fsm_state <= CACHE_UPDATE;
                        end else begin
                            timeout_counter <= timeout_counter + 1;
                            if (timeout_counter > 16'hFFFF) begin
                                fsm_state <= HALT;
                            end
                        end
                    end
                    
                    CACHE_UPDATE: begin
                        m_axi_rready <= 0;  // Deassert ready for the current cycle
                    
                        // Determine which way to update
                        for (int i = 0; i < NUM_WAYS; i++) begin
                            if (!cache_valid[fetch_index][i]) begin
                                way_to_update = i;
                                break;
                            end
                        end
                    
                        // Default to way 0 if all ways are valid (consider LRU replacement later)
                        if (way_to_update == -1) begin
                            way_to_update = 0;
                        end
                    
                        // Update the cache with fetched data
                        cache_data[fetch_index][way_to_update] = current_instruction;
                        cache_tags[fetch_index][way_to_update] = fetch_tag;
                        cache_valid[fetch_index][way_to_update] = 1'b1;
                    
                        // Debugging display statements
                        $display("[CACHE UPDATE] Way=%d | Addr=%h | Index=%d | Tag=%h | Data=%h", 
                                 way_to_update, fetch_pc, fetch_index, fetch_tag, current_instruction);
                    
                        // Handle final transfer or completion of cache line
                        // Condition to return to FETCH if num_transfers is a multiple of 8
                        

                        if (m_axi_rdata == 64'b0) begin
                            if (previous_instruction[63:32]!=32'b0) begin
                                done_instruction <= previous_instruction[63:32];
                            end else begin
                                done_instruction <= previous_instruction[31:0];
                            end
                            done_pc <= curr_pc;
                            done_signal <= 1'b1;
                            cache_line_ready <= 1'b1;
                            read_request_pending <= 0;
                            // valid_cache_data <= 1;
                            num_transfers <= 0;  // Reset transfer counter
                            fsm_state <= IDLE;   // Transition to IDLE state
                            $display("[ICACHE] Last Transfer Detected (RLAST) | Done Inst=%h | PC=%h | Curr Fetch PC=%h", 
                                     done_instruction, done_pc, fetch_pc);
                        end else if (num_transfers > 0 && ((num_transfers+1) % 8 == 0) && (m_axi_rdata != 64'b0)) begin
                            m_axi_arvalid <= 0;
                            read_request_pending <= 0;
                            fetch_pc <= fetch_pc + 8;
                            num_transfers <= num_transfers + 1;
                            $display("[CACHE UPDATE] Transitioning to FETCH | Transfers=%0d | fetch_pc=%h", num_transfers, fetch_pc);
                            if (!m_axi_arvalid && m_axi_arready) begin
                                fsm_state <= FETCH; 
                            end
                        end else if (num_transfers == MAX_TRANSFERS) begin
                            cache_line_ready <= 1'b1;
                            num_transfers <= 0;  // Reset transfer counter
                            fsm_state <= IDLE;   // Transition to IDLE state
                            read_request_pending <= 0;
                            $display("[ICACHE] Max Transfers Reached | PC=%h", fetch_pc);
                        end else begin
                            // Continue fetching the next instruction pair
                            fetch_pc <= fetch_pc + 8;  // Increment by 8 bytes
                            num_transfers <= num_transfers + 1;
                            // if (m_axi_arvalid && m_axi_arready) begin
                            //     m_axi_arvalid <= 0;
                            //     fsm_state <= WAIT_FOR_DATA;
                            // end
                            fsm_state <= WAIT_FOR_DATA;  // Transition back to WAIT_FOR_DATA
                            $display("[CACHE UPDATE] Updated fetch_pc: %h | Transfers=%0d", fetch_pc, num_transfers);
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
