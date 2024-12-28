// module DataCache (
//     input  logic clk,
//     input  logic reset,
//     input  logic [63:0] addr,
//     input  logic read_enable,
//     input  logic write_enable,
//     input  logic [63:0] write_data,
//     output logic [63:0] read_data
// );

//     // Cache memory
//     logic [63:0] cache_mem [0:255]; // Example: 256 lines of 64-bit width

//     // Cache read/write logic
//     always_ff @(posedge clk or posedge reset) begin
//         if (reset) begin
//             for (int i = 0; i < 256; i++) begin
//                 cache_mem[i] <= 64'b0;
//             end
//         end else if (read_enable) begin
//             read_data <= cache_mem[addr[7:0]]; // Assuming 8-bit index for simplicity
//         end else if (write_enable) begin
//             cache_mem[addr[7:0]] <= write_data;
//         end
//     end

// endmodule
