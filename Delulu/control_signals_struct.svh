`ifndef CONTROL_SIGNALS_STRUCT_SVH
`define CONTROL_SIGNALS_STRUCT_SVH

typedef struct packed {
    logic [63:0] pc;
    logic [31:0] instruction;
    logic [4:0] rs1;
    logic [4:0] rs2;
    // logic [63:0] rs1_data;
    // logic [63:0] rs2_data;
    logic [4:0] rd;
    logic en_rs1;
    logic en_rs2;
    logic en_rd;
    logic [63:0] immed;
    // logic keep_pc_plus_immed;
    logic alu_use_immed;
    logic alu_width_32;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic is_store;
    logic is_load;
    // logic is_csr;
    // logic csr_rw;
    // logic csr_rs;
    // logic csr_rc;
    // logic csr_immed;
    logic is_ecall;
    logic is_break;
    // logic is_trap_ret;
    // logic is_wfi;
    // logic is_sfence_vma;
    // logic is_atomic;
    Opcode op_code;
    ALUop alu_op;
    // logic is_swap;
    logic alu_nop;

    // Add missing members for control signals
    logic reg_write;       // Enable register write
    logic mem_write;       // Enable memory write
    logic mem_read;        // Enable memory read
    logic mem_to_reg;      // Select memory or ALU result for writeback

    // Jump-related members
    Jump_Code jump_if;       // Determines the condition to jump
    logic jump_absolute;     // Indicates absolute jump (e.g., JALR)
    logic jump_signal;

    logic [2:0] data_size;
    logic data_sign;
    logic signed_type;
    logic [5:0] shamt;
    // logic [7:0] instruction_type;
} decoder_output;

// UNUSED
typedef struct packed {
    logic miss;
    logic request;      // I-cache needs to make a memory request
    logic request_granted;
    logic in_flight;    // A memory request is ongoing
    logic done;         // A cache line was successfully loaded
    logic hit;          // A cache hit occurred for the current pc
} cache_status_struct;

`endif
