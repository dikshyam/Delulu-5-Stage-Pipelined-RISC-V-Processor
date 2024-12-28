// module InstructionCache (
//     input  logic         clk,
//     input  logic         reset,
    
//     // CPU interface
//     input  logic [63:0]  cpu_addr,       // Address from the CPU
//     input  logic         cpu_read,       // Read request
//     output logic [31:0]  cpu_data,       // Data to CPU
//     output logic         cpu_valid,      // Data valid signal

//     // AXI interface
//     output logic [63:0]  axi_araddr,     // AXI read address
//     output logic [7:0]   axi_arlen,      // AXI burst length
//     output logic [2:0]   axi_arsize,     // AXI transfer size
//     output logic [1:0]   axi_arburst,    // AXI burst type
//     output logic         axi_arvalid,    // AXI address valid
//     input  logic         axi_arready,    // AXI address ready

//     input  logic [63:0]  axi_rdata,      // AXI read data
//     input  logic         axi_rvalid,     // AXI read valid
//     output logic         axi_rready,     // AXI read ready
//     input  logic         axi_rlast       // AXI read last
// );

//     // Cache memory (Direct-mapped cache for simplicity)
//     localparam CACHE_LINES = 64;         // Number of cache lines
//     localparam TAG_WIDTH = 48;           // Tag width (64-bit addr - index bits - offset bits)
//     localparam INDEX_WIDTH = 6;          // Index width (log2(CACHE_LINES))
//     localparam OFFSET_WIDTH = 2;         // Offset width for 4-byte aligned access

//     typedef struct packed {
//         logic [TAG_WIDTH-1:0] tag;       // Cache tag
//         logic [255:0]         data;      // 256-bit data (8 instructions of 32 bits)
//         logic                 valid;     // Valid bit
//     } cache_line_t;

//     cache_line_t cache [CACHE_LINES];

//     // Internal signals
//     logic [INDEX_WIDTH-1:0] index;       // Cache index
//     logic [OFFSET_WIDTH-1:0] offset;     // Cache offset
//     logic [TAG_WIDTH-1:0] tag;           // Cache tag
//     logic cache_hit;                     // Cache hit signal
//     logic [255:0] line_data;             // Cache line data
//     logic [31:0] selected_data;          // Selected instruction

//     // Cache indexing and tag extraction
//     assign index = cpu_addr[INDEX_WIDTH+OFFSET_WIDTH-1:OFFSET_WIDTH];
//     assign tag = cpu_addr[63:INDEX_WIDTH+OFFSET_WIDTH];
//     assign offset = cpu_addr[OFFSET_WIDTH-1:0];

//     // Check for cache hit
//     always_comb begin
//         if (cache[index].valid && (cache[index].tag == tag)) begin
//             cache_hit = 1'b1;
//             line_data = cache[index].data;
//         end else begin
//             cache_hit = 1'b0;
//             line_data = 256'b0;
//         end
//     end

//     // Select the requested instruction based on the offset
//     always_comb begin
//         case (offset)
//             2'b00: selected_data = line_data[31:0];
//             2'b01: selected_data = line_data[63:32];
//             2'b10: selected_data = line_data[95:64];
//             2'b11: selected_data = line_data[127:96];
//             default: selected_data = 32'b0;
//         endcase
//     end

//     // Output to CPU
//     always_ff @(posedge clk or posedge reset) begin
//         if (reset) begin
//             cpu_data <= 32'b0;
//             cpu_valid <= 1'b0;
//         end else if (cpu_read) begin
//             if (cache_hit) begin
//                 cpu_data <= selected_data;
//                 cpu_valid <= 1'b1;
//             end else begin
//                 cpu_data <= 32'b0;
//                 cpu_valid <= 1'b0;
//             end
//         end else begin
//             cpu_valid <= 1'b0;
//         end
//     end

//     // AXI interface for cache miss handling
//     always_ff @(posedge clk or posedge reset) begin
//         if (reset) begin
//             axi_araddr <= 64'b0;
//             axi_arlen <= 8'h7;       // Burst length for 8 instructions
//             axi_arsize <= 3'b010;    // Size: 32 bits
//             axi_arburst <= 2'b01;    // Incrementing burst
//             axi_arvalid <= 1'b0;
//             axi_rready <= 1'b0;
//         end else if (!cache_hit && !axi_arvalid) begin
//             // Send read request on cache miss
//             axi_araddr <= {cpu_addr[63:OFFSET_WIDTH], {OFFSET_WIDTH{1'b0}}}; // Align address
//             axi_arvalid <= 1'b1;
//         end else if (axi_arvalid && axi_arready) begin
//             // Address handshake complete
//             axi_arvalid <= 1'b0;
//             axi_rready <= 1'b1;
//         end else if (axi_rvalid && axi_rready) begin
//             // Read data response
//             cache[index].data <= axi_rdata; // Store data in cache
//             cache[index].tag <= tag;
//             cache[index].valid <= 1'b1;

//             if (axi_rlast) begin
//                 axi_rready <= 1'b0;
//             end
//         end
//     end

// endmodule
