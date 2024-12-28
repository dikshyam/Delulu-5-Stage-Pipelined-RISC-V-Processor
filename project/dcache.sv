module dcache (
    input logic clk,
    input logic reset,
    input logic [63:0] mem_address,  // Address to fetch/store data
    input logic [63:0] mem_data_in,  // Data to write
    input logic [2:0] mem_size,      // Size of the memory operation (e.g., byte, half-word, word)
    input logic wr_en,               // Write enable
    output logic [63:0] mem_data_out,// Fetched data
    output logic cache_hit,          // Cache hit signal
    output logic [63:0] writeback_data, // Data to be written back to memory
    input logic [511:0] axi_rdata,   // Data from AXI read (64 bytes)
    input logic axi_rvalid,          // Valid signal for AXI read data
    output logic [63:0] axi_araddr,  // Address for AXI read
    output logic axi_arvalid,        // Valid signal for AXI read address
    input logic axi_arready,         // Ready signal for AXI read address
    output logic [63:0] axi_awaddr,  // Address for AXI write
    output logic axi_awvalid,        // Valid signal for AXI write address
    input logic axi_awready,         // Ready signal for AXI write address
    output logic [63:0] axi_wdata,   // Data for AXI write
    output logic axi_wvalid,         // Valid signal for AXI write data
    input logic axi_wready,          // Ready signal for AXI write data

    // Arbiter interface
    output logic dcache_req,
    input logic dcache_grant
);

    // Cache parameters
    parameter CACHE_SIZE = 4096; // Cache size in bytes (4KB)
    parameter LINE_SIZE = 64;    // Line size in bytes (64 bytes)
    parameter NUM_WAYS = 2;      // Number of ways (2-way set associative)
    parameter NUM_SETS = CACHE_SIZE / (LINE_SIZE * NUM_WAYS); // Number of sets

    // Cache storage
    logic [511:0] cache_data_array [NUM_SETS-1:0][NUM_WAYS-1:0]; // Cache data storage (64 bytes per line)
    logic [63:0] cache_tags [NUM_SETS-1:0][NUM_WAYS-1:0]; // Cache tags
    logic cache_valid [NUM_SETS-1:0][NUM_WAYS-1:0]; // Valid bits
    logic cache_dirty [NUM_SETS-1:0][NUM_WAYS-1:0]; // Dirty bits

    // Address breakdown
    logic [5:0] index; // Index for cache set
    logic [63:6] tag;  // Tag for cache line

    // Cache control signals
    logic hit;
    logic [1:0] way_select;
    logic [63:0] fetched_data;

    // Address breakdown
    assign index = mem_address[11:6]; // Example index bits
    assign tag = mem_address[63:6];   // Example tag bits

    // Cache lookup
    always_comb begin
        hit = 0;
        fetched_data = 64'b0;
        for (int i = 0; i < NUM_WAYS; i++) begin
            if (cache_valid[index][i] && cache_tags[index][i] == tag) begin
                hit = 1;
                way_select = i;
                fetched_data = cache_data_array[index][i][mem_address[5:3]*64 +: 64]; // Fetch data from cache line
            end
        end
        cache_hit = hit;
        mem_data_out = fetched_data;
    end

    // Cache miss handling
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            axi_arvalid <= 0;
            axi_awvalid <= 0;
            axi_wvalid <= 0;
            cache_hit <= 0;
            dcache_req <= 0;
        end else begin
            if (!hit) begin
                axi_araddr <= mem_address;
                dcache_req <= 1;
                if (dcache_grant) begin
                    axi_arvalid <= 1;
                end
            end else if (axi_arvalid && axi_arready) begin
                axi_arvalid <= 0;
                dcache_req <= 0;
            end

            if (axi_rvalid) begin
                cache_data_array[index][way_select] <= axi_rdata;
                cache_tags[index][way_select] <= tag;
                cache_valid[index][way_select] <= 1;
                cache_dirty[index][way_select] <= 0;
                fetched_data <= axi_rdata;
                cache_hit <= 1;
            end else begin
                cache_hit <= hit;
            end

            if (wr_en) begin
                if (hit) begin
                    cache_data_array[index][way_select][mem_address[5:3]*64 +: 64] <= mem_data_in;
                    cache_dirty[index][way_select] <= 1;
                end else begin
                    axi_awaddr <= mem_address;
                    dcache_req <= 1;
                    if (dcache_grant) begin
                        axi_awvalid <= 1;
                        axi_wdata <= mem_data_in;
                        axi_wvalid <= 1;
                    end
                end
            end
        end
    end

    assign writeback_data = cache_data_array[index][way_select];

endmodule