`include "control_signals_struct.svh"
// `include "oldalu-unsigned.sv"
`include "alu.sv"
`include "enums.sv"
/* verilator lint_off UNOPTFLAT */
module Execute (
    input  logic           clk,
    input  logic           reset,
    input  logic           execute_enable,
    input logic [31:0] instruction_current,
    input  logic [63:0]    pc_current,
    input  logic [63:0]    reg_a_contents,
    input  logic [63:0]    reg_b_contents,
    input  decoder_output  control_signals,

    output logic [63:0]    alu_data_out,
    output logic [63:0]    jump_pc,
    output decoder_output  control_signals_out,
    output logic           execute_done,
    input logic flush, 
    input enable_logging
);

    // logic signed [63:0] signed_imm;
    // logic [11:0] imm_12bit;
    logic alu_enable, alu_done;

    logic jump_taken, jump_taken_temp, alu_inputs_ready, computation_complete;
    logic [63:0] alu_result_temp;
    logic [63:0] jump_pc_temp;


    // decoder_output control_signals_latched;
    typedef enum logic [1:0] {
        EXEC_IDLE,
        EXEC_BUSY
    } exec_state_t;

    exec_state_t exec_state, next_state;

    logic [63:0] regA_final, regB_final;

    decoder_output control_signals_latched;
    // always_ff @(posedge clk or posedge reset) begin
    //     if (reset || flush) begin
    //         alu_data_out        <= 64'd0;
    //         jump_pc             <= 64'd0;
    //         control_signals_out <= '0;
    //         execute_done        <= 0;
    //         jump_taken          <= 0;
    //     end else if (execute_enable && alu_done && computation_complete) begin
    //         alu_data_out        <= alu_result_temp;
    //         jump_pc             <= jump_pc_temp;
    //         control_signals_out <= control_signals_latched;
    //         jump_taken          <= jump_taken_temp;
    //         execute_done        <= 1;
    //     end else begin
    //         execute_done <= 0;
    //     end
    // end

    // logic [7:0] instruction_type_local;
    ALUop alu_op_local;
    logic alu_32_local;


    // ALU instantiation
    ALU ALU_unit (
        .operand1(regA_final),
        .operand2(regB_final),
        .alu_op(alu_op_local),
        .alu_32(alu_32_local),
        .instruction(instruction_current),
        .pc(pc_current),
        .result(alu_result_temp),
        .zero(alu_zero),
        .alu_enable(alu_enable),
        .alu_complete(alu_done),
        .imm(control_signals.immed),
        .shamt(control_signals.shamt),
        .enable_logging(enable_logging)
    );

    always_comb begin

        if (reset) begin
            // Defaults
            alu_enable = 0;
            regA_final = 64'd0;
            regB_final = 64'd0;
            jump_pc_temp = 64'd0;
            jump_taken_temp = 0;
            control_signals_latched = '0;
            computation_complete = 0;
            alu_data_out        = 64'd0;
            jump_pc             = 64'd0;
            control_signals_out = '0;
            execute_done        = 0;
            jump_taken          = 0;
            alu_op_local = 0;
            alu_32_local = 0;
            // instruction_type_local = 0;

            // Everything stays at default
        end else if (execute_enable) begin
            if (execute_done) begin
                alu_enable = 0;
                // hold
            end else if (instruction_current == 32'b0) begin
                alu_data_out = 64'b0;
                jump_pc = 64'b0;
                control_signals_out = control_signals;
                
                control_signals_out.jump_signal = 0;
                execute_done = 1;
                // flush = 0;
                // Optionally: // $display for debug
            end else begin
                alu_enable = 0;
                // instruction = control_signals.instruction;
                alu_op_local = control_signals.alu_op;
                alu_32_local = control_signals.alu_width_32;

                // local variables
                regA_final = 64'd0;
                regB_final = 64'd0;
                jump_pc_temp = 64'd0;
                jump_taken_temp = 0;
                jump_pc = 64'd0;
                alu_data_out = 64'b0;
                jump_taken          = 0;
        
                // Latch control signals
                control_signals_latched = control_signals;
                
                // --- Operand Setup ---
                case (control_signals.op_code)
                    OP_AUIPC: begin
                        regA_final = pc_current;
                        regB_final = $signed(control_signals.immed);
                    end

                    OP_LUI: begin
                        regA_final = 64'd0;
                        regB_final = control_signals.immed;
                    end
                    OP_JAL: begin
                        regA_final = pc_current;
                        regB_final = 64'd4;
                    end

                    OP_JALR: begin
                        // For the ALU result (what gets written to rd)
                        regA_final = pc_current;  // Use current PC
                        regB_final = 64'd4;       // Add 4 to get PC+4
                        
                        // The jump target is calculated separately in the jump logic
                        // Jump logic will use reg_a_contents + immediate
                    end

                    OP_BRANCH: begin
                        // For BLT, BGE (signed comparisons)
                        if (control_signals.signed_type) begin
                            regA_final = $signed(reg_a_contents);
                            regB_final = $signed(reg_b_contents);
                        end
                        // For BLTU, BGEU (unsigned comparisons)
                        else begin
                            regA_final = reg_a_contents;
                            regB_final = reg_b_contents;
                        end
                        
                        // Target address calculation is separate
                        // Make sure to sign-extend the branch offset
                        // branch_target = pc_current + $signed(control_signals.immed);
                    end

                    OP_OP: begin
                        regA_final = reg_a_contents;
                        regB_final = reg_b_contents;
                    end
                    OP_OP_IMM: begin
                        regA_final = reg_a_contents;
                        regB_final = control_signals.signed_type
                                ? $signed(control_signals.immed)
                                : control_signals.immed;
                        // if (control_signals.alu_op inside {ALU_SLLI, ALU_SRLI, ALU_SRAI}) begin
                        //     // For shift immediates (SLLI, SRLI, SRAI)
                        //     regB_final = control_signals.immed;
                        // end else begin
                        //     // Normal I-type immediate ops
                            
                        // end
                    end
                    
                    OP_LOAD: begin
                        regA_final = reg_a_contents;
                        // I-type immediates should be sign-extended
                        regB_final = $signed(control_signals.immed);
                    end
                    
                    OP_STORE: begin
                        regA_final = reg_a_contents;
                        // S-type immediates should be sign-extended
                        regB_final = $signed(control_signals.immed);
                    end

                    OP_IMM_32: begin
                        regA_final = reg_a_contents;
                        regB_final = control_signals.signed_type
                            ? $signed(control_signals.immed)
                            : control_signals.immed;
                    end

                    OP_OP_32: begin
                        // Default - treat as regular unsigned values
                        // ALU_REMUW, ALU_DIVUW, SRLW, SLLW
                        regA_final = reg_a_contents;
                        regB_final = reg_b_contents;
                        
                        // For specifically signed operations
                        if (control_signals.alu_op inside {ALU_ADDW, ALU_SUBW, ALU_DIVW, ALU_REMW, ALU_MULW}) begin
                            // For arithmetic operations that need signed interpretation
                            regA_final = $signed(reg_a_contents);
                            
                            // For shifts, only the value being shifted needs to be signed
                            if (control_signals.alu_op != ALU_SRAW) begin
                                regB_final = $signed(reg_b_contents);
                            end
                        end
                    end

                    OP_MISC_MEM: begin //ununsed
                        regA_final = reg_a_contents;
                        regB_final = reg_b_contents;
                    end
                    OP_SYSTEM: begin
                        regA_final = reg_a_contents;
                        regB_final = control_signals.immed;
                    end
                    default: begin
                        regA_final = reg_a_contents;
                        regB_final = reg_b_contents;
                
                        if (control_signals.alu_use_immed) begin
                            regB_final = control_signals.signed_type
                                ? $signed(control_signals.immed)
                                : control_signals.immed;
                        end
                    end
                endcase
                
                // ---------------------------------
                // Debug output
                // ---------------------------------
                // $display("[EXECUTE DEBUG] REG FINAL DEBUG PC=0x%0h Instr=0x%0h | regA_final=0x%0h regB_final=0x%0h",
                        //  pc_current, instruction_current, regA_final, regB_final);
                

                // Start ALU
                alu_enable = 1;

                // ALU done check must happen elsewhere (ff)
                if (alu_done) begin
                    // --- Jump Evaluation ---
                    // case (control_signals.jump_if)
                    //     JUMP_ALU_EQZ: jump_taken_temp = (alu_result_temp == 64'b0);    // BEQ
                    //     JUMP_ALU_NEZ: jump_taken_temp = (alu_result_temp == 64'b1);    // BNE
                    //     JUMP_ALU_LT:  jump_taken_temp = (alu_result_temp == 64'b1);    // BLT (via SLT)
                    //     JUMP_ALU_GE:  jump_taken_temp = (alu_result_temp == 64'b0);    // BGE (NOT SLT)
                    //     JUMP_ALU_LTU: jump_taken_temp = (alu_result_temp == 64'b1);    // BLTU (via SLTU)
                    //     JUMP_ALU_GEU: jump_taken_temp = (alu_result_temp == 64'b0);    // BGEU (NOT SLTU)
                    //     JUMP_YES:     jump_taken_temp = 1'b1;
                    //     default:      jump_taken_temp = 1'b0;
                    // endcase
                    case (control_signals.jump_if)
                        JUMP_ALU_EQZ: jump_taken_temp = (alu_result_temp == 64'b1);    // BEQ
                        JUMP_ALU_NEZ: jump_taken_temp = (alu_result_temp == 64'b1);    // BNE
                        JUMP_ALU_LT:  jump_taken_temp = (alu_result_temp == 64'b1);    // BLT (via SLT)
                        JUMP_ALU_GE:  jump_taken_temp = (alu_result_temp == 64'b1);    // BGE (NOT SLT)
                        JUMP_ALU_LTU: jump_taken_temp = (alu_result_temp == 64'b1);    // BLTU (via SLTU)
                        JUMP_ALU_GEU: jump_taken_temp = (alu_result_temp == 64'b1);    // BGEU (NOT SLTU)
                        JUMP_YES:     jump_taken_temp = 1'b1;
                        default:      jump_taken_temp = 1'b0;
                    endcase
                    
                    

                    // --- Jump Address ---
                    // if (jump_taken_temp) begin
                    //     if (control_signals.jump_if == JUMP_YES && control_signals.jump_absolute) begin
                    //         // jump_pc_temp = regA_final + {{52{control_signals.immed[11]}}, control_signals.immed[11:0]};
                    //         jump_pc_temp = reg_a_contents + {{52{control_signals.immed[11]}}, control_signals.immed[11:0]};
                    //     end else begin
                    //         jump_pc_temp = pc_current + control_signals.immed;
                    //     end
                    // end

                    if (jump_taken_temp) begin
                        if (control_signals.jump_absolute) begin
                            // JALR: Register-based jump (add immediate to rs1)
                            jump_pc_temp = reg_a_contents + $signed(control_signals.immed);
                        end else begin
                            // Branch/JAL: PC-relative jump (add immediate to PC)
                            jump_pc_temp = pc_current + control_signals.immed;
                        end
                    end else begin
                        // No jump
                        jump_pc_temp = 64'b0;
                    end
                    

                    // Finalize
                    computation_complete = 1;
                    alu_data_out        = alu_result_temp;
                    jump_pc             = jump_pc_temp;
                    control_signals_out = control_signals;
                    control_signals_out.jump_signal = jump_taken_temp;
                    jump_taken          = jump_taken_temp;
                    execute_done        = 1;
                    
                    // EXECUTE DEBUG LOG
                    // $display("[EXECUTE DEBUG] PC=%h | Instr=%h", pc_current, instruction_current);
                    // $display("  ALU Result    : %h", alu_result_temp);
                    // $display("  Jump Taken    : %b", jump_taken_temp);
                    // $display("  Jump Target   : %h", jump_pc_temp);
                    // $display("  RegWrite      : %b", control_signals.reg_write);
                    // $display("  MemRead       : %b", control_signals.mem_read);
                    // $display("  MemWrite      : %b", control_signals.mem_write);
                    // $display("  MemToReg      : %b", control_signals.mem_to_reg);
                    // $display("  ALU_OP        : %s", alu_op_to_string(control_signals.alu_op));
                    // $display("  Operand1      : %h", regA_final);
                    // $display("  Operand2      : %h", regB_final);

                
            end
        end
        
        end 
        else begin
            execute_done = 0;
            jump_pc = 64'b0;
        end
    end


    // Define a transaction record structure for execute unit
    typedef struct packed {
        logic [63:0] pc;                 // Program counter for this instruction
        logic [31:0] instruction;        // The instruction being executed
        
        // Original register values
        logic [63:0] reg_a_contents;     // Original value from register file
        logic [63:0] reg_b_contents;     // Original value from register file
        
        // Final operands after modifications
        logic [63:0] regA_final;         // Final operand A after any modifications
        logic [63:0] regB_final;         // Final operand B after any modifications
        
        // Results and control
        logic [63:0] alu_result;         // Result from ALU
        logic [63:0] jump_target;        // Jump target if applicable
        logic        jump_taken;         // Whether jump was taken
        logic [7:0]  instruction_type;   // Type of instruction
        logic [3:0]  alu_op;             // ALU operation performed
        
        // Immediate value
        logic [63:0] immed_value;        // Immediate value used (if any)
    } execute_transaction_t;

    // Create a transaction log
    parameter EX_TX_LOG_SIZE = 16;
    execute_transaction_t ex_tx_log [EX_TX_LOG_SIZE-1:0];
    logic [$clog2(EX_TX_LOG_SIZE)-1:0] ex_tx_log_ptr;

    // File handle for transaction log
    integer ex_logfile;

    // In your initialization/reset logic:
    initial begin
        // Open log file for writing
        ex_logfile = $fopen("/home/dimohanty/CPU/logs/execute_transactions.log", "w");
        if (!ex_logfile) begin
            $display("[EXECUTE] ERROR: Failed to open transaction log file");
        end else begin
            $fwrite(ex_logfile, "TIME,PC,INSTRUCTION,REG_A_CONTENTS,REG_B_CONTENTS,REGA_FINAL,REGB_FINAL,ALU_RESULT,JUMP_TARGET,JUMP_TAKEN,ALU_OP,ALU_OP_NAME,OPCODE,OPCODE_NAME,IMMEDIATE\n");
            // $display("[EXECUTE] Transaction logging enabled to execute_transactions.log");
        end
        
        // Initialize log pointer
        ex_tx_log_ptr = 0;
    end

    // In your execute unit, add transaction logging when operations complete
    always_ff @(posedge clk) begin
        if (reset || flush) begin
            // Reset transaction pointer
            ex_tx_log_ptr <= 0;
        end else if (execute_done && ex_logfile && enable_logging) begin
            // Record transaction
            ex_tx_log[ex_tx_log_ptr].pc = pc_current;
            ex_tx_log[ex_tx_log_ptr].instruction = instruction_current;
            
            // Original register values
            ex_tx_log[ex_tx_log_ptr].reg_a_contents = reg_a_contents;
            ex_tx_log[ex_tx_log_ptr].reg_b_contents = reg_b_contents;
            
            // Final operand values
            ex_tx_log[ex_tx_log_ptr].regA_final = regA_final;
            ex_tx_log[ex_tx_log_ptr].regB_final = regB_final;
            
            // Results
            ex_tx_log[ex_tx_log_ptr].alu_result = alu_result_temp;
            ex_tx_log[ex_tx_log_ptr].jump_target = jump_pc_temp;
            ex_tx_log[ex_tx_log_ptr].jump_taken = jump_taken_temp;
            // ex_tx_log[ex_tx_log_ptr].instruction_type = control_signals.instruction_type;
            ex_tx_log[ex_tx_log_ptr].alu_op = control_signals.alu_op;
            
            // Immediate value
            ex_tx_log[ex_tx_log_ptr].immed_value = control_signals.immed;
            
            // Increment pointer (circular buffer)
            ex_tx_log_ptr <= (ex_tx_log_ptr == EX_TX_LOG_SIZE-1) ? 0 : ex_tx_log_ptr + 1;
            
            // Log to file
            $fwrite(ex_logfile, "%0d,", $time);
            $fwrite(ex_logfile, "%h,", pc_current);
            $fwrite(ex_logfile, "%h,", instruction_current);
            $fwrite(ex_logfile, "%h,", reg_a_contents);
            $fwrite(ex_logfile, "%h,", reg_b_contents);
            $fwrite(ex_logfile, "%h,", reg_b_contents);
            $fwrite(ex_logfile, "%h,", regA_final);
            $fwrite(ex_logfile, "%h,", regB_final);
            $fwrite(ex_logfile, "%h,", alu_result_temp);
            $fwrite(ex_logfile, "%h,", jump_pc_temp);
            $fwrite(ex_logfile, "%b,", jump_taken_temp);
            $fwrite(ex_logfile, "%d,", control_signals.alu_op);
            $fwrite(ex_logfile, "%s,", control_signals.alu_op.name());
            $fwrite(ex_logfile, "%d,", control_signals.op_code);
            $fwrite(ex_logfile, "%s,", control_signals.op_code.name());
            $fwrite(ex_logfile, "%h\n", control_signals.immed);
            
            // Optional console debug output
            // $display("[EXECUTE_TX] PC=%h | Instr=%h | RegA=%h→%h | RegB=%h→%h | Imm=%h | ALU=%h | Jump=%b→%h", 
            //         pc_current, instruction_current, 
            //         reg_a_contents, regA_final, 
            //         reg_b_contents, regB_final,
            //         control_signals.immed,
            //         alu_result_temp, 
            //         jump_taken_temp, jump_pc_temp);
        end
    end

    // Close file on simulation end
    final begin
        if (ex_logfile) begin
            $fclose(ex_logfile);
            // $display("[EXECUTE] Transaction log file closed");
        end
    end
    

endmodule
