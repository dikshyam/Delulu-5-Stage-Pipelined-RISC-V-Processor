// include "control_signals_struct.svh"

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
    output logic [31:0] icache_inst_out_next,
    output logic [ADDR_WIDTH-1:0] icache_pc_out_next,
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
    output logic icache_result_ready, 
    input logic new_data_request,
    input logic arbiter_icache_grant,
    input logic jump_mux,
    input logic icache_resp_ack

    // input logic icache_in_flight
);
    // logic icache_hit, icache_done, icache_result_ready;
    // Aligned instruction MISS_REQUEST address (8-byte aligned)
    // logic [ADDR_WIDTH-1:0] fetch_address;
    // assign fetch_address = icache_pc & 64'hFFFFFFFFFFFFFFF8;  // Clear lower 3 bits

    // Selects which half (upper/lower) of the 64-bit ICACHE line to use
    // logic select_upper_half;
    // assign select_upper_half = icache_pc[2];

    // Holds the final selected 32-bit instruction from ICACHE
    // logic [31:0] icache_inst_out_v2;
    // localparam BLOCK_OFFSET_WIDTH = $clog2(LINE_SIZE);          // offset within a cache line
    // localparam SET_INDEX_WIDTH    = $clog2(NUM_SETS);           // which set (cache line) it goes in
    // localparam TAG_WIDTH          = ADDR_WIDTH - BLOCK_OFFSET_WIDTH - SET_INDEX_WIDTH;
    
    // localparam BLOCK_OFFSET_WIDTH = $clog2(64);  // = 6


        // // Internal Registers
        // logic [ADDR_WIDTH-1:0] fetch_pc, curr_pc, prev_pc;
        // logic read_request_pending;
        // logic terminate_simulation;
        // logic [15:0] timeout_counter;
        // logic [7:0] num_transfers;
        // logic [63:0] current_instruction, previous_instruction;

        // // ICACHE Storage
        // logic [DATA_WIDTH-1:0] cache_data [NUM_SETS-1:0][NUM_WAYS-1:0];
        // logic [51:0] cache_tags [NUM_SETS-1:0][NUM_WAYS-1:0]; 
        // logic cache_valid [NUM_SETS-1:0][NUM_WAYS-1:0];

        // // Address Breakdown (Calculated Separately)
        // logic [5:0] fetch_index, f_index;
        // logic [51:0] fetch_tag, f_tag;
        // logic signed [31:0] way_to_update;  // Declare as logic
        
        // assign fetch_index = fetch_pc[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
        // assign fetch_tag   = fetch_pc[ADDR_WIDTH-1 -: TAG_WIDTH];
        

        // logic [ADDR_WIDTH-1:0] line_base_addr;
        // logic [BLOCK_OFFSET_WIDTH-1:0] word_offset;

        // logic [ADDR_WIDTH-1:0] aligned_pc;
        // assign aligned_pc = {icache_pc[ADDR_WIDTH-1:BLOCK_OFFSET_WIDTH], {BLOCK_OFFSET_WIDTH{1'b0}}};

        
        // // assign f_index = aligned_pc[$clog2(NUM_SETS) + $clog2(LINE_SIZE) - 1 : $clog2(LINE_SIZE)];
        // // assign f_tag   = aligned_pc[ADDR_WIDTH-1 : $clog2(NUM_SETS) + $clog2(LINE_SIZE)];
        // assign f_index = aligned_pc[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
        // assign f_tag   = aligned_pc[ADDR_WIDTH-1 -: TAG_WIDTH];
        
        

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

    logic icache_hit, icache_done, icache_result_ready;

    // Aligned instruction MISS_REQUEST address (8-byte aligned)
    // logic [ADDR_WIDTH-1:0] fetch_address;
    // assign fetch_address = icache_pc & 64'hFFFFFFFFFFFFFFF8;  // Clear lower 3 bits

    // Selects which half (upper/lower) of the 64-bit ICACHE line to use
    logic select_upper_half;
    assign select_upper_half = icache_pc[2];

    // Holds the final selected 32-bit instruction from ICACHE
    logic [31:0] icache_inst_out_v2;

    // Derived address width breakdown
    // localparam BLOCK_OFFSET_WIDTH = $clog2(LINE_SIZE);                  // Offset within a cache line
    // localparam SET_INDEX_WIDTH    = $clog2(NUM_SETS);                   // Which set it maps to
    // localparam TAG_WIDTH          = ADDR_WIDTH - SET_INDEX_WIDTH - BLOCK_OFFSET_WIDTH;
    localparam BLOCK_OFFSET_WIDTH = $clog2(LINE_SIZE * (DATA_WIDTH / 32));
    localparam SET_INDEX_WIDTH    = $clog2(NUM_SETS);
    localparam TAG_WIDTH          = ADDR_WIDTH - SET_INDEX_WIDTH - BLOCK_OFFSET_WIDTH;
    
    // Internal Registers
    logic [ADDR_WIDTH-1:0] fetch_pc, curr_pc, prev_pc;
    logic read_request_pending;
    logic terminate_simulation;
    logic [15:0] timeout_counter;
    logic [7:0] num_transfers;
    logic [63:0] current_instruction, previous_instruction;

    // ICACHE Storage
    // logic [DATA_WIDTH-1:0] cache_data [NUM_SETS-1:0][NUM_WAYS-1:0];
    // logic [LINE_SIZE*8-1:0] cache_data [NUM_SETS-1:0][NUM_WAYS-1:0];
    logic [LINE_SIZE * DATA_WIDTH - 1 : 0] cache_data [NUM_SETS-1:0][NUM_WAYS-1:0];

    logic [TAG_WIDTH-1:0]  cache_tags [NUM_SETS-1:0][NUM_WAYS-1:0]; 
    logic                  cache_valid[NUM_SETS-1:0][NUM_WAYS-1:0];

    logic [ADDR_WIDTH-1:0] line_addr;
    logic [SET_INDEX_WIDTH-1:0] line_index;
    logic [TAG_WIDTH-1:0]       line_tag;
    // Address Breakdown
    logic [SET_INDEX_WIDTH-1:0] fetch_index, f_index;
    logic [TAG_WIDTH-1:0]       fetch_tag, f_tag;
    logic signed [31:0] way_to_update;

    // Extract index and tag from fetch_pc (used for storing incoming lines)
    assign fetch_index = aligned_pc[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
    assign fetch_tag   = aligned_pc[ADDR_WIDTH-1 -: TAG_WIDTH];

    // Extract index and tag from aligned current PC (used for hit check)
    logic [ADDR_WIDTH-1:0] aligned_pc, icache_pc_out;
    logic [31:0] icache_inst_out;
    localparam CACHE_LINE_ADDR_WIDTH = $clog2(LINE_SIZE * DATA_WIDTH / 8);  // 64B = 6 bits
    assign aligned_pc = {icache_pc[ADDR_WIDTH-1:CACHE_LINE_ADDR_WIDTH], {CACHE_LINE_ADDR_WIDTH{1'b0}}};

    // assign aligned_pc = {icache_pc[ADDR_WIDTH-1:BLOCK_OFFSET_WIDTH], {BLOCK_OFFSET_WIDTH{1'b0}}};
    assign f_index     = aligned_pc[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
    assign f_tag       = aligned_pc[ADDR_WIDTH-1 -: TAG_WIDTH];

    // Optional: for exact block address comparison during hit
    logic [ADDR_WIDTH-1:0] line_base_addr;
    logic [BLOCK_OFFSET_WIDTH-1:0] word_offset;

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

    logic [DATA_WIDTH-1:0] icache_line_buffer [0:LINE_SIZE-1];
    logic [LINE_SIZE * DATA_WIDTH - 1 : 0] packed_line;


    always_comb begin
        // if (jump_mux) begin
        //     icache_hit       = 1'b0;
        //     icache_request   = 1'b0;
        //     icache_inst_out  = 32'b0;
        //     icache_pc_out = 64'b0;
        // end
        // Default outputs
        if (new_data_request) begin
            icache_hit       = 1'b0;
            icache_request   = 1'b0;
            icache_inst_out  = 32'b0;
            icache_pc_out = 64'b0;
            
            aligned_pc = {icache_pc[ADDR_WIDTH-1:CACHE_LINE_ADDR_WIDTH], {CACHE_LINE_ADDR_WIDTH{1'b0}}};

            // assign aligned_pc = {icache_pc[ADDR_WIDTH-1:BLOCK_OFFSET_WIDTH], {BLOCK_OFFSET_WIDTH{1'b0}}};
            f_index     = aligned_pc[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
            f_tag       = aligned_pc[ADDR_WIDTH-1 -: TAG_WIDTH];
            word_offset = icache_pc[BLOCK_OFFSET_WIDTH + 1 : 2];  // e.g., 0–7 for 32-bit words in 64-bit lines
        
            if (icache_done) begin
                for (int i = 0; i < NUM_WAYS; i++) begin
                    if (cache_valid[f_index][i] &&
                        cache_tags[f_index][i] == f_tag) begin
        
                        icache_inst_out = cache_data[f_index][i][word_offset * 32 +: 32];
                        icache_pc_out   = icache_pc;
                        icache_hit      = 1'b1;
        
                        // $display("[ICACHE] HIT  | PC=%h | Index=%0d | Tag=%h | WordOffset=%0d", 
                                //  icache_pc, f_index, f_tag, word_offset);
                        // $display("[ICACHE] INST | %h", icache_inst_out);
                        break;
                    end
                end
            end
        
            if (fsm_state == ICACHE_CHECK && !icache_hit && !read_request_pending) begin
                icache_request = 1'b1;
                // $display("[ICACHE] MISS | PC=%h | Index=%0d | Tag=%h", icache_pc, f_index, f_tag);
            end
        end
    end
    
    
    // always_ff @(posedge clk) begin
    //     $display("[ICACHE SIZE] [SETS: %0d | WAYS: %0d | LINE_SIZE: %0d x %0d bits]", 
    //              NUM_SETS, NUM_WAYS, LINE_SIZE, DATA_WIDTH);
    //     $display("\n================= ICACHE DEBUG STATE =================");
        
    //     for (int i = 0; i < NUM_SETS; i++) begin
    //         for (int j = 0; j < NUM_WAYS; j++) begin
    //             if (cache_valid[i][j]) begin
    //                 $display("[SET %0d | WAY %0d] Tag: %h | Valid: %b", 
    //                          i, j, cache_tags[i][j], cache_valid[i][j]);
    //                 for (int k = 0; k < (LINE_SIZE * 2); k++) begin
    //                     $display("  >> Instr[%0d]: %h", 
    //                              k, cache_data[i][j][k*32 +: 32]);
    //                 end
    //             end
    //         end
    //     end
    
    //     $display("=====================================================\n");
    // end
    
    
    
    always_ff @(posedge clk) begin
        if (reset) begin
            fsm_state <= ICACHE_IDLE;
            read_request_pending <= 1'b0;
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
            terminate_simulation <= 1'b0;
    
            fetch_pc <= 64'b0;
            // icache_done <= 1'b0;
            // packed_line <= 0;
    
            done_instruction <= 64'b0;
            done_pc <= 64'b0;
            done_signal <= 1'b0;
    
            num_transfers <= 7'b0;
            current_instruction <= 64'b0;
            previous_instruction <= 64'b0;
            curr_pc <= 64'b0;
            prev_pc <= 64'b0;
            icache_result_ready <= 0;
            icache_in_flight <= 1'b0;
            // request   <= 1'b0;
            icache_done      <= 1'b0;
            // hit       <= 1'b0;
            icache_inst_out_next <= 32'b0;
            icache_pc_out_next <= 64'b0;

            for (int i = 0; i < LINE_SIZE; i++) begin
                icache_line_buffer[i] = '0;
            end
            
    
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
                        icache_result_ready <= 0;  

                    end else begin
                        if (icache_resp_ack) begin
                            icache_result_ready <= 0;  
                        end
                        fsm_state <= ICACHE_IDLE;
                    end
    
                end
    
                ICACHE_CHECK: begin
                    if (icache_hit && icache_done) begin
                        // if (!jump_mux) begin
                        icache_result_ready <= 1; 
                        icache_inst_out_next <= icache_inst_out;
                        icache_pc_out_next <= icache_pc_out;
                        fsm_state <= ICACHE_IDLE;

                        // end else begin
                            // icache_result_ready <= 0; 
                            // icache_inst_out_next <= 0;
                            // icache_pc_out_next <= 0;
                        // end
                    end else if (arbiter_icache_grant) begin
                        fsm_state <= MISS_REQUEST;
                        icache_in_flight <= (fsm_next_state != ICACHE_CHECK);
                        icache_done <= 0;
                        // fetch_pc <= {icache_pc[ADDR_WIDTH-1:BLOCK_OFFSET_WIDTH], {BLOCK_OFFSET_WIDTH{1'b0}}};    
                        fetch_pc <= {icache_pc[ADDR_WIDTH-1:CACHE_LINE_ADDR_WIDTH], {CACHE_LINE_ADDR_WIDTH{1'b0}}};
                        
                    end
                end
                
                MISS_REQUEST: begin
                    if (!read_request_pending && !m_axi_arvalid) begin
                        // fetch_pc <= {icache_pc[ADDR_WIDTH-1:CACHE_LINE_ADDR_WIDTH], {CACHE_LINE_ADDR_WIDTH{1'b0}}};
                        m_axi_arvalid <= 1;
                        m_axi_arlen   <= 8'd7;
                        m_axi_arsize  <= 3'b011;
                        m_axi_arburst <= 2'b10;

                        m_axi_araddr  <= fetch_pc;

                        // $display("[ICACHE MISS_REQUEST] Issued Read | PC=%h | Index=%0d | Tag=%h",
                                //  fetch_pc, fetch_index, fetch_tag);
                    end else if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 0; 
                        read_request_pending <= 1;
                        num_transfers <= 0;
                        fsm_state <= WAIT_FOR_MEMORY;
                        m_axi_rready <= 1;
                        // $display("[ICACHE MISS_REQUEST] Read accepted by AXI | PC=%h", fetch_pc);
                    end
                end
    
                // WAIT_FOR_MEMORY: begin
                //     if (m_axi_rvalid) begin
                //         m_axi_rready <= 1;
                        
                //         if (current_instruction != 32'b0) begin
                //             previous_instruction <= current_instruction;
                //             prev_pc <= curr_pc;
                //         end
    
                //         current_instruction <= m_axi_rdata;
                //         curr_pc <= fetch_pc;
                //         fsm_state <= FILL_CACHE_LINE;
                //         // $display("[ICACHE WAIT_FOR_MEMORY] Received Transfer | Data=%h | PC=%h", m_axi_rdata, fetch_pc);
                //     end
                //     // else begin
                //     //     timeout_counter <= timeout_counter + 1;
                //     //     if (timeout_counter > 16'hFFFF) begin
                //     //         // $display("[ICACHE WAIT_FOR_MEMORY] Timeout reached! Halting simulation.");
                //     //         fsm_state <= ICACHE_HALT;
                //     //     end
                //     // end
                // end
                WAIT_FOR_MEMORY: begin
                    
                    if (m_axi_rvalid) begin
                        
                
                        // Store the incoming AXI data burst into the buffer
                        icache_line_buffer[num_transfers] <= m_axi_rdata;
                        if (m_axi_rlast || num_transfers == LINE_SIZE) begin
                            m_axi_rready <= 0;
                            fsm_state <= FILL_CACHE_LINE;
                        end
                        // $display("[ICACHE WAIT_FOR_MEMORY] Received Transfer #%0d | Data=%h", num_transfers, m_axi_rdata);
                        // $display("    >> Storing burst[%0d] = %h", num_transfers, m_axi_rdata);

                        num_transfers <= num_transfers + 1;
                        fetch_pc <= fetch_pc + 8;
                
                        
                    end
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
                
                    // Pack the full burst into a single cache line
                    for (int j = 0; j < LINE_SIZE; j++) begin
                        packed_line[j*DATA_WIDTH +: DATA_WIDTH] = icache_line_buffer[j];
                    end
                
                    // Store into the cache
                    cache_data[fetch_index][way_to_update] = packed_line;
                    cache_tags[fetch_index][way_to_update] = fetch_tag;
                    cache_valid[fetch_index][way_to_update] = 1'b1;
                
                    icache_done <= 1'b1;
                    read_request_pending <= 0;
                    icache_in_flight <= 0;
                    num_transfers <= 0;
                    fsm_state <= ICACHE_IDLE;
                end
                
            
    
                // ICACHE_HALT: begin
                //     // $display("[ICACHE HALT] Halting simulation...");
                //     $finish;
                // end
    
            endcase
        end
    end
    

    
    


endmodule