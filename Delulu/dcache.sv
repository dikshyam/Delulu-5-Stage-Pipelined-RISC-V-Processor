
// module dcache #(
//     parameter CACHE_LINE_SIZE = 512,   // each line is 512 bits = 64 bytes
//     parameter LINE_SIZE = 4,     // ICACHE line size in bytes

//     parameter SETS = 32,               // number of sets in the cache
//     parameter WAYS = 2,                // 2-way associative
//     parameter ADDR_WIDTH = 64,
//     parameter DATA_WIDTH = 64
// )
module dcache #(
    parameter CACHE_LINE_SIZE = 512,   // each line is 512 bits = 64 bytes
    // parameter LINE_SIZE = 4,     // ICACHE line size in bytes

    parameter SETS = 32,               // number of sets in the cache
    parameter WAYS = 2,                // 2-way associative
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 64
)(
    input  logic clk,                // system clk
    input  logic reset,                // system reset
    input  logic read_enable,          // CPU requests a read
    input  logic write_enable,         // CPU requests a write
    input  logic [63:0] address,       // target address
    input logic [63:0] pc,
    input logic [31:0] instruction,
    input  logic [2:0] data_size,      // byte/half/word/dword
    input  logic [63:0] data_input,    // data to write (if any)
    input  logic load_sign,            // load sign extension needed?
    input  logic ecall_clean,          // flush dirty lines
    // input  logic icache_reading,       // icache is currently active (priority?)

    // Output
    output logic [63:0] computed_data_out_next,      // data back to CPU
    // output logic send_enable,          // data is ready for CPU
    output logic ecall_clean_done,           // dirty flush done
    input logic ecall_clean_signal_ack,
    // output logic dcache_reading,       // dcache is reading from memory

    // AXI read address
    output logic m_axi_arvalid,
    output logic [63:0] m_axi_araddr,
    output logic [7:0]  m_axi_arlen,
    output logic [2:0]  m_axi_arsize,
    output logic [1:0]  m_axi_arburst,
    input  logic m_axi_arready,

    // AXI read data
    input  logic [63:0] m_axi_rdata,
    input  logic m_axi_rvalid,
    input  logic m_axi_rlast,
    output logic m_axi_rready,

    // AXI write address
    output logic m_axi_awvalid,
    output logic [63:0] m_axi_awaddr,
    output logic [7:0]  m_axi_awlen,
    output logic [2:0]  m_axi_awsize,
    output logic [1:0]  m_axi_awburst,
    input  logic m_axi_awready,

    // AXI write data
    output logic [63:0] m_axi_wdata,
    output logic [7:0]  m_axi_wstrb,
    output logic m_axi_wvalid,
    output logic m_axi_wlast,
    input  logic m_axi_wready,

    // AXI write response
    input  logic m_axi_bvalid,
    input  logic [1:0] m_axi_bresp,
    output logic m_axi_bready,

    // Coherency
    input  logic m_axi_acvalid,
    input  logic [ADDR_WIDTH-1:0] m_axi_acaddr,
    input  logic [3:0] m_axi_acsnoop,
    output logic m_axi_acready,
    output logic stall_core,

    input  logic new_data_request,
    input  logic arbiter_dcache_grant,
    output logic dcache_request,
    output logic dcache_in_flight,
    output logic dcache_result_ready,
    input logic dcache_result_ack, 
    output logic dcache_underway,
    input logic enable_logging
);
// -----------------------------------------------------------
// Cache memory structures
// -----------------------------------------------------------
// localparam BLOCK_OFFSET_WIDTH = $clog2(CACHE_LINE_SIZE / DATA_WIDTH);
// localparam BLOCK_OFFSET_WIDTH = $clog2(CACHE_LINE_SIZE);  // CACHE_LINE_SIZE is in bytes
localparam BLOCK_OFFSET_WIDTH = $clog2(CACHE_LINE_SIZE / DATA_WIDTH) + 3;
localparam SET_INDEX_WIDTH    = $clog2(SETS);
localparam TAG_WIDTH          = ADDR_WIDTH - SET_INDEX_WIDTH - BLOCK_OFFSET_WIDTH;

localparam WORD_OFFSET_WIDTH = 3;   // 8 words per cache line
localparam BYTE_OFFSET_WIDTH = 3;   // 8 bytes per word

logic dcache_hit_or_done;
// Cache arrays
logic [TAG_WIDTH-1:0]        tags       [SETS-1:0][WAYS-1:0];
logic [CACHE_LINE_SIZE-1:0]  data_lines [SETS-1:0][WAYS-1:0];
logic                        valid_bits [SETS-1:0][WAYS-1:0];
logic                        dirty_bits [SETS-1:0][WAYS-1:0];

logic [63:0] line_data, computed_data_out, computed_data_out_next;
// logic [DATA_WIDTH*LINE_SIZE-1:0] data_lines [SET_COUNT][WAY_COUNT];

logic snoop_done;
integer dcache_logfile;
// AXI burst read buffer
logic [63:0] burst_buffer [7:0];
logic [2:0]  burst_counter;

// req_tag, req_index are already calculated:
// req_tag = address[ADDR_WIDTH-1 -: TAG_WIDTH];
// req_index = address[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
// req_offset = address[BLOCK_OFFSET_WIDTH-1:0];

logic [BLOCK_OFFSET_WIDTH-BYTE_OFFSET_WIDTH-1:0] block_offset; // Word index within cache line
logic [BYTE_OFFSET_WIDTH-1:0] within_word_offset; // Byte index within word

// logic [ADDR_WIDTH-1:0] snoop_address;
// FSM scratch variables
logic [TAG_WIDTH-1:0]        tag_reg, replace_tag;
logic [SET_INDEX_WIDTH-1:0]  index_reg, replace_index;
logic [BLOCK_OFFSET_WIDTH-1:0] offset_reg, replace_offset;

logic [$clog2(WAYS)-1:0]     access_way_comb;
logic [$clog2(WAYS)-1:0]     writeback_way;
logic [$clog2(WAYS)-1:0] hit_way, hit_way_comb;
logic [ADDR_WIDTH-1:0] flush_addr, snoop_address, dirty_address;

logic [63:0] write_mask;
logic [63:0] shifted_data;
logic [63:0] read_temp;

logic dirty_line_found, dirty_bits_write_complete;
logic [SET_INDEX_WIDTH-1:0] flush_index;
logic [$clog2(WAYS)-1:0]     flush_way;

logic [ADDR_WIDTH-1:0] write_address_track, dcache_aligned_address;
logic [TAG_WIDTH-1:0]        req_tag, dcache_aligned_tag;
logic [SET_INDEX_WIDTH-1:0]  req_index, dcache_aligned_index_reg;
logic [BLOCK_OFFSET_WIDTH-1:0] req_offset, dcache_aligned_offset;
// Break down the address
// assign req_tag   = address[ADDR_WIDTH-1 -: TAG_WIDTH];
// assign req_index = address[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
// assign req_offset = address[BLOCK_OFFSET_WIDTH-1:0];
logic [TAG_WIDTH-1:0] ac_tag;
logic [SET_INDEX_WIDTH-1:0] ac_index;

logic [$clog2(WAYS)-1:0] rr_counter;
logic [63:0] evicted_addr;
logic cache_line_ready, read_request_pending, write_request_pending;
logic flush_in_progress;
// logic [LINE_SIZE*DATA_WIDTH-1:0] packed_dline;
logic [63:0] word;
logic read_result_ready, write_result_ready;
typedef enum logic [3:0] {
    DCACHE_RESET            = 4'd0,
    DCACHE_IDLE             = 4'd1,
    
    DCACHE_MISS_READ_REQ    = 4'd4,
    DCACHE_MISS_READ_WAIT   = 4'd5,
    DCACHE_MISS_FILL_LINE   = 4'd6,

    DCACHE_WRITEBACK_REQ    = 4'd7,
    DCACHE_WRITEBACK_DATA   = 4'd8,
    DCACHE_WRITEBACK_WAIT   = 4'd9,
    DCACHE_WRITEBACK_DONE   = 4'd10, 

    DCACHE_ECALL_CLEAN      = 4'd11, // unused - not needed
    DCACHE_SNOOP_HANDLE     = 4'd12

    // Note: 0xD, 0xE, 0xF are now free
} dcache_state_e;


logic [$clog2(WAYS)-1:0] access_way;
logic [63:0] old_word, new_word;

dcache_state_e fsm_state, fsm_next_state;



// unsure it's already too complicated and i want to kill myself
always_ff @(posedge clk) begin
    if (reset)
        rr_counter <= 0;
    else if (fsm_state == DCACHE_MISS_FILL_LINE) begin
        rr_counter <= (rr_counter == 0) ? 1 : 0;
    end
    // access_way_comb <= rr_counter;
end

// always_ff @(posedge clk) begin
//     if (read_enable || write_enable) begin
//     logic [ADDR_WIDTH-1:0] full_addr;

//     $display("\n================= DCACHE DEBUG STATE =================");
//     $display("[SET | WAY] | VALID | DIRTY |        TAG        |         ADDR        | DATA");
//     for (int set = 0; set < SETS; set++) begin
//         for (int way = 0; way < WAYS; way++) begin
//             if (valid_bits[set][way]) begin
//                 full_addr = {tags[set][way], set[$clog2(SETS)-1:0], {BLOCK_OFFSET_WIDTH{1'b0}}};

//                 $display("[ %2d | %2d ] |   %0d   |   %0d   | %014h | %016h | %h",
//                          set, way,
//                          valid_bits[set][way],
//                          dirty_bits[set][way],
//                          tags[set][way],
//                          full_addr,
//                          data_lines[set][way]);
//             end
//         end
//     end

//     $display("======================================================");
//     $display("[ACTIVE REQ] Tag: %014h | Index: %0d | Offset: %0d", tag_reg, index_reg, offset_reg);
//     $display("Checking line address: %016h", {tag_reg, index_reg, {BLOCK_OFFSET_WIDTH{1'b0}}});
//     $display("======================================================\n");
//     end
// end


// File handle for transaction log
integer tx_logfile;

// In your initialization/reset logic:
initial begin
    // Open log file for writing
    tx_logfile = $fopen("/home/dimohanty/CPU/logs/dcache_transactions.log", "w");
    if (!tx_logfile) begin
        $display("[DCACHE] ERROR: Failed to open transaction log file");
    end else begin
        $fwrite(tx_logfile, "TIME,OP,PC,ADDR,SIZE,SIGN,DATA,HIT_MISS,SET,TAG,WAY,INSTRUCTION\n");
        // $display("[DCACHE] Transaction logging enabled to dcache_transactions.log");
    end
end

// In your transaction handling logic (where you detect read/write completions):
always_ff @(posedge clk) begin
    if (enable_logging) begin
        if (read_result_ready || write_result_ready) begin
                if (tx_logfile) begin
                    $fwrite(tx_logfile, "%0d,", $time);
                    $fwrite(tx_logfile, "%s,", read_result_ready ? "READ" : "WRITE");
                    $fwrite(tx_logfile, "%h,", pc);  // Assuming this contains PC
                    $fwrite(tx_logfile, "%h,", address);
                    $fwrite(tx_logfile, "%0d,", data_size);
                    $fwrite(tx_logfile, "%b,", load_sign);  
                    $fwrite(tx_logfile, "%h,", read_result_ready ? computed_data_out : data_input);
                    $fwrite(tx_logfile, "%s,", dcache_hit_or_done ? "HIT" : "MISS");
                    $fwrite(tx_logfile, "%0d,", req_index);
                    $fwrite(tx_logfile, "%h,", req_tag);
                    $fwrite(tx_logfile, "%0d,", hit_way_comb);
                    $fwrite(tx_logfile, "%h\n", instruction);
                end
            end
    end
end

// Close file on simulation end
final begin
    if (tx_logfile) begin
        $fclose(tx_logfile);
        // $display("[DCACHE] Transaction log file closed");
    end
end

// Define a snoop invalidation record structure
typedef struct packed {
    logic [63:0] timestamp;          // Simulation time when snoop occurred
    logic [63:0] snoop_address;      // Address being snooped
    logic [3:0]  snoop_type;         // Type of snoop request (from m_axi_acsnoop)
    logic [TAG_WIDTH-1:0] tag;       // Tag bits of snooped address
    logic [SET_INDEX_WIDTH-1:0] index; // Set index of snooped address
    logic        match_found;        // Whether a matching line was found
    logic [$clog2(WAYS)-1:0] way;    // Way where match was found (if any)
    logic        was_dirty;          // Whether the invalidated line was dirty
    logic        was_valid;          // Whether the invalidated line was valid
} snoop_invalidation_t;

// Create a snoop log
parameter SNOOP_LOG_SIZE = 32;  // More entries for snoops
snoop_invalidation_t snoop_log [SNOOP_LOG_SIZE-1:0];
logic [$clog2(SNOOP_LOG_SIZE)-1:0] snoop_log_ptr;

// File handle for snoop log
integer snoop_logfile;

// In your initialization/reset logic:
initial begin
    // Open log file for writing
    snoop_logfile = $fopen("/home/dimohanty/CPU/logs/snoop_invalidations.log", "w");
    if (!snoop_logfile) begin
        $display("[DCACHE] ERROR: Failed to open snoop log file");
    end else begin
        $fwrite(snoop_logfile, "TIME,ADDRESS,SNOOP_TYPE,TAG,INDEX,MATCH_FOUND,WAY,WAS_DIRTY,WAS_VALID\n");
        // $display("[DCACHE] Snoop logging enabled to snoop_invalidations.log");
    end
    
    // Initialize log pointer
    snoop_log_ptr = 0;
end

// In your snoop handling logic, add this section:
always_ff @(posedge clk) begin
    if (reset) begin
        snoop_log_ptr <= 0;
    end else if (fsm_state == DCACHE_SNOOP_HANDLE && m_axi_acready) begin
        // Process each way to check for matches
        logic found_match;
        found_match = 0;
        
        // Check all ways for a matching line
        for (int w = 0; w < WAYS; w++) begin
            if (valid_bits[ac_index][w] && tags[ac_index][w] == ac_tag) begin
                found_match = 1;
                
                // Record the snoop invalidation
                snoop_log[snoop_log_ptr].timestamp = $time;
                snoop_log[snoop_log_ptr].snoop_address = snoop_address;
                snoop_log[snoop_log_ptr].snoop_type = m_axi_acsnoop;
                snoop_log[snoop_log_ptr].tag = ac_tag;
                snoop_log[snoop_log_ptr].index = ac_index;
                snoop_log[snoop_log_ptr].match_found = 1;
                snoop_log[snoop_log_ptr].way = w;
                snoop_log[snoop_log_ptr].was_dirty = dirty_bits[ac_index][w];
                snoop_log[snoop_log_ptr].was_valid = valid_bits[ac_index][w];
                
                // Write to log file
                $fwrite(snoop_logfile, "%0d,", $time);
                $fwrite(snoop_logfile, "%h,", snoop_address);
                $fwrite(snoop_logfile, "%h,", m_axi_acsnoop);
                $fwrite(snoop_logfile, "%h,", ac_tag);
                $fwrite(snoop_logfile, "%0d,", ac_index);
                $fwrite(snoop_logfile, "1,");  // Match found
                $fwrite(snoop_logfile, "%0d,", w);
                $fwrite(snoop_logfile, "%0d,", dirty_bits[ac_index][w]);
                $fwrite(snoop_logfile, "%0d\n", valid_bits[ac_index][w]);
                
                // Console output
                // $display("[SNOOP_INVALIDATE] Time=%0t | Addr=%h | Tag=%h | Index=%0d | Way=%0d | Dirty=%0d | Valid=%0d",
                //         $time, snoop_address, ac_tag, ac_index, w, 
                //         dirty_bits[ac_index][w], valid_bits[ac_index][w]);
                
                // Increment pointer (circular buffer)
                snoop_log_ptr <= (snoop_log_ptr == SNOOP_LOG_SIZE-1) ? 0 : snoop_log_ptr + 1;
            end
        end
        
        // Record when no match is found
        if (!found_match) begin
            snoop_log[snoop_log_ptr].timestamp = $time;
            snoop_log[snoop_log_ptr].snoop_address = snoop_address;
            snoop_log[snoop_log_ptr].snoop_type = m_axi_acsnoop;
            snoop_log[snoop_log_ptr].tag = ac_tag;
            snoop_log[snoop_log_ptr].index = ac_index;
            snoop_log[snoop_log_ptr].match_found = 0;
            snoop_log[snoop_log_ptr].way = 0;
            snoop_log[snoop_log_ptr].was_dirty = 0;
            snoop_log[snoop_log_ptr].was_valid = 0;
            
            // Write to log file
            $fwrite(snoop_logfile, "%0d,", $time);
            $fwrite(snoop_logfile, "%h,", snoop_address);
            $fwrite(snoop_logfile, "%h,", m_axi_acsnoop);
            $fwrite(snoop_logfile, "%h,", ac_tag);
            $fwrite(snoop_logfile, "%0d,", ac_index);
            $fwrite(snoop_logfile, "0,");  // No match found
            $fwrite(snoop_logfile, ",");   // No way
            $fwrite(snoop_logfile, ",");   // Not dirty
            $fwrite(snoop_logfile, "\n");  // Not valid
            
            // Console output
            // $display("[SNOOP_NO_MATCH] Time=%0t | Addr=%h | Tag=%h | Index=%0d | No matching line found",
            //         $time, snoop_address, ac_tag, ac_index);
            
            // Increment pointer (circular buffer)
            snoop_log_ptr <= (snoop_log_ptr == SNOOP_LOG_SIZE-1) ? 0 : snoop_log_ptr + 1;
        end
    end
end

// Close file on simulation end
final begin
    if (snoop_logfile) begin
        $fclose(snoop_logfile);
        // $display("[DCACHE] Snoop log file closed");
    end
end


always_ff @(posedge clk) begin
    if (reset) begin
        m_axi_arvalid    <= 0;
        m_axi_rready     <= 0;

        m_axi_wvalid     <= 0;
        m_axi_bready     <= 0;
        m_axi_wlast      <= 0;

        m_axi_acready <= 0;

        // data_out         <= 64'b0;
        burst_counter    <= 0;

        tag_reg          <= '0;
        index_reg        <= '0;
        offset_reg       <= '0;
        // snoop_done <= 0;
        hit_way          <= '0;
        dcache_result_ready <= 1'b0;
        read_request_pending <= 0;
        write_request_pending <= 0;
        cache_line_ready <= 0;
        fsm_state <= DCACHE_IDLE;
        write_address_track <= 0;
        dirty_bits_write_complete <= 0;

        // old_word <= 64'b0;
        // new_word <= 64'b0;
        
        m_axi_wdata  <= 0;
        m_axi_wstrb  <= 0;
        dcache_in_flight <= 0;
        m_axi_acready <= 0;
        // stall_core     <= 0;
        // read_result_ready <= 0;
        // write_result_ready <= 0;
        ecall_clean_done <= 0;
        // writeback_in_progress <= 0;
        // $display("[DCACHE] RESET: Core dcache state reset to IDLE.");

    end else begin
        fsm_state <= fsm_next_state;
        case (fsm_state)
        
        DCACHE_RESET: begin
            if (read_result_ready || write_result_ready) begin
                dcache_result_ready <= 1;
                computed_data_out_next <= computed_data_out;
                // computed_data_out_next <= read_enable ? computed_data_out: 0;
                // read_result_ready <= 0;
                // write_result_ready <= 0;
            end else if (dcache_result_ready && dcache_result_ack) begin
                dcache_result_ready <= 0;
            end else if (ecall_clean_done_comb) begin
                ecall_clean_done <= 1;
            end else if (ecall_clean_done && ecall_clean_signal_ack) begin
                // dcache_result_ready <= 0;
                ecall_clean_done <= 0;
            end else begin
                // waiting for data to latch
            end
            
        end

        DCACHE_IDLE: begin
            // dcache_result_ready <= 0;
            dcache_in_flight    <= 0;
            burst_counter       <= 0;
            // cache_line_ready    <= 0;
            if (new_data_request && !dcache_hit_or_done) begin
                cache_line_ready    <= 0;
                access_way <= access_way_comb;
            end

            // if (new_data_request) begin
            //     // tag_reg    <= req_tag;
            //     // index_reg  <= req_index;
            //     // offset_reg <= req_offset;
            //     dcache_result_ready <= 0;
            //     // hit_way <= hit_way_comb;
            //     access_way <= access_way_comb;
            //     $display("[DCACHE] IDLE → LOOKUP | Addr: %h | Tag: %h | Index: %d | Offset: %d",
            //              address, req_tag, req_index, req_offset);
            // end

        end


        // DCACHE_HIT_READ: begin

            
        //     //     // Extract full 64-bit word from the cache line
        //     //     // word = data_lines[index_reg][hit_way][offset_reg * 64 +: 64];
            
        //     //     // // Apply size + sign extension
        //     //     // case (data_size)
        //     //     //     3'b001: data_out <= load_sign ? {{56{word[7]}},  word[7:0]}   : {56'b0, word[7:0]};
        //     //     //     3'b010: data_out <= load_sign ? {{48{word[15]}}, word[15:0]}  : {48'b0, word[15:0]};
        //     //     //     3'b100: data_out <= load_sign ? {{32{word[31]}}, word[31:0]}  : {32'b0, word[31:0]};
        //     //     //     3'b111: data_out <= word;
        //     //     //     default: data_out <= 64'b0;
        //     //     // endcase

        //     //     // data_out <= computed_data_out;
        //     //     // read_result_ready <= 1;

        //     //     $display("[DCACHE] READ HIT | Addr=%h | Data=%h | DataSize=%0d | Word=%h",
        //     //             {tag_reg, index_reg, offset_reg},
        //     //             computed_data_out,
        //     //             data_size,
        //     //             word);
        //     //     // read_result_ready <= 1;
                
        // end

        // DCACHE_HIT_WRITE: begin
        
            //     // old_word <= data_lines[index_reg][hit_way][offset_reg * 64 +: 64];
            
            //     case (data_size)
            //         3'b001: begin
            //             // write_mask   <= 64'hFF << (offset_reg * 8);
            //             // shifted_data <= data_input[7:0] << (offset_reg * 8);
            //             do_pending_write(dcache_aligned_address, data_input[7:0], 1);
            //         end
            //         3'b010: begin
            //             // write_mask   <= 64'hFFFF << (offset_reg * 8);
            //             // shifted_data <= data_input[15:0] << (offset_reg * 8);
            //             do_pending_write(dcache_aligned_address, data_input[15:0], 2);
            //         end
            //         3'b100: begin
            //             // write_mask   <= 64'hFFFFFFFF << (offset_reg * 8);
            //             // shifted_data <= data_input[31:0] << (offset_reg * 8);
            //             do_pending_write(dcache_aligned_address, data_input[31:0], 4);
            //         end
            //         3'b111: begin
            //             // write_mask   <= 64'hFFFFFFFFFFFFFFFF;
            //             // shifted_data <= data_input;
            //             do_pending_write(dcache_aligned_address, data_input, 8);
            //         end
            //         // default: begin
            //         //     write_mask   <= 64'h0;
            //         //     shifted_data <= 64'h0;
            //         // end
            //     endcase
            
            //     // new_word <= (old_word & ~write_mask) | (shifted_data & write_mask);
            //     data_lines[index_reg][hit_way][offset_reg * 64 +: 64] <= new_word;
            //     valid_bits[index_reg][hit_way] <= 1'b1;      // Optional, for robustness
            //     dirty_bits[index_reg][hit_way] <= 1'b1;      // Mark line dirty due to write
                        
            //     write_result_ready <= 1;
            
            //     $display("[DCACHE] WRITE HIT | Addr=%h | OldWord=%h | NewWord=%h | Size=%0d", {tag_reg, index_reg, offset_reg}, old_word, new_word, data_size);
        // end


        DCACHE_MISS_READ_REQ: begin
            if (!arbiter_dcache_grant) begin
                dcache_request <= 1; // Stay high until we handshake

            end else if (arbiter_dcache_grant && !m_axi_arvalid) begin
                // Raise request
                m_axi_arvalid <= 1;
                m_axi_araddr  <= dcache_aligned_address;
                // m_axi_araddr <= {address[ADDR_WIDTH-1:BLOCK_OFFSET_WIDTH], {BLOCK_OFFSET_WIDTH{1'b0}}};

                // m_axi_araddr <= {tag_reg, index_reg, {BLOCK_OFFSET_WIDTH{1'b0}}} & 64'h00000000FFFFFFFF;

                m_axi_arlen   <= 8'd7;
                m_axi_arsize  <= 3'b011;
                m_axi_arburst <= 2'b10;
        
                dcache_request <= 0;
                // $display("[DCACHE] MISS_READ_REQ: Requesting AXI read");
                // $display("[DCACHE] Requesting line for address: %h | Aligned: %h", address, {address[63:6], 6'b0});

            end
        
            if (m_axi_arvalid && m_axi_arready) begin
                // Handshake complete — drop valid
                m_axi_arvalid    <= 0;
                m_axi_rready     <= 1;
                burst_counter    <= 0;
                dcache_in_flight <= 1;
                read_request_pending <= 1;
        
                // $display("[DCACHE] MISS_READ_REQ → MISS_READ_WAIT | Handshake complete");
                // $display("[DCACHE] READ MISS | m_axi_araddr = %h | tag=%h index=%h offset=%h", m_axi_araddr, tag_reg, index_reg, {BLOCK_OFFSET_WIDTH{1'b0}});

            end
            
        end


        DCACHE_MISS_READ_WAIT: begin
            if (m_axi_rvalid && m_axi_rready) begin
                burst_buffer[burst_counter] <= m_axi_rdata;
        
                if (m_axi_rlast) begin
                    m_axi_rready  <= 0;
                    burst_counter <= 0;
                    fsm_state <= DCACHE_MISS_FILL_LINE;
                    dcache_in_flight <= 0;
                end else begin
                    burst_counter <= burst_counter + 1;
                    read_request_pending <= 0;
                end
            end
        end
        
        DCACHE_MISS_FILL_LINE: begin

            // Commit into cache
            // data_lines[index_reg][access_way] <= {burst_buffer[7], burst_buffer[6], 
            //                                         burst_buffer[5], burst_buffer[4],
            //                                         burst_buffer[3], burst_buffer[2], 
            //                                         burst_buffer[1], burst_buffer[0]};

            // tags[index_reg][access_way]       <= tag_reg;
            // valid_bits[index_reg][access_way] <= 1'b1;
            // dirty_bits[index_reg][access_way] <= 1'b0;
        
            // hit_way         <= access_way;

            if (data_stored) begin
                cache_line_ready <= 1;

            end
        
            // $display("[DCACHE] FILL_LINE | Index=%0d | Way=%0d | Tag=%h", index_reg, access_way, tag_reg);
        end
        
        // ============================================
        // DCACHE_WRITEBACK_REQ (Address Phase)
        // ============================================
        DCACHE_WRITEBACK_REQ: begin
            // Set AXI signals only if not already valid (prevent glitches)
            // if (!m_axi_awvalid) begin
                // m_axi_awvalid <= 1'b1;
                // m_axi_awaddr  <= ecall_clean ? flush_addr : dcache_aligned_address;
                // write_address_track <= ecall_clean ? flush_addr : dcache_aligned_address;  //  Track for debug
                // m_axi_awlen   <= 8'd7;       // Burst length = 8 beats (64 bytes)
                // m_axi_awsize  <= 3'b011;     // 8 bytes/transfer (64-bit)
                // m_axi_awburst <= 2'b01;      // INCR burst (address increments)
            write_address_track <= ecall_clean ? flush_addr : dirty_address;
            dirty_bits_write_complete <= 1'b0;
            write_request_pending <= 1;
            m_axi_wlast <= 0;
            // $display("[DCACHE] WRITEBACK_REQ | Addr: %h | Way: %0d", 
            //         ecall_clean ? flush_addr : dcache_aligned_address, 
            //         ecall_clean ? flush_way : hit_way);
            // end
        
            // Handshake completion check
            // if (m_axi_awvalid && m_axi_awready && m_axi_wready) begin
            //     write_request_pending <= 1;
            //     m_axi_awvalid <= 1'b0;       // Deassert after acceptance
            //     burst_counter <= 0;           // Reset beat counter
            //     $display("[DCACHE] AW handshake complete, proceeding to data phase");

            end
    //     end
    // end

        DCACHE_WRITEBACK_WAIT: begin
            burst_counter <= 0;
        end
        // ============================================
        // DCACHE_WRITEBACK_DATA (Data Phase)
        // ============================================
        DCACHE_WRITEBACK_DATA: begin
            // Data beat handshake (per 64-bit word)
            if (m_axi_wready && !m_axi_wlast) begin
                m_axi_wvalid <= 1'b1;
                m_axi_wdata  <= ecall_clean ? 
                                data_lines[flush_index][flush_way][(7-burst_counter)*64 +: 64] : 
                                data_lines[replace_index][access_way_comb][(7-burst_counter)*64 +: 64];
                m_axi_wstrb  <= 8'hFF;  // All bytes enabled
                
                // Update address tracker (optional debug)
                write_address_track <= write_address_track + 8;
                burst_counter <= burst_counter + 1;
                
                // Optional debug display
                // $display("[DCACHE] WRITEBACK: Sending word %d (inv: %d) from address %h: %h", 
                //          burst_counter, 7-burst_counter, write_address_track, m_axi_wdata);
            end
            // Beat counter update on successful transfer
            // if (m_axi_wvalid) begin
            //     burst_counter <= burst_counter + 1;
            // end 

            if (burst_counter == 7) begin
                m_axi_wlast  <= 1;
            end    

            // Final beat cleanup
            if (m_axi_wlast) begin
                m_axi_wvalid <= 1'b0;
                m_axi_wlast  <= 1;
                burst_counter <= 0;
                write_request_pending <=0;
                // state <= DCACHE_WRITEBACK_WAIT;  // Proceed to response phase
                // $display("[DCACHE] WRITEBACK_DATA: Burst complete @ %h", 
                //         write_address_track);
            end
        end
        // end
        // end

        DCACHE_WRITEBACK_DONE: begin
            if (m_axi_bvalid && !m_axi_bready) begin
                m_axi_bready <=1;
            end else if (m_axi_bready && m_axi_bvalid) begin
                m_axi_bready <= 0;
                dirty_bits_write_complete <= 1;  
            end
        end

        // DCACHE_WRITEBACK_WAIT, DCACHE_ECALL_FLUSH_WAIT: begin
        //     // Clean up any lingering write signals (safety)
        //     if (m_axi_awvalid && m_axi_awready) begin
        //         m_axi_awvalid <= 1'b0;
        //         m_axi_wvalid  <= 1'b0;
        //         m_axi_wlast   <= 1'b0;
        //         burst_counter <= 0;
        //     end
        
        //     // Response handshake
        //     if (m_axi_bvalid) begin
        //         if (!m_axi_bready) begin
        //             // First cycle: Acknowledge response
        //             m_axi_bready <= 1'b1;
        //         end
        //         else begin
        //             // Second cycle: Complete handshake
        //             m_axi_bready <= 1'b0;
        //             dirty_bits_write_complete <= 1'b1;
                    
        //             // Update dirty bit (conditional on ecall_clean)
        //             // if (!ecall_clean) begin
        //             //     dirty_bits[index_reg][access_way] <= 1'b0;
        //             // end
                    
        //             $display("[DCACHE] WRITEBACK COMPLETE | Index: %0d | Way: %0d | Resp: %b", 
        //                     index_reg, access_way, m_axi_bresp);
                            
        //             // Return to idle or continue flush process
        //             // state <= ecall_clean ? DCACHE_ECALL_CLEAN : DCACHE_IDLE;
        //         end
        //     end
        // end

        

        DCACHE_SNOOP_HANDLE: begin
            // $display("[DCACHE] SNOOP HANDLE | Addr=%h | Tag=%h | Index=%d", snoop_address, ac_tag, ac_index);
            // Handle new snoop request

            if (m_axi_acvalid && m_axi_acsnoop == 4'b1101 && !m_axi_acready) begin  // MakeInvalid
                // Decode address
                // snoop_done <= 0;
                m_axi_acready <= 1;
                // stall_core    <= 1;
                // snoop_address <= m_axi_acaddr;
                snoop_address <= {m_axi_acaddr[ADDR_WIDTH-1:BLOCK_OFFSET_WIDTH], {BLOCK_OFFSET_WIDTH{1'b0}}};
                // $display("[DCACHE] SNOOP REQUEST | Addr=%h | Snoop=%h", 
                //  m_axi_acaddr, m_axi_acsnoop);
            end

            // if (m_axi_acvalid && m_axi_acready) begin         
            //     for (int w = 0; w < WAYS; w++) begin
            //         if (valid_bits[ac_index][w] && tags[ac_index][w] == ac_tag) begin
            //             valid_bits[ac_index][w] = 0;
            //             $display("[DCACHE] SNOOP_INVALIDATE | Index=%0d Way=%0d Tag=%h", ac_index, w, ac_tag);
            //         end
            //     end
                
            //     m_axi_acready <= 0;  // Acknowledge
            // end

            if (m_axi_acready) begin
                m_axi_acready <= 0;
                // snoop_done    <= 1;

                // $display("[DCACHE] SNOOP IN PROGRESS: Address = 0x%0h", snoop_address);
            end 

            // if (!m_axi_acvalid && m_axi_acready) begin
            //     m_axi_acready <= 0;
            //     // snoop_done    <= 1;

            //     $display("[DCACHE] SNOOP COMPLETE — Back to IDLE");
            // end 

            // if (m_axi_acvalid && m_axi_acready) begin
            //     m_axi_acready <= 0;

            //     $display("[DCACHE] SNOOP COMPLETE — Back to IDLE");
            // end 

        end

        DCACHE_ECALL_CLEAN: begin
            // if (ecall_clean_done_comb==1 && dirty_line_found==0) begin
            //     ecall_clean_done <= 1;
            // end
        end

        
        
        
            
        endcase
    end
end


logic dirty_replace;
logic writeback_for_read;
logic ecall_clean_start;
logic data_stored;
localparam BYTES_PER_WORD = 8; // 64-bit words
localparam WORDS_PER_LINE = CACHE_LINE_SIZE / DATA_WIDTH; // 512/64 = 8 words per line
logic [$clog2(WORDS_PER_LINE)-1:0] word_offset;
logic [2:0] byte_offset; // 0-7 byte offset within word
logic axi_channels_free, ecall_clean_done_comb;
logic write_through_value, write_back_done, request_done;
logic [15:0] halfword;
logic [31:0] word32;

always_comb begin

    if (reset) begin
        fsm_next_state = DCACHE_IDLE;
        ecall_clean_start = 0;
        dcache_hit_or_done = 0;
        hit_way_comb = -1;
        access_way_comb = -1;
        dirty_replace = 0;
        writeback_for_read = 0;
        word = 64'b0;
        old_word = 64'b0;
        new_word = 64'b0;
        computed_data_out = 64'b0;
        read_result_ready = 0;
        write_result_ready = 0;
        data_stored = 0;
        ecall_clean_done_comb = 0;
        m_axi_awvalid    = 0;
        m_axi_awaddr = 0;
        m_axi_awlen   = 0;       // Burst length = 8 beats (64 bytes)
        m_axi_awsize  = 0;     // 8 bytes/transfer (64-bit)
        m_axi_awburst = 0;      // INCR burst (address increments)
        write_back_done = 0;
        write_through_value = 0;
        request_done = 0;
        
        for (int i = 0; i < SETS; i++) begin
            for (int j = 0; j < WAYS; j++) begin
                data_lines[i][j] = '0;
                valid_bits[i][j] = 0;
                dirty_bits[i][j] = 0;
            end
        end
        
        // More control defaults if needed
    end else begin    

        case (fsm_state)
            DCACHE_RESET: begin
                fsm_next_state = DCACHE_RESET;
                if (dcache_result_ready) begin
                    read_result_ready = 0;
                    write_result_ready = 0;
                    if (dcache_result_ack) begin
                        fsm_next_state = DCACHE_IDLE;
                    end
                end else if (ecall_clean_done) begin
                    ecall_clean_done_comb = 0;
                    if (ecall_clean_signal_ack) begin
                        fsm_next_state = DCACHE_IDLE;
                    end
                end

            end 

                

            DCACHE_IDLE: begin
                // fsm_next_state = DCACHE_IDLE;
            
                // Defaults
                // old_word = 64'b0;
                // new_word = 64'b0;
                axi_channels_free = !m_axi_arvalid && !m_axi_awvalid && !m_axi_wvalid;

                if (!read_enable && !write_enable) begin
                    dcache_hit_or_done = 0;
                    hit_way_comb       = -1;
                    access_way_comb    = -1;
                    read_result_ready  = 0;
                    write_result_ready = 0;
                    // stall_core     = 0;
                    writeback_for_read = 0;
                    computed_data_out = 0;
                    request_done = 0;
                end
                // --- Snoop or flush ---
                if (snoop_done) begin
                    stall_core = 0;
                end 
                // else begin
                // end

                if (read_result_ready || write_result_ready || ecall_clean_done_comb) begin
                    fsm_next_state = DCACHE_RESET;
                end 
                
                if (m_axi_acvalid) begin
                    stall_core = (m_axi_acvalid && m_axi_acsnoop == 4'b1101) ? 1'b1 : 1'b0;
                    snoop_done = 0;
                    fsm_next_state = DCACHE_SNOOP_HANDLE;
                    // $display("[DCACHE] ECALL CLEAN STARTED");
                end else if (ecall_clean==1 && axi_channels_free==1 && !ecall_clean_done_comb) begin
                    // ecall_clean_start = 1;
                    // fsm_next_state = DCACHE_ECALL_CLEAN;
                    ecall_clean_done_comb = 1;
                    // $display("[DCACHE] ECALL CLEAN STARTED");
                end else if (new_data_request && !dcache_hit_or_done) begin
                    dcache_aligned_address = {address[ADDR_WIDTH-1:BLOCK_OFFSET_WIDTH], {BLOCK_OFFSET_WIDTH{1'b0}}};
                    req_tag   = address[ADDR_WIDTH-1 -: TAG_WIDTH];
                    req_index = address[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
                    req_offset = address[BLOCK_OFFSET_WIDTH-1:0];

                    if (cache_line_ready) begin
                        // ----------------------------
                        // Tag match lookup
                        // ----------------------------
                        dcache_hit_or_done = 0;
                        hit_way_comb = -1;
                        computed_data_out = 64'b0;

                        
                        for (int w = 0; w < WAYS; w++) begin
                            if (valid_bits[req_index][w] && tags[req_index][w] == req_tag) begin
                                dcache_hit_or_done = 1;
                                hit_way_comb = w;
                                // word_offset = address[$clog2(CACHE_LINE_SIZE)-1:3]; // Word index (0-7)
                                // byte_offset = address[2:0]; // Byte index within word (0-7)
                                word_offset = address[BLOCK_OFFSET_WIDTH-1:BYTE_OFFSET_WIDTH]; // Extract bits [5:3]
                                byte_offset = address[BYTE_OFFSET_WIDTH-1:0]; // Extract bits [2:0]
                                // $display("[DCACHE] HIT DETECTED | Set: %0d | Way: %0d | Tag: %h", req_index, w, req_tag);
                                // $display("Cache line data: %h", data_lines[req_index][hit_way_comb]);
                                // $display("Extracting word at offset %d (bit position %d) from cache line", 
                                //         word_offset, word_offset * DATA_WIDTH);
                                    
                            end
                        end

                        if (dcache_hit_or_done) begin
                            if (read_enable) begin
                                // Access cache data with inverted word offset to match our storage pattern
                                word = data_lines[req_index][hit_way_comb][(7-word_offset) * DATA_WIDTH +: DATA_WIDTH];
                            
                                // Handle different data sizes with appropriate sign extension
                                case (data_size)
                                    3'b001: begin // Byte load (1 byte)
                                        // Extract the byte at the specified offset
                                        computed_data_out = load_sign ? 
                                            {{56{word[byte_offset*8 + 7]}}, word[byte_offset*8 +: 8]} : 
                                            {56'b0, word[byte_offset*8 +: 8]};
                                    end
                                    
                                    3'b010: begin // Half-word load (2 bytes)
                                        // Check for alignment
                                        if (byte_offset[0]) $warning("Unaligned halfword read at %h", address);
                                        
                                        // Extract the halfword
                                        halfword = word[byte_offset*8 +: 16];
                                        
                                        // Apply sign extension if needed
                                        computed_data_out = load_sign ? 
                                            {{48{halfword[15]}}, halfword} : 
                                            {48'b0, halfword};
                                    end
                                    
                                    3'b100: begin // Word load (4 bytes)
                                        // Check for alignment
                                        if (byte_offset[1:0]) $warning("Unaligned word read at %h", address);
                                        
                                        // Extract the word
                                        word32 = word[byte_offset*8 +: 32];
                                        
                                        // Apply sign extension if needed
                                        computed_data_out = load_sign ? 
                                            {{32{word32[31]}}, word32} : 
                                            {32'b0, word32};
                                    end
                                    
                                    3'b111: begin // Double-word load (8 bytes)
                                        // Check for alignment
                                        if (byte_offset[2:0]) $warning("Unaligned dword read at %h", address);
                                        
                                        // For double-word loads, return the entire 64-bit word
                                        computed_data_out = word;
                                    end
                                    
                                    default: computed_data_out = 64'b0;
                                endcase
                            
                                // Debug output
                                // $display("[DCACHE] READ HIT | Addr=%h | Tag=%h | Index=%h | WordOff=%d | InvWordOff=%d | ByteOff=%h | SignedLoad=%b | Data=%h | Word=%h | Size=%0d", 
                                //     address, 
                                //     req_tag, 
                                //     req_index, 
                                //     word_offset,
                                //     7-word_offset,
                                //     byte_offset,
                                //     load_sign,
                                //     computed_data_out, 
                                //     word, 
                                //     data_size);
        //                         $display("DEBUG LD: address=%h, load_sign=%b, raw_word=%h before processing",
        //  address, load_sign, data_lines[req_index][hit_way_comb][(7-word_offset) * DATA_WIDTH +: DATA_WIDTH]);
                                read_result_ready = 1;
                                request_done = 1;
                            end
                            // ----------------------------
                            // HIT: Write
                            // ----------------------------
                            if (write_enable) begin
                                // Extract the components - use the same offset calculations as read
                                word_offset = address[BLOCK_OFFSET_WIDTH-1:BYTE_OFFSET_WIDTH]; // Which 64-bit word in the cache line
                                byte_offset = address[BYTE_OFFSET_WIDTH-1:0]; // Which byte within the 64-bit word
                                
                                // Debug display for verification
                                // $display("Address: %h | req_tag: %h | req_index: %d | word_offset: %d | inv_word_offset: %d | byte_offset: %d",
                                //         address, req_tag, req_index, word_offset, 7-word_offset, byte_offset);
                            
                                // Case statement for different write sizes
                                case (data_size)
                                    3'b001: begin // Byte write
                                        write_mask = 64'hFF << (byte_offset * 8);
                                        shifted_data = data_input[7:0] << (byte_offset * 8);
                                        do_pending_write(address, data_input[7:0], 1);
                                    end
                                    
                                    3'b010: begin // Half-word write
                                        if (byte_offset[0]) $warning("Unaligned halfword write at %h", address);
                                        write_mask = 64'hFFFF << (byte_offset * 8);
                                        shifted_data = data_input[15:0] << (byte_offset * 8);
                                        do_pending_write(address, data_input[15:0], 2); 
                                    end
                                    
                                    3'b100: begin // Word write
                                        if (byte_offset[1:0]) $warning("Unaligned word write at %h", address);
                                        write_mask = 64'hFFFFFFFF << (byte_offset * 8);
                                        shifted_data = data_input[31:0] << (byte_offset * 8);
                                        do_pending_write(address, data_input[31:0], 4); 
                                    end
                                    
                                    3'b111: begin // Double-word write
                                        if (byte_offset[2:0]) $warning("Unaligned dword write at %h", address);
                                        write_mask = 64'hFFFFFFFFFFFFFFFF;
                                        shifted_data = data_input;
                                        do_pending_write(address, data_input[63:0], 8); 
                                    end
                                    
                                    default: begin
                                        $finish;
                                        write_mask = 64'h0;
                                        shifted_data = 64'h0;
                                    end
                                endcase
                                
                                old_word = data_lines[req_index][hit_way_comb][(7-word_offset) * DATA_WIDTH +: DATA_WIDTH];
                                new_word = (old_word & ~write_mask) | (shifted_data & write_mask);
                                // Extensive debug information
                                // $display("DEBUG SD BEFORE: address=%h, data_lines[%d][%d] = %h",
                                // address, req_index, hit_way_comb, 
                                // data_lines[req_index][hit_way_comb]);
                                // $display("Writing to word offset %d (inv %d) (bit position %d)", 
                                // word_offset, 7-word_offset, (7-word_offset) * DATA_WIDTH);
                                for (int w = 0; w < WAYS; w++) begin
                                    if (valid_bits[req_index][w] && tags[req_index][w] == req_tag) begin
                                        data_lines[req_index][w][(7-word_offset) * DATA_WIDTH +: DATA_WIDTH] = (data_lines[req_index][w][(7-word_offset) * DATA_WIDTH +: DATA_WIDTH] & ~write_mask) | (shifted_data & write_mask);
                                        dirty_bits[req_index][w] = 1'b1;

                                    end
                                end
                                // $display("[DCACHE] WRITE HIT | Addr=%h | Tag=%h | Index=%h | WordOff=%d | InvWordOff=%d | ByteOffset=%h | FullAddr=%h | BaseAddr=%h | OldWord=%h | NewWord=%h | CacheLine=%h | InputData=%h | Size=%0d", 
                                //     address, 
                                //     req_tag, 
                                //     req_index, 
                                //     word_offset,
                                //     7-word_offset,
                                //     byte_offset,
                                //     {req_tag, req_index, {BLOCK_OFFSET_WIDTH{1'b0}}},  // This is the full aligned address
                                //     {req_tag, req_index, {BLOCK_OFFSET_WIDTH{1'b0}}},  // Same as FullAddr
                                //     old_word, 
                                //     new_word,
                                //     data_lines[req_index][hit_way_comb],
                                //     data_input,
                                //     data_size);
                                
                                request_done = 1;
                                write_result_ready = 1;
                            end
                        end else if (!dcache_hit_or_done) begin
                            access_way_comb = -1;
            
                            for (int w = 0; w < WAYS; w++) begin
                                if (!valid_bits[req_index][w]) begin
                                    access_way_comb = w;
                                end
                            end
            
                            if (access_way_comb == -1)
                                access_way_comb = rr_counter;
            
                            dirty_replace = valid_bits[req_index][access_way_comb] && dirty_bits[req_index][access_way_comb];
                            if (dirty_replace) begin
                                replace_tag   = address[ADDR_WIDTH-1 -: TAG_WIDTH];
                                replace_index = address[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
                                replace_offset = address[BLOCK_OFFSET_WIDTH-1:0];
                                dirty_address = {
                                    tags[replace_index][access_way_comb],   // Stored tag
                                    replace_index[SET_INDEX_WIDTH-1:0],     // Set index
                                    {BLOCK_OFFSET_WIDTH{1'b0}}              // Zero offset (line-aligned)
                                };
                                // access_way_comb = access_way_comb;
                                writeback_for_read = read_enable;
                                fsm_next_state = DCACHE_WRITEBACK_REQ;
                            end else begin
                                if (read_enable) begin
                                    // $display("[DCACHE] MISS | Replacing Set=%0d Way=%0d | Dirty=%b", req_index, access_way_comb, dirty_replace);
                                    access_way_comb = access_way_comb;
                                    fsm_next_state = DCACHE_MISS_READ_REQ;
                                end
                                    
                                else if (write_enable)
                                    fsm_next_state = DCACHE_IDLE; // Already performed write inline
                            end
                        end

                        end 
                    else begin
                        fsm_next_state = DCACHE_MISS_READ_REQ; 
                    end
                end
            end
            
            

            DCACHE_MISS_READ_REQ: begin
                fsm_next_state = DCACHE_MISS_READ_REQ;
                data_stored = 0;
            
                // Transition only after AXI read address handshake
                if (m_axi_arvalid && m_axi_arready) begin
                    fsm_next_state = DCACHE_MISS_READ_WAIT;
                end
            end
            
            
            DCACHE_MISS_READ_WAIT: begin
                fsm_next_state = DCACHE_MISS_READ_WAIT;
            
                if (m_axi_rvalid && m_axi_rlast && !read_request_pending) begin
                    fsm_next_state = DCACHE_MISS_FILL_LINE;
                end
            end
            
            
            DCACHE_MISS_FILL_LINE: begin

                fsm_next_state = DCACHE_MISS_FILL_LINE;
                dcache_aligned_address = {address[ADDR_WIDTH-1:BLOCK_OFFSET_WIDTH], {BLOCK_OFFSET_WIDTH{1'b0}}};
                dcache_aligned_tag   = address[ADDR_WIDTH-1 -: TAG_WIDTH];
                dcache_aligned_index_reg = address[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
                dcache_aligned_offset = address[BLOCK_OFFSET_WIDTH-1:0];

                data_lines[dcache_aligned_index_reg][access_way] = {burst_buffer[0], burst_buffer[1], 
                                                  burst_buffer[2], burst_buffer[3],
                                                  burst_buffer[4], burst_buffer[5], 
                                                  burst_buffer[6], burst_buffer[7]};

                tags[dcache_aligned_index_reg][access_way]       = dcache_aligned_tag;
                valid_bits[dcache_aligned_index_reg][access_way] = 1'b1;
                dirty_bits[dcache_aligned_index_reg][access_way] = 1'b0;
                data_stored = 1;
                // cache_line_ready = 1;

                if (cache_line_ready) begin
                    fsm_next_state = DCACHE_IDLE;
                end
            end
            
            DCACHE_SNOOP_HANDLE: begin
                // fsm_next_state = DCACHE_SNOOP_HANDLE;
                
                if (m_axi_acready) begin
                    ac_tag    = snoop_address[ADDR_WIDTH-1 -: TAG_WIDTH];
                    ac_index = snoop_address[BLOCK_OFFSET_WIDTH +: SET_INDEX_WIDTH];
                    // if (m_axi_acvalid && m_axi_acready) begin         
                    for (int w = 0; w < WAYS; w++) begin
                        if (valid_bits[ac_index][w] && tags[ac_index][w] == ac_tag) begin
                            // $display("[DCACHE] FOUND MATCHING LINE | Addr=%h | Tag=%h | Index=%d", snoop_address, ac_tag, ac_index);
                            // $display("[DCACHE] FOUND MATCHING LINE | Way=%d | Valid=%b | Dirty=%b", 
                            // w, valid_bits[ac_index][w], dirty_bits[ac_index][w]);
                            // $display("[DCACHE] BEFORE INVALIDATION | Line=%h", data_lines[ac_index][w]);
                            valid_bits[ac_index][w] = 0;
                            data_lines[ac_index][w] = '0;
                            // Handle dirty data - flush if necessary
                            if (dirty_bits[ac_index][w]) begin
                                // $display("[DCACHE] WARNING: Invalidating dirty line without writeback!");
                                // In a full implementation, you might want to initiate a writeback here
                                // to ensure modified data isn't lost
                                dirty_bits[ac_index][w] = 0;
                            end
                        end else begin
                            // $display("[DCACHE] NO MATCHING ADDRESS FOUND | Addr=%h | Tag=%h | Index=%d", snoop_address, ac_tag, ac_index);
                        end
                    end
                end

                if (!m_axi_acvalid && !m_axi_acready) begin
                    // snoop done, resume normal operation
                    snoop_done = 1;
                    // $display("[DCACHE] SNOOP_INVALIDATE | Cache Invalidated");
                    fsm_next_state = DCACHE_IDLE;
                    
                end
            end
            
            DCACHE_WRITEBACK_REQ: begin
                // fsm_next_state = DCACHE_WRITEBACK_REQ;
                m_axi_awvalid = 1;
                m_axi_awaddr  = ecall_clean ? flush_addr : dirty_address;
                // write_address_track = ecall_clean ? flush_addr : dcache_aligned_address;  //  Track for debug
                m_axi_awlen   = 8'd7;       // Burst length = 8 beats (64 bytes)
                m_axi_awsize  = 3'b011;     // 8 bytes/transfer (64-bit)
                m_axi_awburst = 2'b01;      // INCR burst (address increments)
                
                if (m_axi_awvalid && m_axi_awready) begin
                    fsm_next_state = DCACHE_WRITEBACK_WAIT;
                    // write_request_pending = 1;
                end else begin
                    fsm_next_state = DCACHE_WRITEBACK_REQ;
                end
                // if (write_request_pending) begin
                //     fsm_next_state = ecall_clean ? DCACHE_ECALL_FLUSH_DATA : DCACHE_WRITEBACK_DATA;
                // end
            end
            
            DCACHE_WRITEBACK_WAIT: begin
                m_axi_awvalid = 0;
                if (m_axi_wready) begin
                    fsm_next_state = DCACHE_WRITEBACK_DATA;
                end
            end

            

            DCACHE_WRITEBACK_DATA: begin
                fsm_next_state = DCACHE_WRITEBACK_DATA;
            
                if (m_axi_wlast) begin
                    fsm_next_state = DCACHE_WRITEBACK_DONE;
                end
            end
            
            DCACHE_WRITEBACK_DONE: begin
                // fsm_next_state = DCACHE_WRITEBACK_WAIT;
            
                if (dirty_bits_write_complete) begin
                    
                    if (ecall_clean) begin
                        dirty_bits[flush_index][flush_way] = 0;
                        fsm_next_state = DCACHE_ECALL_CLEAN;

                    end else begin
                        
                        if (write_through_value) begin
                            write_result_ready = 1;
                            write_back_done = 1;
                            dirty_bits[replace_index][hit_way_comb] = 0;
                        end else begin
                            dirty_bits[replace_index][access_way_comb] = 0;
                        end

                        fsm_next_state = DCACHE_IDLE;

                        // write_result_ready = 1;
                    end
                    
                end
                
            end


            default: begin

            end
            
        endcase
end

end




endmodule
