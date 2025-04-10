// `include "Sysbus.defs"
// `include "outputs.sv"

`include "enums.sv"
`include "control_signals_struct.svh"


// typedef struct packed {
//     logic [4:0] rs1;
//     logic [4:0] rs2;
//     // logic [63:0] rs1_data;
//     // logic [63:0] rs2_data;
//     logic [4:0] rd;
//     logic en_rs1;
//     logic en_rs2;
//     logic en_rd;
//     logic [63:0] immed;
//     logic keep_pc_plus_immed;
//     logic alu_use_immed;
//     logic alu_width_32;
//     logic [2:0] funct3;
//     logic [6:0] funct7;
//     logic is_store;
//     logic is_load;
//     logic is_csr;
//     logic csr_rw;
//     logic csr_rs;
//     logic csr_rc;
//     logic csr_immed;
//     logic is_ecall;
//     logic is_break;
//     logic is_trap_ret;
//     logic is_wfi;
//     logic is_sfence_vma;
//     logic is_atomic;
//     ALUop alu_op;
//     logic is_swap;
//     logic alu_nop;

//     // Add missing members for control signals
//     logic reg_write;       // Enable register write
//     logic mem_write;       // Enable memory write
//     logic mem_read;        // Enable memory read
//     logic mem_to_reg;      // Select memory or ALU result for writeback

//     // Jump-related members
//     Jump_Code jump_if;       // Determines the condition to jump
//     logic jump_absolute;     // Indicates absolute jump (e.g., JALR)

//     logic [2:0] data_size;
//     logic signed_type;
//     logic [4:0] shamt;
//     logic [7:0] instruction_type;

// } decoder_output;

function string alu_op_to_string(ALUop alu_op);
    case (alu_op)
        5'd0:   return "ALU_ADD";
        5'd1:   return "ALU_SUB";
        5'd2:   return "ALU_AND";
        5'd3:   return "ALU_OR";
        5'd4:   return "ALU_XOR";
        5'd5:   return "ALU_SLL";
        5'd6:   return "ALU_SRL";
        5'd7:   return "ALU_SRA";
        5'd8:   return "ALU_SLT";
        5'd9:   return "ALU_SLTU";
        5'd10:  return "ALU_MUL";
        5'd11:  return "ALU_MULH";
        5'd12:  return "ALU_MULHSU";
        5'd13:  return "ALU_MULHU";
        5'd14:  return "ALU_DIV";
        5'd15:  return "ALU_DIVU";
        5'd16:  return "ALU_REM";
        5'd17:  return "ALU_REMU";
        5'd18:  return "ALU_MULW";
        5'd19:  return "ALU_DIVW";
        5'd20:  return "ALU_DIVUW";
        5'd21:  return "ALU_REMW";
        5'd22:  return "ALU_REMUW";
        5'd31:  return "ALU_NOP";
        5'd23:  return "ALU_ADDW";
        5'd24:  return "ALU_SLLW";
        5'd25:  return "ALU_SRLW";
        5'd26:  return "ALU_SRAW";

        default: return "UNKNOWN_ALU_OP";
    endcase
endfunction


module Decoder (
    input  [31:0] inst,
    input         valid,
    input  [63:0] pc,
    input  [63:0] clk_counter,
    // input  [63:0] registers [0:31],
    // input  [63:0] rs1_data,
    // input  [63:0] rs2_data,
    output decoder_output out, 
    input  [1:0] curr_priv_mode,
    output logic gen_trap,
    output logic [63:0] gen_trap_cause,
    output logic [63:0] gen_trap_val
);

    // Immediate fields based on instruction type
    logic [63:0] immed_I, immed_S, immed_SB, immed_U, immed_UJ;

    // Sign-extended immediate values
    assign immed_I  = {{52{inst[31]}}, inst[31:20]};
    assign immed_S  = {{52{inst[31]}}, inst[31:25], inst[11:7]};
    assign immed_SB = {{51{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    assign immed_U  = {inst[31:12], 12'b0};
    assign immed_UJ = {{44{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};

    // Instruction fields
    logic [2:0] funct3 = inst[14:12];
    logic [6:0] funct7 = inst[31:25];
    logic [6:0] op_code = inst[6:0];


    logic [4:0] shamt = inst[24:20];
    logic [63:0] immed_I_shamt = {{59{1'b0}}, shamt};


    always_comb begin
        // check if decode is enabled

        
        // add reset block

        // Default control signal values
        out = '0;
        gen_trap = 0;
        gen_trap_cause = 0;
        gen_trap_val = 0;

        // Extract fields
        out.rs1 = inst[19:15];
        out.rs2 = inst[24:20];
        out.rd  = inst[11:7];
        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b000;

        out.funct3 = funct3;
        out.funct7 = funct7;
        out.immed  = 0;

        out.alu_op = ALU_NOP;    // Default ALU operation
        out.jump_if = JUMP_NO;
        out.jump_absolute = 0;

        $display("[DECODE] Decoding instruction: %h at PC: %h | clk_counter: %0d", inst, pc, clk_counter);

        // assign out.rs1_data = (out.rs1 != 5'b0) ? rs1_data : 64'h0;
        // assign out.rs2_data = (out.rs2 != 5'b0) ? rs2_data : 64'h0;
        
        // Instruction decoding logic
        case (op_code)

            // LUI and AUIPC
            OP_LUI: begin
                out.immed = immed_U;
                out.reg_write = 1;
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b001;
            end

            OP_AUIPC: begin
                out.immed = immed_U;
                out.reg_write = 1;
                out.alu_op = ALU_ADD;
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b001;
                // out.rs1_data = pc;
                // out.keep_pc_plus_immed = 1;
                // {out.en_rs1, out.en_rs2, out.en_rd} = 3'b001;
            end

            // Jump Instructions
            OP_JAL: begin
                out.immed = immed_UJ;
                out.reg_write = 1;
                out.jump_if = JUMP_YES;
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b001;
                out.alu_op = ALU_ADD;               
                // out.rs1_data = pc + 4;
                $display("[DECODE JAL] PC=%h | Inst=%h | rs1=%d | immed=%h | rd=%d", pc, inst, out.rs1, out.immed, out.rd);

            end

            OP_JALR: begin
                out.immed = immed_I;
                out.reg_write = 1;
                out.jump_if = JUMP_YES;
                out.jump_absolute = 1;
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b101;
                out.alu_op = ALU_ADD;               
                // out.rs1_data = pc + 4;
                $display("[DECODE JALR] PC=%h | Inst=%h | rs1=%d | immed=%h | rd=%d", pc, inst, out.rs1, out.immed, out.rd);

            end

            // Branch Instructions
            OP_BRANCH: begin
                out.immed = immed_SB;
                case (funct3)
                    F3B_BEQ:  out.jump_if = JUMP_ALU_EQZ;
                    F3B_BNE:  out.jump_if = JUMP_ALU_NEZ;
                    F3B_BLT:  out.jump_if = JUMP_ALU_NEZ;
                    F3B_BGE:  out.jump_if = JUMP_ALU_EQZ;
                    default:  gen_trap = 1;
                endcase
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b110;
            end

            // Load Instructions
            OP_LOAD: begin
                out.immed = immed_I;
                out.reg_write = 1;
                out.mem_read = 1;
                out.mem_to_reg = 1;
                out.is_load = 1;
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b101;
                // Add based on funct3
                case (funct3)
                    3'b000: begin out.data_size = 3'b001; out.signed_type = 1; end // LB
                    3'b001: begin out.data_size = 3'b010; out.signed_type = 1; end // LH
                    3'b010: begin out.data_size = 3'b100; out.signed_type = 1; end // LW
                    3'b011: begin out.data_size = 3'b111; out.signed_type = 1; end // LD
                    3'b100: begin out.data_size = 3'b001; out.signed_type = 0; end // LBU
                    3'b101: begin out.data_size = 3'b010; out.signed_type = 0; end // LHU
                    3'b110: begin out.data_size = 3'b100; out.signed_type = 0; end // LWU
                endcase
            end

            // Store Instructions
            OP_STORE: begin
                out.immed = immed_S;
                out.mem_write = 1;
                out.is_store = 1;
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b110;
                case (funct3)
                    3'b000: out.data_size = 3'b001; // SB
                    3'b001: out.data_size = 3'b010; // SH
                    3'b010: out.data_size = 3'b100; // SW
                    3'b011: out.data_size = 3'b111; // SD
                endcase
            end

            // Immediate Arithmetic
            OP_OP_IMM: begin
                // Determine immediate type (regular or shift amount)
                if (funct3 == FUNCT3_OP_IMM_SLL || funct3 == FUNCT3_OP_IMM_SRL_SRA) begin
                    out.immed = immed_I_shamt;  // Shift amount immediate
                    out.shamt = inst[24:20];
                end else begin
                    out.immed = immed_I;        // Standard immediate
                end

                // Enable Immediate, Writeback, and ALU usage
                out.alu_use_immed = 1;
                out.reg_write = 1;
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b101;

                // Decode ALU Operation Based on funct3
                case (funct3)
                    FUNCT3_OP_IMM_ADD:  out.alu_op = ALU_ADD;  // ADDI
                    FUNCT3_OP_IMM_SLL:  out.alu_op = ALU_SLL;  // SLLI
                    FUNCT3_OP_IMM_SLT:  out.alu_op = ALU_SLT;  // SLTI
                    FUNCT3_OP_IMM_SLTU: out.alu_op = ALU_SLTU; // SLTIU
                    FUNCT3_OP_IMM_XOR:  out.alu_op = ALU_XOR;  // XORI
                    FUNCT3_OP_IMM_SRL_SRA:  out.alu_op = (funct7 == 7'b0100000) ? ALU_SRA : ALU_SRL;  // SRLI/SRAI
                    FUNCT3_OP_IMM_OR:   out.alu_op = ALU_OR;   // ORI
                    FUNCT3_OP_IMM_AND:  out.alu_op = ALU_AND;  // ANDI
                    default:            gen_trap = 1;         // Trap for illegal instructions
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
                            default: gen_trap = 1;  // Illegal Instruction Trap
                        endcase
                    end
            
                    FUNCT7_OP_SUB: begin  // Subtraction or SRA (funct7 = 0100000)
                        case (funct3)
                            FUNCT3_OP_ADD_SUB:  out.alu_op = ALU_SUB;  // SUB
                            FUNCT3_OP_SRL_SRA:  out.alu_op = ALU_SRA;  // SRA
                            default: gen_trap = 1;
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
                            default: gen_trap = 1;
                        endcase
                    end
            
                    default: gen_trap = 1;  // Illegal funct7 - Trap
                endcase
            end
            

            OP_IMM_32: begin
                out.immed = immed_I;
                out.alu_use_immed = 1;
                out.reg_write = 1;
                out.alu_width_32 = 1;  // Mark this as a 32-bit operation
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b101;  // Use rs1 and rd, no rs2
            
                case (funct3)
                    FUNCT3_OP_IMM_32_ADD: begin
                        out.alu_op = ALU_ADDW;  // ADDIW (Immediate Add Word)
                    end
            
                    FUNCT3_OP_IMM_32_SLL: begin
                        out.immed = immed_I_shamt;  // Use shift amount for SLLIW
                        out.alu_op = ALU_SLLW;       // SLLIW (Shift Left Logical Immediate Word)
                    end
            
                    FUNCT3_OP_IMM_32_SRL_SRA: begin
                        out.immed = immed_I_shamt;  // Use shift amount for SRLIW/SRAIW
                        case (funct7)
                            FUNCT7_OP_IMM_32_STD:  out.alu_op = ALU_SRLW;  // SRLIW
                            FUNCT7_OP_IMM_32_SUB:  out.alu_op = ALU_SRAW;  // SRAIW
                            default: gen_trap = 1;  // Illegal instruction trap
                        endcase
                    end
            
                    default: gen_trap = 1;  // Illegal instruction trap
                endcase
            end
            
            
             // Register Arithmetic (32-bit, RV64I)
            OP_OP_32: begin
                out.reg_write = 1;
                out.alu_width_32 = 1;  // Indicate 32-bit ALU operation
                {out.en_rs1, out.en_rs2, out.en_rd} = 3'b111;

                case (funct7)
                    FUNCT7_OP_IMM_32_STD: begin
                        case (funct3)
                            FUNCT3_OP_IMM_32_ADD:  out.alu_op = ALU_ADDW;  // ADDW
                            FUNCT3_OP_IMM_32_SLL:  out.alu_op = ALU_SLLW;  // SLLW
                            FUNCT3_OP_IMM_32_SRL_SRA: out.alu_op = ALU_SRLW;  // SRLW
                            default: gen_trap = 1;
                        endcase
                    end

                    FUNCT7_OP_IMM_32_SUB: begin
                        case (funct3)
                            FUNCT3_OP_IMM_32_ADD:  out.alu_op = ALU_SUBW;  // SUBW
                            FUNCT3_OP_IMM_32_SRL_SRA: out.alu_op = ALU_SRAW;  // SRAW
                            default: gen_trap = 1;
                        endcase
                    end

                    FUNCT7_OP_IMM_32_MUL: begin  // RV64M Multiplication and Division for 32-bit
                        case (funct3)
                            3'b000: out.alu_op = ALU_MULW;   // MULW
                            3'b100: out.alu_op = ALU_DIVW;   // DIVW
                            3'b101: out.alu_op = ALU_DIVUW;  // DIVUW
                            3'b110: out.alu_op = ALU_REMW;   // REMW
                            3'b111: out.alu_op = ALU_REMUW;  // REMUW
                            default: gen_trap = 1;
                        endcase
                    end

                    default: gen_trap = 1;
                endcase
            end

            // Miscellaneous Memory Operations (Fence)
            OP_MISC_MEM: begin
                case (funct3)
                    3'b000: begin
                        out.is_sfence_vma = 1;  // FENCE instruction
                        out.reg_write = 0;
                        {out.en_rs1, out.en_rs2, out.en_rd} = 3'b000;
                    end
                    default: gen_trap = 1;
                endcase
            end


            // System Instructions (CSR, ECALL, EBREAK)
            OP_SYSTEM: begin
                out.reg_write = 1;
                case (funct3)

                    F3SYS_PRIV: begin  // ECALL and EBREAK
                        case (inst[31:20])
                            12'b000000000000: out.is_ecall = 1;
                            12'b000000000001: out.is_break = 1;
                            default: out.is_csr = 1;  // CSR Access
                        endcase
                    end

                    F3SYS_CSRRW: begin
                        out.csr_rw = 1;   // CSRRW (Write)
                        out.csr_rs = 0;
                        out.csr_rc = 0;
                        out.csr_immed = 0;
                    end
                    F3SYS_CSRRS: begin
                        out.csr_rw = 0;
                        out.csr_rs = 1;   // CSRRS (Set)
                        out.csr_rc = 0;
                        out.csr_immed = 0;
                    end
                    F3SYS_CSRRC: begin
                        out.csr_rw = 0;
                        out.csr_rs = 0;
                        out.csr_rc = 1;   // CSRRC (Clear)
                        out.csr_immed = 0;
                    end
                    F3SYS_CSRRWI: begin
                        out.csr_rw = 1;   // CSRRWI (Immediate Write)
                        out.csr_rs = 0;
                        out.csr_rc = 0;
                        out.csr_immed = 1;
                    end
                    F3SYS_CSRRSI: begin
                        out.csr_rw = 0;
                        out.csr_rs = 1;   // CSRRSI (Immediate Set)
                        out.csr_rc = 0;
                        out.csr_immed = 1;
                    end
                    F3SYS_CSRRCI: begin
                        out.csr_rw = 0;
                        out.csr_rs = 0;
                        out.csr_rc = 1;   // CSRRCI (Immediate Clear)
                        out.csr_immed = 1;
                    end
                    default: begin
                        out.csr_rw = 0;
                        out.csr_rs = 0;
                        out.csr_rc = 0;
                        out.csr_immed = 0;
                    end
                endcase
            end
        default: begin
            gen_trap = 1;
            gen_trap_cause = MCAUSE_ILLEGAL_INST;
        end
        endcase
        // Modified $display with ALU op as string
        // $display("[DEBUG DECODE] PC=%h | Inst=%h | rs1=%d | rs2=%d | rd=%d | ALU_OP=%s | RegWrite=%b | rs1_data=%h | rs2_data=%h | op_code=%h",
        //  pc, inst, out.rs1, out.rs2, out.rd, alu_op_to_string(out.alu_op), out.reg_write, out.rs1_data, out.rs2_data, op_code);
         $display("[DEBUG DECODE] PC=%h | Inst=%h | rs1=%d | rs2=%d | rd=%d | ALU_OP=%s | RegWrite=%b | op_code=%h",
         pc, inst, out.rs1, out.rs2, out.rd, alu_op_to_string(out.alu_op), out.reg_write, op_code);
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