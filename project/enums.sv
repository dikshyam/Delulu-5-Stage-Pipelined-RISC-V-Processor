// enums.sv
`ifndef ENUMS_SV
`define ENUMS_SV
// ALU Operations Enum

// typedef enum logic [4:0] {
//     // Arithmetic Operations
//     ALU_ADD    = 5'b00000,  // Addition (funct7 = 0000000, funct3 = 000)
//     ALU_SUB    = 5'b00001,  // Subtraction (funct7 = 0100000, funct3 = 000)

//     // Logical Operations
//     ALU_AND    = 5'b00111,  // AND (funct3 = 111)
//     ALU_OR     = 5'b00110,  // OR  (funct3 = 110)
//     ALU_XOR    = 5'b00100,  // XOR (funct3 = 100)

//     // Shift Operations
//     ALU_SLL    = 5'b00010,  // Shift Left Logical (funct3 = 001)
//     ALU_SRL    = 5'b00101,  // Shift Right Logical (funct7 = 0000000, funct3 = 101)
//     ALU_SRA    = 5'b00111,  // Shift Right Arithmetic (funct7 = 0100000, funct3 = 101)

//     // Comparisons
//     ALU_SLT    = 5'b01000,  // Set Less Than (signed) (funct3 = 010)
//     ALU_SLTU   = 5'b01001,  // Set Less Than (unsigned) (funct3 = 011)

//     // Multiplication and Division (RV32M, RV64M)
//     ALU_MUL    = 5'b01010,  // Multiply (funct7 = 0000001, funct3 = 000)
//     ALU_MULH   = 5'b01011,  // Multiply High (signed) (funct3 = 001)
//     ALU_MULHSU = 5'b01100,  // Multiply High (signed-unsigned)
//     ALU_MULHU  = 5'b01101,  // Multiply High (unsigned)
//     ALU_DIV    = 5'b01110,  // Divide (signed) (funct3 = 100)
//     ALU_DIVU   = 5'b01111,  // Divide (unsigned)
//     ALU_REM    = 5'b10000,  // Remainder (signed) (funct3 = 110)
//     ALU_REMU   = 5'b10001,  // Remainder (unsigned)

//     // RV64M Extension Operations
//     ALU_MULW   = 5'b10010,  // Multiply Word
//     ALU_DIVW   = 5'b10011,  // Divide Word (signed)
//     ALU_DIVUW  = 5'b10100,  // Divide Word (unsigned)
//     ALU_REMW   = 5'b10101,  // Remainder Word (signed)
//     ALU_REMUW  = 5'b10110,  // Remainder Word (unsigned)

//     // Default and No-Operation
//     ALU_NOP    = 5'b11111   // No operation
// } ALUop;

typedef enum logic [4:0] {
    // Basic Arithmetic (RV32I / RV64I)
    ALU_ADD    = 5'b00000,  // ADD (funct7 = 0000000, funct3 = 000)
    ALU_SUB    = 5'b00001,  // SUB (funct7 = 0100000, funct3 = 000)

    // Logical Operations
    ALU_AND    = 5'b00010,  // AND (funct3 = 111)
    ALU_OR     = 5'b00011,  // OR  (funct3 = 110)
    ALU_XOR    = 5'b00100,  // XOR (funct3 = 100)

    // Shift Operations (RV32I / RV64I)
    ALU_SLL    = 5'b00101,  // SLL  (funct3 = 001)
    ALU_SRL    = 5'b00110,  // SRL  (funct7 = 0000000, funct3 = 101)
    ALU_SRA    = 5'b00111,  // SRA  (funct7 = 0100000, funct3 = 101)

    // Comparisons (Set Less Than)
    ALU_SLT    = 5'b01000,  // SLT  (signed, funct3 = 010)
    ALU_SLTU   = 5'b01001,  // SLTU (unsigned, funct3 = 011)

    // Multiplication (RV32M / RV64M)
    ALU_MUL    = 5'b01010,  // MUL (funct7 = 0000001, funct3 = 000)
    ALU_MULH   = 5'b01011,  // MULH (signed, funct3 = 001)
    ALU_MULHSU = 5'b01100,  // MULHSU (signed-unsigned, funct3 = 010)
    ALU_MULHU  = 5'b01101,  // MULHU (unsigned, funct3 = 011)

    // Division and Modulus (RV32M / RV64M)
    ALU_DIV    = 5'b01110,  // DIV  (signed, funct3 = 100)
    ALU_DIVU   = 5'b01111,  // DIVU (unsigned, funct3 = 101)
    ALU_REM    = 5'b10000,  // REM  (signed, funct3 = 110)
    ALU_REMU   = 5'b10001,  // REMU (unsigned, funct3 = 111)

    // RV64M Extension (Word Operations)
    ALU_MULW   = 5'b10010,  // MULW (funct3 = 000, RV64)
    ALU_DIVW   = 5'b10011,  // DIVW (signed, funct3 = 100, RV64)
    ALU_DIVUW  = 5'b10100,  // DIVUW (unsigned, funct3 = 101, RV64)
    ALU_REMW   = 5'b10101,  // REMW (signed, funct3 = 110, RV64)
    ALU_REMUW  = 5'b10110,  // REMUW (unsigned, funct3 = 111, RV64)

    // RV64I Word Arithmetic (W-type)
    ALU_ADDW   = 5'b10111,  // ADDW
    ALU_SUBW   = 5'b11000,  // SUBW
    ALU_SLLW   = 5'b11001,  // SLLW
    ALU_SRLW   = 5'b11010,  // SRLW
    ALU_SRAW   = 5'b11011,  // SRAW
    
    // Default No-Operation (NOP)
    ALU_NOP    = 5'b11111   // No Operation -> 31
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
    // OP_AMO       = 7'b0101111, // Atomic Memory Operations (AMOADD, AMOSWAP)

    // Multiplication/Division (M extension for RV32M/RV64M)
    // OP_MUL_DIV   = 7'b0110011, // M-Extension (MUL, DIV, REM for RV32M/RV64M)

    // Atomic Instructions (RV64A and RV32A)
    // OP_AMO_W     = 7'b0101111, // Atomic Memory Operations (32-bit)
    // OP_AMO_D     = 7'b0101111, // Atomic Memory Operations (64-bit)

    // Floating Point (Placeholder if needed)
    // OP_LOAD_FP   = 7'b0000111, // Floating-point Loads
    // OP_STORE_FP  = 7'b0100111, // Floating-point Stores
    // OP_FP        = 7'b1010011, // Floating-point Operations

    // Custom Extensions (Reserved)
    // OP_CUSTOM_0  = 7'b0001011, // Custom Instruction 0
    // OP_CUSTOM_1  = 7'b0101011  // Custom Instruction 1

} Opcode;



// Funct3 Enum
// typedef enum logic [2:0] {
//   FUNCT3_ADD_SUB  = 3'b000,  // ADD, SUB, MUL
//   FUNCT3_SLL      = 3'b001,  // SLL, MULH
//   FUNCT3_SLT      = 3'b010,  // SLT, MULHSU
//   FUNCT3_SLTU     = 3'b011,  // SLTU, MULHU
//   FUNCT3_XOR      = 3'b100,  // XOR, DIV
//   FUNCT3_SRL_SRA  = 3'b101,  // SRL, SRA, DIVU
//   FUNCT3_OR       = 3'b110,  // OR, REM
//   FUNCT3_AND      = 3'b111   // AND, REMU
// } Funct3;

// typedef enum logic [2:0] {
//   FUNCT3_ADD_SUB_MUL = 3'b000,  // ADD / SUB
//   FUNCT3_SLL_MULH     = 3'b001,  // Shift Left Logical
//   FUNCT3_SLT_MULHSU     = 3'b010,  // Set Less Than
//   FUNCT3_SLTU_MULHU    = 3'b011,  // Set Less Than Unsigned
//   FUNCT3_XOR_DIV     = 3'b100,  // XOR
//   FUNCT3_SRL_SRA_DIVU = 3'b101,  // Shift Right Logical / Shift Right Arithmetic
//   FUNCT3_OR_REM      = 3'b110,  // OR
//   FUNCT3_AND_REMU     = 3'b111  // AND
//   // FUNCT3_MUL     = 3'b000,  // Multiply (RV32M)
//   // FUNCT3_MULH    = 3'b001,  // Multiply High (signed)
//   // FUNCT3_MULHSU  = 3'b010,  // Multiply High (signed * unsigned)
//   // FUNCT3_MULHU   = 3'b011,  // Multiply High Unsigned
//   // FUNCT3_DIV     = 3'b100,  // Divide (signed)
//   // FUNCT3_DIVU    = 3'b101,  // Divide Unsigned
//   // FUNCT3_REM     = 3'b110,  // Remainder (signed)
//   // FUNCT3_REMU    = 3'b111   // Remainder Unsigned
// } Funct3;

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

// BRANCH (Branch Instructions)
typedef enum logic [2:0] {
  FUNCT3_BRANCH_EQ  = 3'b000,  // BEQ
  FUNCT3_BRANCH_NE  = 3'b001,  // BNE
  FUNCT3_BRANCH_LT  = 3'b100,  // BLT
  FUNCT3_BRANCH_GE  = 3'b101,  // BGE
  FUNCT3_BRANCH_LTU = 3'b110,  // BLTU
  FUNCT3_BRANCH_GEU = 3'b111   // BGEU
} Funct3_BRANCH;

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

// M (Multiplication and Division for RV32M / RV64M)
// typedef enum logic [6:0] {
//   FUNCT7_M_MUL   = 7'b0000001,  // MUL
//   FUNCT7_M_DIV   = 7'b0000001,  // DIV
//   FUNCT7_M_DIVU  = 7'b0000001,  // DIVU
//   FUNCT7_M_REM   = 7'b0000001,  // REM
//   FUNCT7_M_REMU  = 7'b0000001   // REMU
// } Funct7_M;

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




// Jump Codes
typedef enum bit [1:0] {
  JUMP_NO      = 2'b00,
  JUMP_YES     = 2'b01,
  JUMP_ALU_EQZ = 2'b10,
  JUMP_ALU_NEZ = 2'b11
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
