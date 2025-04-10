module LoadModule (
    input logic [63:0] load_address,     // Memory address to load from
    input logic [1:0] load_size,         // Size of the load (00 = byte, 01 = half-word, 10 = word, 11 = double-word)
    input logic load_signed,             // Sign-extension enable
    input logic [63:0] mem_rdata,        // Data returned from memory
    input logic mem_valid,               // Indicates memory data is valid
    input logic clk,
    input logic reset,
    
    output logic [63:0] load_data,       // Aligned and extended loaded data
    output logic load_ready,             // Load completed signal
    output logic load_stall              // Indicates if load is stalling
);

    // Internal signals
    logic [63:0] aligned_data;           // Data after alignment
    
    always_comb begin
        load_ready = 0;
        load_stall = 0;
        aligned_data = 0;

        // Alignment logic based on load_size
        case (load_size)
            2'b00: aligned_data = {56'b0, mem_rdata[7:0]};   // Byte load
            2'b01: aligned_data = {48'b0, mem_rdata[15:0]};  // Half-word load
            2'b10: aligned_data = {32'b0, mem_rdata[31:0]};  // Word load
            2'b11: aligned_data = mem_rdata;                 // Double-word load
        endcase

        // Handle sign-extension
        if (load_signed) begin
            case (load_size)
                2'b00: load_data = {{56{aligned_data[7]}}, aligned_data[7:0]};   // Sign-extend byte
                2'b01: load_data = {{48{aligned_data[15]}}, aligned_data[15:0]}; // Sign-extend half-word
                2'b10: load_data = {{32{aligned_data[31]}}, aligned_data[31:0]}; // Sign-extend word
                2'b11: load_data = aligned_data;                                 // No sign extension for double-word
            endcase
        end else begin
            load_data = aligned_data; // Zero-extend for unsigned loads
        end

        // Set load_ready and load_stall based on mem_valid
        if (mem_valid) begin
            load_ready = 1;
            load_stall = 0;
        end else begin
            load_ready = 0;
            load_stall = 1;
        end
    end

endmodule
