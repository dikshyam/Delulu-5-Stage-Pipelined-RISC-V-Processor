// enums.sv
`ifndef ENUMS_SV
`define ENUMS_SV
// ALU Operations Enum


typedef enum logic [7:0] {
    // R-Type Arithmetic
    ALU_ADD     = 8'd0,
    ALU_SUB     = 8'd1,
    ALU_XOR     = 8'd2,
    ALU_OR      = 8'd3,
    ALU_AND     = 8'd4,
    ALU_SLL     = 8'd5,
    ALU_SRL     = 8'd6,
    ALU_SRA     = 8'd7,
    ALU_SLT     = 8'd8,
    ALU_SLTU    = 8'd9,
    ALU_MUL     = 8'd10,
    ALU_MULH    = 8'd11,
    ALU_MULHSU  = 8'd12,
    ALU_MULHU   = 8'd13,
    ALU_DIV     = 8'd14,
    ALU_DIVU    = 8'd15,
    ALU_REM     = 8'd16,
    ALU_REMU    = 8'd17,

    // I-Type Immediate Arithmetic
    ALU_ADDI    = 8'd18,
    ALU_XORI    = 8'd19,
    ALU_ORI     = 8'd20,
    ALU_ANDI    = 8'd21,
    ALU_SLLI    = 8'd22,
    ALU_SRLI    = 8'd23,
    ALU_SRAI    = 8'd24,
    ALU_SLTI    = 8'd25,
    ALU_SLTIU   = 8'd26,

    // RV64I Shifts and Word-Immediates
    // ALU_SLLI_W  = 8'd27,
    // ALU_SRLI_W  = 8'd28,
    // ALU_SRAI_W  = 8'd29,
    ALU_ADDIW   = 8'd30,
    ALU_SLLIW   = 8'd31,
    ALU_SRLIW   = 8'd32,
    ALU_SRAIW   = 8'd33,

    // RV64I Word Register Arithmetic
    ALU_ADDW    = 8'd34,
    ALU_SUBW    = 8'd35,
    ALU_SLLW    = 8'd36,
    ALU_SRLW    = 8'd37,
    ALU_SRAW    = 8'd38,

    // RV64M Word Multiplication and Division
    ALU_MULW    = 8'd39,
    ALU_DIVW    = 8'd40,
    ALU_DIVUW   = 8'd41,
    ALU_REMW    = 8'd42,
    ALU_REMUW   = 8'd43,

    // S-Type Store (tracking only)
    ALU_SB      = 8'd50,
    ALU_SH      = 8'd51,
    ALU_SW      = 8'd52,
    ALU_SD      = 8'd53,

    // B-Type Branch
    ALU_BEQ     = 8'd60,
    ALU_BNE     = 8'd61,
    ALU_BLT     = 8'd62,
    ALU_BGE     = 8'd63,
    ALU_BLTU    = 8'd64,
    ALU_BGEU    = 8'd65,

    // Jumps and Immediate Ops (tracking)
    ALU_JAL     = 8'd70,
    ALU_JALR    = 8'd71,
    ALU_LUI     = 8'd72,
    ALU_AUIPC   = 8'd73,
    ALU_ECALL   = 8'd74,
    ALU_EBREAK  = 8'd75,

    // Loads (tracking only)
    ALU_LB      = 8'd80,
    ALU_LH      = 8'd81,
    ALU_LW      = 8'd82,
    ALU_LBU     = 8'd83,
    ALU_LHU     = 8'd84,
    ALU_LWU     = 8'd85,
    ALU_LD      = 8'd86,

    // Default No-Operation
    ALU_NOP     = 8'd255
} ALUop;




typedef enum logic [6:0] {
    // Base Integer Instructions (RV32I and RV64I)
    OP_LUI       = 7'b0110111, // Load Upper Immediate
    OP_AUIPC     = 7'b0010111, // Add Upper Immediate to PC
    OP_JAL       = 7'b1101111, // Jump and Link
    OP_JALR      = 7'b1100111, // Jump and Link Register
    OP_BRANCH    = 7'b1100011, // Branch (BEQ, BNE, BLT, BGE, etc.)
    OP_LOAD      = 7'b0000011, // Load (LB, LH, LW, LBU, LHU, LD)
    OP_STORE     = 7'b0100011, // Store (SB, SH, SW, SD)
    OP_OP_IMM    = 7'b0010011, // Immediate Arithmetic (ADDI, SLTI, etc.)
    OP_OP        = 7'b0110011, // Register Arithmetic (ADD, SUB, AND, OR, etc.)
    
    // 32-bit Operations (RV32I, RV32M)
    OP_IMM_32    = 7'b0011011, // Immediate Arithmetic for 32-bit (ADDIW, SLLIW)
    OP_OP_32     = 7'b0111011, // Register Arithmetic for 32-bit (ADDW, SUBW, MULW, etc.)

    // Memory and Synchronization
    OP_MISC_MEM  = 7'b0001111, // Miscellaneous Memory (FENCE, FENCE.I)
    OP_SYSTEM    = 7'b1110011 // System Instructions (ECALL, EBREAK, CSR)

} Opcode;


// OP_IMM (Immediate Arithmetic Instructions)
typedef enum logic [2:0] {
  FUNCT3_OP_IMM_ADD  = 3'b000,  // ADDI
  FUNCT3_OP_IMM_SLL  = 3'b001,  // SLLI
  FUNCT3_OP_IMM_SLT  = 3'b010,  // SLTI
  FUNCT3_OP_IMM_SLTU = 3'b011,  // SLTIU
  FUNCT3_OP_IMM_XOR  = 3'b100,  // XORI
  FUNCT3_OP_IMM_SRL_SRA  = 3'b101,  // SRLI
  // FUNCT3_OP_IMM_SRA  = 3'b101,  // SRAI (funct7 differentiates)
  FUNCT3_OP_IMM_OR   = 3'b110,  // ORI
  FUNCT3_OP_IMM_AND  = 3'b111   // ANDI
} Funct3_OP_IMM;

// OP (Register-Register Arithmetic)
typedef enum logic [2:0] {
  FUNCT3_OP_ADD_SUB = 3'b000,  // ADD / SUB
  FUNCT3_OP_SLL     = 3'b001,  // SLL
  FUNCT3_OP_SLT     = 3'b010,  // SLT
  FUNCT3_OP_SLTU    = 3'b011,  // SLTU
  FUNCT3_OP_XOR     = 3'b100,  // XOR
  FUNCT3_OP_SRL_SRA = 3'b101,  // SRL / SRA
  FUNCT3_OP_OR      = 3'b110,  // OR
  FUNCT3_OP_AND     = 3'b111   // AND
} Funct3_OP;

// OP_IMM_32 / OP_32 (32-bit Arithmetic, RV64I)
typedef enum logic [2:0] {
  FUNCT3_OP_IMM_32_ADDW = 3'b000,  // ADDIW
  FUNCT3_OP_IMM_32_SLLW = 3'b001,  // SLLIW
  FUNCT3_OP_IMM_32_SRLW = 3'b101   // SRLIW / SRAIW
} Funct3_OP_IMM_32;

// LOAD (Load Instructions)
typedef enum logic [2:0] {
  FUNCT3_LOAD_B  = 3'b000,  // LB
  FUNCT3_LOAD_H  = 3'b001,  // LH
  FUNCT3_LOAD_W  = 3'b010,  // LW
  FUNCT3_LOAD_D  = 3'b011,  // LD (RV64I)
  FUNCT3_LOAD_BU = 3'b100,  // LBU
  FUNCT3_LOAD_HU = 3'b101,  // LHU
  FUNCT3_LOAD_WU = 3'b110   // LWU (RV64I)
} Funct3_LOAD;

// STORE (Store Instructions)
typedef enum logic [2:0] {
  FUNCT3_STORE_B = 3'b000,  // SB
  FUNCT3_STORE_H = 3'b001,  // SH
  FUNCT3_STORE_W = 3'b010,  // SW
  FUNCT3_STORE_D = 3'b011   // SD (RV64I)
} Funct3_STORE;

// SYSTEM (CSR Instructions)
typedef enum logic [2:0] {
  FUNCT3_CSRRW  = 3'b001,  // CSRRW
  FUNCT3_CSRRS  = 3'b010,  // CSRRS
  FUNCT3_CSRRC  = 3'b011,  // CSRRC
  FUNCT3_CSRRWI = 3'b101,  // CSRRWI
  FUNCT3_CSRRSI = 3'b110,  // CSRRSI
  FUNCT3_CSRRCI = 3'b111   // CSRRCI
} Funct3_SYSTEM;



// OP (Register-Register Arithmetic)
// funct7 for Standard Operations (ADD, SUB, SLL, SRL, SRA)
typedef enum logic [6:0] {
    FUNCT7_OP_STD     = 7'b0000000,  // Standard operations (ADD, SLL, SRL)
    FUNCT7_OP_SUB     = 7'b0100000,  // Subtraction and SRA
    FUNCT7_OP_MUL_DIV = 7'b0000001   // Multiplication and Division (M-extension)
} Funct7_OP;

// OP_32 (32-bit Arithmetic for RV64I)
typedef enum logic [6:0] {
    FUNCT7_OP_IMM_32_STD = 7'b0000000,  // Standard 32-bit operations (ADDW, SLLW, SRLW)
    FUNCT7_OP_IMM_32_SUB = 7'b0100000,  // Subtraction and SRAW (32-bit)
    FUNCT7_OP_IMM_32_MUL = 7'b0000001   // Multiply/Divide (M-extension, 32-bit)
} Funct7_OP_32;

// AMO (Atomic Memory Operations)
typedef enum logic [6:0] {
  FUNCT7_AMO_SWAP = 7'b0000100,  // Atomic SWAP
  FUNCT7_AMO_ADD  = 7'b0000000,  // Atomic ADD
  FUNCT7_AMO_XOR  = 7'b0000101,  // Atomic XOR
  FUNCT7_AMO_AND  = 7'b0000110,  // Atomic AND
  FUNCT7_AMO_OR   = 7'b0000111,  // Atomic OR
  FUNCT7_AMO_MIN  = 7'b0001000,  // Atomic MIN (signed)
  FUNCT7_AMO_MAX  = 7'b0001010,  // Atomic MAX (signed)
  FUNCT7_AMO_MINU = 7'b0001100,  // Atomic MINU (unsigned)
  FUNCT7_AMO_MAXU = 7'b0001110   // Atomic MAXU (unsigned)
} Funct7_AMO;

// funct3 for OP_OP_32 (32-bit Arithmetic)
typedef enum logic [2:0] {
    FUNCT3_OP_IMM_32_ADD     = 3'b000,  // ADDW, SUBW
    FUNCT3_OP_IMM_32_SLL     = 3'b001,  // SLLW
    FUNCT3_OP_IMM_32_SRL_SRA = 3'b101   // SRLW, SRAW
} Funct3_OP_32;

// funct7 for OP_OP_32 (32-bit Arithmetic)
typedef enum logic [6:0] {
    FUNCT7_STD = 7'b0000000,
    FUNCT7_SUB = 7'b0100000,
    FUNCT7_MUL = 7'b0000001
} Funct7_OP_OP_32;

typedef enum logic [2:0] {
  JUMP_NO      = 3'd0,
  JUMP_YES     = 3'd1,
  JUMP_ALU_EQZ = 3'd2,
  JUMP_ALU_NEZ = 3'd3,
  JUMP_ALU_LT  = 3'd4,
  JUMP_ALU_GE  = 3'd5,
  JUMP_ALU_LTU = 3'd6,
  JUMP_ALU_GEU = 3'd7
} Jump_Code;


// Privilege Modes
typedef enum bit [1:0] {
  PRIV_U = 0,
  PRIV_S = 1,
  PRIV_M = 3,
  PRIV_RESERVED = 2
} Privilege_Mode;

// Branch Function Codes
typedef enum logic [2:0] {
  F3B_BEQ   = 3'b000,  // Branch if Equal
  F3B_BNE   = 3'b001,  // Branch if Not Equal
  F3B_BLT   = 3'b100,  // Branch if Less Than
  F3B_BLTU  = 3'b110,  // Branch if Less Than Unsigned
  F3B_BGE   = 3'b101,  // Branch if Greater or Equal
  F3B_BGEU  = 3'b111   // Branch if Greater or Equal Unsigned
} BranchFunct3;

// CSR Function Codes
typedef enum logic [2:0] {
  F3SYS_PRIV = 3'b000,  // Privileged instructions (e.g., ECALL, EBREAK)
  F3SYS_CSRRW  = 3'b001,  // Atomic Read/Write CSR
  F3SYS_CSRRS  = 3'b010,  // Atomic Read/Set CSR
  F3SYS_CSRRC  = 3'b011,  // Atomic Read/Clear CSR
  F3SYS_CSRRWI = 3'b101,  // Atomic Immediate Write CSR
  F3SYS_CSRRSI = 3'b110,  // Atomic Immediate Set CSR
  F3SYS_CSRRCI = 3'b111   // Atomic Immediate Clear CSR
} CSRFunct3;


// Exception Causes
typedef enum logic [63:0] {
  MCAUSE_ECALL_U = 64'd8,   // Environment Call from User Mode
  MCAUSE_ECALL_S = 64'd9,   // Environment Call from Supervisor Mode
  MCAUSE_ECALL_M = 64'd11,  // Environment Call from Machine Mode
  MCAUSE_BREAKPOINT = 64'd3,// Breakpoint
  MCAUSE_ILLEGAL_INST = 64'd2 // Illegal Instruction
} MCause;
`endif
