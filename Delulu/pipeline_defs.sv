// Struct for Writeback (WB) Stage Data [UNUSED]
typedef struct packed {
    logic [63:0] result;          // ALU or Memory result
    logic [31:0] instruction;     // Full instruction from MEM stage
    logic [63:0] pc;              // Program Counter from MEM stage
    logic [4:0]  rd;              // Destination register
    logic        reg_write;       // Register write enable
    logic        mem_to_reg;      // Select memory read result or ALU result
    logic        is_store;        // Is a store operation
    logic [63:0] rs2_data;        // Data to store in memory
    logic        mem_read;        // Is a memory read operation
} wb_output;
