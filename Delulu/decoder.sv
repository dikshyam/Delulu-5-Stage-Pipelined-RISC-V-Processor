// `include "Sysbus.defs"
// `include "outputs.sv"

`include "enums.sv"
`include "control_signals_struct.svh"


module Decoder (
    input  logic        clk,                  // Clock input
    input  logic        reset,                // Reset input
    input  logic [31:0] inst,                 // 32-bit instruction
    input  logic        decode_enable,                // Enable signal to trigger decode
    input  logic [63:0] pc,                   // Program counter for the instruction
    // input  logic [63:0] clk_counter,          // Clock cycle count (for tracing/debugging)
    output logic [4:0] rs1_data,
    output logic [4:0] rs2_data,
    output logic [4:0] rd,

    output decoder_output out,               // Structured decode output

    output logic        decode_complete,     // Goes high for 1 cycle after decode finishes

    // input  logic [1:0]  curr_priv_mode,      // Privilege mode (optional)
    output logic        exception_detected,            // Trap trigger
    output logic [63:0] exception_detected_cause,      // Cause of trap
    output logic [63:0] exception_detected_val,         // Trap value
    input enable_logging
);

    logic [63:0] immed_I;
    logic [63:0] immed_S;
    logic [63:0] immed_SB;
    logic [63:0] immed_U;
    logic [63:0] immed_UJ, immed_AUIPC, immed_LUI;

    // Instruction fields
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [6:0] op_code;

    // Shift amount
    logic [4:0] shamt;
    logic [63:0] immed_I_shamt;
    // File handle for decoder error logging
    integer decoder_error_logfile;
    logic [63:0] exception_cause;
    string exception_details;
    integer decoder_trace_logfile;

    // In your initialization/reset logic:
    initial begin
        // Open decoder error log file for writing
        decoder_error_logfile = $fopen("/home/dimohanty/CSE-502-ComputerArchitecture/Delulu/logs/decoder_errors.log", "w");
        if (!decoder_error_logfile) begin
            $display("[DECODER] ERROR: Failed to open error log file");
        end else begin
            $fwrite(decoder_error_logfile, "TIME,PC,INSTRUCTION,ERROR_TYPE,DETAILS\n");
            // $display("[DECODER] Error logging enabled to decoder_errors.log");
        end
        decoder_trace_logfile = $fopen("/home/dimohanty/CSE-502-ComputerArchitecture/Delulu/logs/decoder_trace.log", "w");
        if (!decoder_trace_logfile) begin
            $display("[DECODER] ERROR: Failed to open trace log file");
        end else begin
            $fwrite(decoder_trace_logfile, "TIME,PC,INSTRUCTION,OPCODE,FUNCT3,RS1,RS2,RD,JUMP_IF,ALU_OP,BRANCH_TAKEN,JUMP_ABS,REG_WRITE,MEM_READ,MEM_WRITE,MEM_TO_REG,IS_LOAD,IS_STORE,IS_ECALL,IS_BREAK,ALU_WIDTH_32,SIGNED_TYPE,ALU_USE_IMMED,DATA_SIZE,DATA_SIGN\n");
        end
    end


    always_comb begin
        // check if decode is enabled
        if (decode_enable) begin
            if (reset) begin

                decode_complete = 0;
                out = '0;
                // Initialize all outputs explicitly
                // out.rs1            = 5'd0;
                // out.rs2            = 5'd0;
                // out.rd             = 5'd0;
                // out.en_rs1         = 1'b0;
                // out.en_rs2         = 1'b0;
                // out.en_rd          = 1'b0;
                // out.funct3         = 3'b000;
                // out.funct7         = 7'b0000000;
                // out.immed          = 64'd0;
                // out.alu_op         = ALU_NOP;
                // out.jump_if        = JUMP_NO;
                // out.jump_absolute  = 1'b0;

                exception_detected           = 1'b0;
                exception_detected_cause     = 64'd0;
                exception_detected_val       = 64'd0;
            end else if (inst == 32'b0) begin
                // $display("[DECODE] NOP Detected: ADDI x0, x0, 0 at PC=%h", pc);
                // // $display("[DECODE] NOP detected at PC=%h", pc);
                exception_detected = 0;
                out.instruction   = inst;
                out.pc            = pc;

                // Operands
                out.rs1           = 5'd0;
                out.rs2           = 5'd0;
                out.rd            = 5'd0;
                out.immed         = 64'd0;

                // Control signals
                out.alu_op        = ALU_NOP;
                out.mem_read      = 0;
                out.mem_write     = 0;
                out.reg_write     = 0;
                out.mem_to_reg    = 0;
                out.jump_signal   = 0;
                out.jump_if       = JUMP_NO;
                out.jump_absolute = 0;
                rs1_data = out.rs1;
                rs2_data = out.rs2;
                rd = out.rd;
                decode_complete = 1;


            end else if (inst != 32'b0) begin
                exception_detected           = 1'b0;
                exception_detected_cause     = 64'd0;
                exception_detected_val       = 64'd0;
                out.pc = pc;
                out.instruction = inst;

                immed_I       = {{52{inst[31]}}, inst[31:20]};
                immed_S       = {{52{inst[31]}}, inst[31:25], inst[11:7]};
                immed_SB      = {{51{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
                immed_U       = {{32{inst[31]}}, inst[31:12], 12'b0};
                immed_UJ      = {{43{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
                // immed_AUIPC = {{52{inst[31]}}, inst[31:20]} << 12;
                // immed_LUI = {inst[31:12], 12'b0};

                funct3        = inst[14:12];
                funct7        = inst[31:25];
                op_code       = inst[6:0];

                shamt         = inst[25:20];
                immed_I_shamt = {{59{1'b0}}, shamt};

                // immed_I_shamt = shamt;

                out.op_code = op_code;
                // Extract fields
                out.rs1 = inst[19:15];
                out.rs2 = inst[24:20];
                out.rd  = inst[11:7];
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b000;

                out.funct3 = funct3;
                out.funct7 = funct7;
                out.immed  = 0;

                out.alu_op       = ALU_NOP;
                out.jump_if      = JUMP_NO;
                out.jump_absolute = 1'b0;
                out.jump_signal   = 1'b0;

                out.reg_write = 0;
                out.mem_read = 0;
                out.mem_write = 0;
                out.mem_to_reg = 0;

                out.is_load      = 1'b0;
                out.is_store     = 1'b0;
                out.is_ecall     = 1'b0;
                out.is_break     = 1'b0;
                // out.is_csr       = 1'b0;
                

                out.alu_width_32 = 0;
                out.signed_type = 0;
                out.alu_use_immed = 0;
                out.data_size = 0;
                out.data_sign = 0;
                
                // $display("[DECODE] Decoding instruction: %h at PC: %h | clk: %0d", inst, pc, clk);

                rs1_data = (out.rs1 != 5'b0) ? out.rs1 : 64'h0;
                rs2_data = (out.rs2 != 5'b0) ? out.rs2 : 64'h0;
                
                // Instruction decoding logic
                case (op_code)

                    // LUI and AUIPC // Updated
                    OP_LUI: begin
                        out.immed = immed_U;
                        out.reg_write = 1;
                        out.alu_use_immed = 1;
                        out.alu_op = ALU_LUI;
                        out.signed_type = 1;
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b001;
                    end

                    OP_AUIPC: begin
                        out.immed = immed_U;
                        out.reg_write = 1;
                        out.alu_op = ALU_AUIPC;
                        out.alu_use_immed = 1;
                        out.signed_type = 1;
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b001;
                    end

                    // Jump Instructions // Updated
                    OP_JAL: begin
                        out.immed = immed_UJ;
                        out.reg_write = 1;
                        out.alu_use_immed = 1;
                        out.jump_if = JUMP_YES;
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b001;
                        out.alu_op = ALU_JAL;               
                    end
                    
                    OP_JALR: begin
                        out.immed = immed_I;
                        out.alu_use_immed = 1;
                        out.reg_write = 1;
                        out.jump_if = JUMP_YES;
                        out.jump_absolute = 1;
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b101;
                        out.alu_op = ALU_JALR;               
                    end

                    // Updated
                    OP_BRANCH: begin
                        out.immed = immed_SB;
                        
                        case (funct3)
                            F3B_BEQ: begin
                                out.alu_op = ALU_BEQ;
                                out.jump_if = JUMP_ALU_EQZ;
                                out.signed_type = 1; // Equality comparisons can be signed or unsigned (doesn't matter)
                            end
                            F3B_BNE: begin
                                out.alu_op = ALU_BNE;
                                out.jump_if = JUMP_ALU_NEZ;
                                out.signed_type = 1; // Equality comparisons can be signed or unsigned (doesn't matter)
                            end
                            F3B_BLT: begin
                                out.alu_op = ALU_BLT;
                                out.jump_if = JUMP_ALU_LT;
                                out.signed_type = 1; // Signed comparison
                            end
                            F3B_BGE: begin
                                out.alu_op = ALU_BGE;
                                out.jump_if = JUMP_ALU_GE;
                                out.signed_type = 1; // Signed comparison
                            end
                            F3B_BLTU: begin
                                out.alu_op = ALU_BLTU;
                                out.jump_if = JUMP_ALU_LTU;
                                out.signed_type = 0; // Unsigned comparison
                            end
                            F3B_BGEU: begin
                                out.alu_op = ALU_BGEU;
                                out.jump_if = JUMP_ALU_GEU;
                                out.signed_type = 0; // Unsigned comparison
                            end
                            default: begin
                                exception_detected = 1'b1;
                                exception_cause = MCAUSE_ILLEGAL_INST;
                                exception_details = $sformatf("Invalid branch funct3 field: %b", funct3);
                            end
                        endcase
                    
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b110;
                        out.rd = 0;
                        rd = 0;
                    end

                    // Load Instructions // Updated
                    OP_LOAD: begin
                        out.immed = immed_I;
                        out.reg_write = 1;
                        out.mem_read = 1;
                        out.mem_to_reg = 1;
                        out.is_load = 1;
                        out.alu_use_immed = 1;
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b101;
                        out.data_sign = 0;
                        // Use enum values from Funct3_LOAD
                        case (funct3)
                            FUNCT3_LOAD_B:  begin 
                                out.alu_op = ALU_LB;
                                out.data_size = 3'b001; 
                                out.data_sign = 1; 
                            end 
                            FUNCT3_LOAD_H:  begin 
                                out.alu_op = ALU_LH;
                                out.data_size = 3'b010; 
                                out.data_sign = 1; 
                            end 
                            FUNCT3_LOAD_W:  begin 
                                out.alu_op = ALU_LW;
                                out.data_size = 3'b100; 
                                out.data_sign = 1; 
                            end 
                            FUNCT3_LOAD_D:  begin 
                                out.alu_op = ALU_LD;
                                out.data_size = 3'b111; 
                                out.data_sign = 1; 
                            end 
                            FUNCT3_LOAD_BU: begin 
                                out.alu_op = ALU_LBU;
                                out.data_size = 3'b001; 
                                out.data_sign = 0; 
                            end 
                            FUNCT3_LOAD_HU: begin 
                                out.alu_op = ALU_LHU;
                                out.data_size = 3'b010; 
                                out.data_sign = 0; 
                            end 
                            FUNCT3_LOAD_WU: begin 
                                out.alu_op = ALU_LWU;
                                out.data_size = 3'b100; 
                                out.data_sign = 0; 
                            end 
                            default:        begin 
                                exception_detected = 1'b1;
                                exception_cause = MCAUSE_ILLEGAL_INST;
                                exception_details = $sformatf("Invalid load funct3 field: %b", funct3);
                                out.data_size = 3'b000; 
                                out.data_sign = 0; 
                                exception_detected = 1; 
                            end
                        endcase
                    end
                    

                    // Store Instructions // Updated
                    OP_STORE: begin
                        out.immed = immed_S;
                        out.mem_write = 1;
                        out.alu_use_immed = 1;
                        out.is_store = 1;
                        out.data_sign = 1;;
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b110;
                        
                        case (funct3)
                            FUNCT3_STORE_B: begin
                                out.alu_op = ALU_SB;
                                out.data_size = 3'b001; // SB
                            end
                            FUNCT3_STORE_H: begin
                                out.alu_op = ALU_SH;
                                out.data_size = 3'b010; // SH
                            end
                            FUNCT3_STORE_W: begin
                                out.alu_op = ALU_SW;
                                out.data_size = 3'b100; // SW
                            end
                            FUNCT3_STORE_D: begin
                                out.alu_op = ALU_SD;
                                out.data_size = 3'b111; // SD
                            end
                            default: begin
                                out.data_size = 3'b000;
                                exception_detected = 1;
                                exception_cause = MCAUSE_ILLEGAL_INST;
                                exception_details = $sformatf("Invalid store funct3 field: %b", funct3);
                            end
                        endcase
                    end
                    

                    // Immediate Arithmetic // Updated
                    OP_OP_IMM: begin
                        // Handle shift-type immediates separately
                        if (funct3 == FUNCT3_OP_IMM_SLL || funct3 == FUNCT3_OP_IMM_SRL_SRA) begin
                            out.immed = immed_I_shamt;
                            out.shamt = inst[25:20];
                            out.signed_type = 0; // shift amounts are unsigned!
                        end else if (funct3 == FUNCT3_OP_IMM_SLTU) begin
                            out.immed = immed_I;
                            out.signed_type = 0; // SLTIU uses unsigned comparison
                        end else begin 
                            out.immed = immed_I;
                            out.signed_type = 1; // Other operations use signed comparison
                        end

                        out.alu_use_immed = 1;
                        out.reg_write = 1;
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b101;
                        
                        // Decode operation using funct3 (+ funct7 for SRL/SRA)
                        case (funct3)
                            FUNCT3_OP_IMM_ADD:     out.alu_op = ALU_ADDI;                        // ADDI 
                            FUNCT3_OP_IMM_SLL:     out.alu_op = ALU_SLLI;                        // SLLI
                            FUNCT3_OP_IMM_SLT:     out.alu_op = ALU_SLTI;                        // SLTI
                            FUNCT3_OP_IMM_SLTU:    out.alu_op = ALU_SLTIU;                       // SLTIU
                            FUNCT3_OP_IMM_XOR:     out.alu_op = ALU_XORI;                        // XORI
                            FUNCT3_OP_IMM_SRL_SRA: out.alu_op = (funct7 == 7'b0100000) 
                                                                ? ALU_SRAI : ALU_SRLI;           // SRLI / SRAI
                            FUNCT3_OP_IMM_OR:      out.alu_op = ALU_ORI;                         // ORI
                            FUNCT3_OP_IMM_AND:     out.alu_op = ALU_ANDI;                        // ANDI
                            default: begin 
                                exception_detected = 1'b1;
                                exception_cause = MCAUSE_ILLEGAL_INST;
                                exception_details = $sformatf("Invalid immediate shift instruction: funct3=%b, funct7=%b", funct3, funct7);
                            end
                        endcase
                    end
                    


                    // Register Arithmetic
                    OP_OP: begin
                        out.reg_write = 1;
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b111;
                    
                        case (funct7)
                            FUNCT7_OP_STD: begin  // Standard Arithmetic (funct7 = 0000000)
                                case (funct3)
                                    FUNCT3_OP_ADD_SUB:  out.alu_op = ALU_ADD;  // ADD
                                    FUNCT3_OP_SLL:      out.alu_op = ALU_SLL;  // SLL
                                    FUNCT3_OP_SLT:      out.alu_op = ALU_SLT;  // SLT
                                    FUNCT3_OP_SLTU:     out.alu_op = ALU_SLTU; // SLTU
                                    FUNCT3_OP_XOR:      out.alu_op = ALU_XOR;  // XOR
                                    FUNCT3_OP_OR:       out.alu_op = ALU_OR;   // OR
                                    FUNCT3_OP_AND:      out.alu_op = ALU_AND;  // AND
                                    FUNCT3_OP_SRL_SRA:  out.alu_op = ALU_SRL;  // SRL
                                    default: begin
                                        exception_detected = 1'b1;
                                        exception_cause = MCAUSE_ILLEGAL_INST;
                                        exception_details = $sformatf("Invalid R-extension funct3: funct3=%b, funct7=%b", funct3, funct7);
                                    end
                                endcase
                            end
                    
                            FUNCT7_OP_SUB: begin  // Subtraction or SRA (funct7 = 0100000)
                                case (funct3)
                                    FUNCT3_OP_ADD_SUB:  out.alu_op = ALU_SUB;  // SUB
                                    FUNCT3_OP_SRL_SRA:  out.alu_op = ALU_SRA;  // SRA
                                    default: begin
                                        exception_detected = 1'b1;
                                        exception_cause = MCAUSE_ILLEGAL_INST;
                                        exception_details = $sformatf("Invalid R-extension funct3: %b", funct3);
                                    end
                                endcase
                            end
                    
                            FUNCT7_OP_MUL_DIV: begin  // Multiply/Divide (funct7 = 0000001, RV32M/RV64M)
                                case (funct3)
                                    FUNCT3_OP_ADD_SUB:  out.alu_op = ALU_MUL;   // MUL
                                    FUNCT3_OP_SLL:      out.alu_op = ALU_MULH;  // MULH
                                    FUNCT3_OP_SLT:      out.alu_op = ALU_MULHSU;// MULHSU
                                    FUNCT3_OP_SLTU:     out.alu_op = ALU_MULHU; // MULHU
                                    FUNCT3_OP_XOR:      out.alu_op = ALU_DIV;   // DIV
                                    FUNCT3_OP_SRL_SRA:  out.alu_op = ALU_DIVU;  // DIVU
                                    FUNCT3_OP_OR:       out.alu_op = ALU_REM;   // REM
                                    FUNCT3_OP_AND:      out.alu_op = ALU_REMU;  // REMU
                                    default: begin
                                        exception_detected = 1'b1;
                                        exception_cause = MCAUSE_ILLEGAL_INST;
                                        exception_details = $sformatf("Invalid M-extension funct3: %b", funct3);
                                    end
                                endcase
                            end
                    
                            default: begin
                                exception_detected = 1'b1;
                                exception_cause = MCAUSE_ILLEGAL_INST;
                                exception_details = $sformatf("Invalid OP instruction: funct3=%b, funct7=%b", funct3, funct7);
                            end
                        endcase
                    end
                    
                    // Updated
                    OP_IMM_32: begin
                        out.immed = immed_I;
                        out.alu_use_immed = 1;
                        out.reg_write = 1;
                        out.alu_width_32 = 1;  // Mark this as a 32-bit operation
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b101;  // Use rs1 and rd, no rs2
                        out.signed_type = 1;

                        case (funct3)
                            FUNCT3_OP_IMM_32_ADD: begin
                                out.alu_op = ALU_ADDIW;  // ADDIW (Immediate Add Word)
                            end
                    
                            FUNCT3_OP_IMM_32_SLL: begin
                                out.immed = immed_I_shamt;  // Use shift amount for SLLIW
                                out.alu_op = ALU_SLLIW;       // SLLIW (Shift Left Logical Immediate Word)
                                out.signed_type = 0; 
                            end
                    
                            FUNCT3_OP_IMM_32_SRL_SRA: begin
                                out.immed = immed_I_shamt;  // Use shift amount for SRLIW/SRAIW
                                case (funct7)
                                    FUNCT7_OP_IMM_32_STD:  begin 
                                        out.alu_op = ALU_SRLIW;  // SRLIW
                                        out.signed_type = 0; 
                                    end
                                    FUNCT7_OP_IMM_32_SUB:  begin
                                        out.alu_op = ALU_SRAIW;  // SRAIW
                                        out.signed_type = 0;
                                    end
                                    default: exception_detected = 1;  // Illegal instruction trap
                                endcase
                            end
                    
                            default: exception_detected = 1;  // Illegal instruction trap
                        endcase
                    end
                    
                    
                    // Register Arithmetic (32-bit, RV64I) // Updated
                    OP_OP_32: begin
                        out.reg_write = 1;
                        out.alu_width_32 = 1;  // Indicate 32-bit ALU operation
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b111;

                        // Set default signed type
                        out.signed_type = 1;  // Most 32-bit operations are signed by default

                        case (funct7)
                            FUNCT7_OP_IMM_32_STD: begin
                                case (funct3)
                                    FUNCT3_OP_IMM_32_ADD: begin  
                                        out.alu_op = ALU_ADDW;  // ADDW
                                        out.signed_type = 1;    // Signed operation
                                    end
                                    FUNCT3_OP_IMM_32_SLL: begin  
                                        out.alu_op = ALU_SLLW;  // SLLW
                                        out.signed_type = 0;    // Shift amount is unsigned
                                    end
                                    FUNCT3_OP_IMM_32_SRL_SRA: begin 
                                        out.alu_op = ALU_SRLW;  // SRLW
                                        out.signed_type = 0;    // Logical shift is unsigned
                                    end
                                    default: begin
                                        exception_detected = 1'b1;
                                        exception_cause = MCAUSE_ILLEGAL_INST;
                                        exception_details = $sformatf("Invalid SLLIW instruction: funct7=%b", funct7);
                                    end
                                endcase
                            end

                            FUNCT7_OP_IMM_32_SUB: begin
                                case (funct3)
                                    FUNCT3_OP_IMM_32_ADD: begin  
                                        out.alu_op = ALU_SUBW;  // SUBW
                                        out.signed_type = 1;    // Signed operation
                                    end
                                    FUNCT3_OP_IMM_32_SRL_SRA: begin 
                                        out.alu_op = ALU_SRAW;  // SRAW
                                        out.signed_type = 1;    // Arithmetic shift preserves sign
                                    end
                                    default: begin
                                        exception_detected = 1'b1;
                                        exception_cause = MCAUSE_ILLEGAL_INST;
                                        exception_details = $sformatf("Invalid SRAIW/SRAIW instruction: funct7=%b", funct7);
                                    end
                                endcase
                            end

                            FUNCT7_OP_IMM_32_MUL: begin  // RV64M Multiplication and Division for 32-bit
                                case (funct3)
                                    3'b000: begin
                                        out.alu_op = ALU_MULW;   // MULW
                                        out.signed_type = 1;     // Signed multiplication
                                    end
                                    3'b100: begin
                                        out.alu_op = ALU_DIVW;   // DIVW
                                        out.signed_type = 1;     // Signed division
                                    end
                                    3'b101: begin
                                        out.alu_op = ALU_DIVUW;  // DIVUW
                                        out.signed_type = 0;     // Unsigned division
                                    end
                                    3'b110: begin
                                        out.alu_op = ALU_REMW;   // REMW
                                        out.signed_type = 1;     // Signed remainder
                                    end
                                    3'b111: begin
                                        out.alu_op = ALU_REMUW;  // REMUW
                                        out.signed_type = 0;     // Unsigned remainder
                                    end
                                    default: begin
                                        exception_detected = 1'b1;
                                        exception_cause = MCAUSE_ILLEGAL_INST;
                                        exception_details = $sformatf("Invalid OP_IMM_32 funct3 field: %b", funct3);   
                                    end                         
                                endcase
                            end

                            default: begin
                                exception_detected = 1'b1;
                                exception_cause = MCAUSE_ILLEGAL_INST;
                                exception_details = $sformatf("Invalid OP_OP_32 instruction: funct3=%b, funct7=%b", funct3, funct7);
                            end
                        endcase
                    end

                    // Miscellaneous Memory Operations (Fence)
                    OP_MISC_MEM: begin
                        case (funct3)
                            3'b000: begin
                                // out.is_sfence_vma = 1;  // FENCE instruction
                                out.reg_write = 0;
                                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b000;
                            end
                            default: exception_detected = 1;
                        endcase
                    end

                    OP_SYSTEM: begin
                        out.reg_write = 1;
                        case (funct3)
                    
                            F3SYS_PRIV: begin  // ECALL and EBREAK
                                case (inst[31:20])
                                    12'h000: begin
                                        out.is_ecall = 1;
                                        out.reg_write = 1;       
                                        out.rd = 5'd10; // a0 - as required by the project
                                        out.alu_op = ALU_ECALL;
                                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b001;
                                    end
                                    12'h001: begin
                                        out.is_break = 1;
                                        out.reg_write = 0;
                                        out.rd = 0;
                                        rd = 0;
                                        out.alu_op = ALU_EBREAK;
                                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b101;
                                    end
                                    default: begin
                                        exception_detected = 1'b1;
                                        exception_cause = MCAUSE_ILLEGAL_INST;
                                        exception_details = $sformatf("Invalid SYSTEM instruction imm field: 0x%h", inst[31:20]);
                                    end
                                endcase
                            end
                    
                            // F3SYS_CSRRW, F3SYS_CSRRS, F3SYS_CSRRC,
                            // F3SYS_CSRRWI, F3SYS_CSRRSI, F3SYS_CSRRCI: begin
                            //     out.is_csr = 1;
                            //     out.csr_immed = funct3[2]; // CSRxI immediate variants
                            //     out.csr_rw = (funct3 == F3SYS_CSRRW || funct3 == F3SYS_CSRRWI);
                            //     out.csr_rs = (funct3 == F3SYS_CSRRS || funct3 == F3SYS_CSRRSI);
                            //     out.csr_rc = (funct3 == F3SYS_CSRRC || funct3 == F3SYS_CSRRCI);
                            //     out.rd = inst[11:7];
                            // end
                    
                            default: begin
                                exception_detected = 1'b1;
                                exception_cause = MCAUSE_ILLEGAL_INST;
                                exception_details = $sformatf("Invalid SYSTEM instruction imm field: 0x%h", inst[31:20]);
                            end
                        endcase
                    
                        // Immediate for SYSTEM ops (can be used for CSRs or trap handling)
                        out.immed = {52'b0, inst[31:20]};
                    end
                    

                    
                
                    default: begin
                        // Unknown opcode
                        exception_detected = 1'b1;
                        exception_cause = MCAUSE_ILLEGAL_INST;
                        exception_details = $sformatf("Unknown opcode: 0x%h", op_code);
                    end
                    
                endcase

                // Modified // $display with ALU op as string
                // // $display("[DEBUG DECODE] PC=%h | Inst=%h | rs1=%d | rs2=%d | rd=%d | ALU_OP=%s | RegWrite=%b | rs1_data=%h | rs2_data=%h | op_code=%h",
                //  pc, inst, out.rs1, out.rs2, out.rd, alu_op_to_string(out.alu_op), out.reg_write, out.rs1_data, out.rs2_data, op_code);
                
                // Assign registers only if enabled
                out.rs1 = out.en_rs1 ? inst[19:15] : 5'd0;
                out.rs2 = out.en_rs2 ? inst[24:20] : 5'd0;
                // out.rd  = (out.en_rd && out.rd ==0)  ? inst[11:7]  : out.rd;
                if (!out.is_ecall) begin
                    if (out.en_rd) begin
                    // Normal instructions
                        out.rd = inst[11:7];
                    end else begin
                        // No destination register
                        out.rd = 5'd0;
                    end
                end

                rs1_data = out.rs1;
                rs2_data = out.rs2;
                rd = out.rd;

                // $display("[DEBUG DECODE] PC=%h | Inst=%h | opcode=%s | ALU_OP=%s | RegWrite=%b | MemRead=%b | MemWrite=%b | MemToReg=%b",
                // pc, inst,
                // opcode_to_string(out.op_code),
                // alu_op_to_string(out.alu_op),
                // out.reg_write,
                // out.mem_read,
                // out.mem_write,
                // out.mem_to_reg);
                

                // $display("[DEBUG DECODE] PC=%h | Inst=%h | rs1=%d | rs2=%d | rd=%0d", pc, inst, out.rs1, out.rs2, out.rd);
                decode_complete = 1;

            end
        
            
        end else begin 
            decode_complete = 0;
        end
        
    if (enable_logging) begin
        if (decoder_trace_logfile && decode_complete && inst != 32'b0) begin
            // Basic instruction info
            $fwrite(decoder_trace_logfile, "%0t,", $time);
            $fwrite(decoder_trace_logfile, "%h,", out.pc);
            $fwrite(decoder_trace_logfile, "%h,", out.instruction);
            $fwrite(decoder_trace_logfile, "%s,", out.op_code.name());
            
            // Register fields
            $fwrite(decoder_trace_logfile, "%h,", out.funct3);
            $fwrite(decoder_trace_logfile, "%h,", out.rs1);
            $fwrite(decoder_trace_logfile, "%h,", out.rs2);
            $fwrite(decoder_trace_logfile, "%h,", out.rd);
            
            // Control signals
            $fwrite(decoder_trace_logfile, "%s,", out.jump_if.name());
            $fwrite(decoder_trace_logfile, "%s,", out.alu_op.name());
            $fwrite(decoder_trace_logfile, "%b,", (out.jump_signal && out.jump_if != JUMP_NO));
            $fwrite(decoder_trace_logfile, "%b,", out.jump_absolute);
            
            // Memory signals
            $fwrite(decoder_trace_logfile, "%b,", out.reg_write);
            $fwrite(decoder_trace_logfile, "%b,", out.mem_read);
            $fwrite(decoder_trace_logfile, "%b,", out.mem_write);
            $fwrite(decoder_trace_logfile, "%b,", out.mem_to_reg);
            
            // Instruction type flags
            $fwrite(decoder_trace_logfile, "%b,", out.is_load);
            $fwrite(decoder_trace_logfile, "%b,", out.is_store);
            $fwrite(decoder_trace_logfile, "%b,", out.is_ecall);
            $fwrite(decoder_trace_logfile, "%b,", out.is_break);
            
            // ALU configuration
            $fwrite(decoder_trace_logfile, "%b,", out.alu_width_32);
            $fwrite(decoder_trace_logfile, "%b,", out.signed_type);
            $fwrite(decoder_trace_logfile, "%b,", out.alu_use_immed);
            
            // Data access info
            $fwrite(decoder_trace_logfile, "%h,", out.data_size);
            $fwrite(decoder_trace_logfile, "%b\n", out.data_sign);
        end
        // Log exceptions
        if (exception_detected && decoder_error_logfile && inst !=32'b0) begin
            $fwrite(decoder_error_logfile, "%0d,", $time);
            $fwrite(decoder_error_logfile, "%h,", pc);
            $fwrite(decoder_error_logfile, "%h,", inst);
            $fwrite(decoder_error_logfile, "EXCEPTION,");
            $fwrite(decoder_error_logfile, "%h,", exception_cause);
            $fwrite(decoder_error_logfile, "%s\n", exception_details);
            
            // $display("[DECODER_EXCEPTION] Time=%0t | PC=%h | Instr=%h | Cause=MCAUSE_ILLEGAL_INST | %s", 
            //          $time, pc, inst, exception_details);
        end
    
    // Close file on simulation end
    end
    end

    final begin
        if (decoder_error_logfile) begin
            $fclose(decoder_error_logfile);
            // $display("[DECODER] Error log file closed");
        end
    end
endmodule


// Opcode Name	Binary (7-bit)	Decimal Equivalent
// OP_LUI	0110111	55
// OP_AUIPC	0010111	23
// OP_JAL	1101111	111
// OP_JALR	1100111	103
// OP_BRANCH	1100011	99
// OP_LOAD	0000011	3
// OP_STORE	0100011	35
// OP_OP_IMM	0010011	19
// OP_OP	0110011	51
// OP_MISC_MEM	0001111	15
// OP_SYSTEM	1110011	115
// OP_AMO	0101111	47
// OP_IMM_32	0011011	27
// OP_OP_32	0111011	59