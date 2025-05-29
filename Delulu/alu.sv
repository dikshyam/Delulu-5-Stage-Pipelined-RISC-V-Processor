`include "enums.sv"

module ALU (
    input logic alu_enable,
    input  logic [63:0] operand1,       // First operand
    input  logic [63:0] operand2,       // Second operand
    input  ALUop        alu_op,         // ALU operation type
    input  logic alu_32,
    input signed [63:0] imm,
    input logic [5:0] shamt,
    input  logic [31:0] instruction,    // Current instruction for debugging
    // input 
    input  logic [63:0] pc,             // Program Counter for context
    output logic [63:0] result,         // Result of the ALU operation
    output logic        zero,            // Zero flag
    output logic alu_complete,
    input enable_logging
);


logic [63:0] temp_result;
logic [31:0] temp_result32;

// File handle for error logging
integer alu_error_logfile;
integer alu_log_file;

// In your initialization/reset logic:
initial begin
    // Open error log file for writing
    alu_error_logfile = $fopen("/home/dimohanty/CSE-502-ComputerArchitecture/Delulu/logs/alu_errors.log", "w");
    if (!alu_error_logfile) begin
        $display("[ALU] ERROR: Failed to open error log file");
    end else begin
        $fwrite(alu_error_logfile, "TIME,PC,INSTRUCTION,ALU_OP,OPERAND1,OPERAND2,ISSUE\n");
        // $display("[ALU] Error logging enabled to alu_errors.log");
    end

    // Open general operations log file
    alu_log_file = $fopen("/home/dimohanty/CSE-502-ComputerArchitecture/Delulu/logs/alu_operations.log", "w");
    if (!alu_log_file) begin
        $display("[ALU] ERROR: Failed to open operations log file");
    end else begin
        $fwrite(alu_log_file, "TIME,PC,INSTRUCTION,ALU_OP,OPERAND1,OPERAND2,RESULT,ZERO,ALU_32\n");
        // $display("[ALU] Operations logging enabled to alu_operations.log");
    end
end
logic disable_aluext;

always_comb begin
  
  if (alu_enable) begin
    
    // alu_complete = 0;
    zero = 0;
    temp_result = 64'b0;
    temp_result32 = 32'b0;
    result = 64'b0;

    // Detailed debugging statement
    // $display("[ALU DEBUG] PC=%h | Instr=%h | Operand1=%h | Operand2=%h | ALU_OP=%h | ALU_OP=%s", 
              // pc, instruction, operand1, operand2, alu_op, alu_op_to_string(alu_op));

    case (alu_op)

      // unsigned
      ALU_ADD:  temp_result = operand1 + operand2;                // Addition
      ALU_SUB:  temp_result = operand1 - operand2;                // Subtraction
      ALU_AND:  temp_result = operand1 & operand2;                // Bitwise AND
      ALU_OR:   temp_result = operand1 | operand2;                // Bitwise OR
      ALU_XOR:  temp_result = operand1 ^ operand2;                // Bitwise XOR
      // ALU_SLL:  temp_result = operand1 << operand2[5:0];          // Shift Left Logical
      // ALU_SRL:  temp_result = operand1 >> operand2[5:0];          // Shift Right Logical
      // ALU_SRA:  temp_result = $signed(operand1) >>> operand2[5:0];         // Shift Right Arithmetic
      // ALU_SLT:  temp_result = ($signed(operand1) < $signed(operand2)) ? 64'b1 : 64'b0; // Set Less Than (signed)
      // ALU_SLTU: temp_result = ($unsigned(operand1) < $unsigned(operand2)) ? 64'b1 : 64'b0; // Set Less Than (unsigned)
      // ALU_SRA:  temp_result = operand1 >>> operand2[5:0];         // Shift Right Arithmetic
      // ALU_SLT:  temp_result = (operand1 < operand2) ? 1 : 0; // Set Less Than (signed)
      // ALU_SLTU: temp_result = ($unsigned(operand1) < $unsigned(operand2)) ? 1 : 0; // Set Less Than (unsigned)
      ALU_MUL: temp_result = operand1 * operand2;
      ALU_MULH: temp_result = (operand1 * operand2) >> 32;
      
      ALU_SLL: begin
        // Perform 64-bit logical left shift
        // Only lower 6 bits of rs2 are used for shift amount in RV64I
        temp_result = operand1 << operand2[5:0];
      end
      
      ALU_SRL: begin
        // Perform 64-bit logical right shift
        // Only lower 6 bits of rs2 are used for shift amount in RV64I
        temp_result = operand1 >> operand2[5:0];
      end
      
      ALU_SRA: begin
        // Perform 64-bit arithmetic right shift
        // Convert to signed for proper sign extension
        logic signed [63:0] signed_operand = $signed(operand1);
        
        // Only lower 6 bits of rs2 are used for shift amount in RV64I
        temp_result = signed_operand >>> operand2[5:0];
      end
      
      ALU_SLT: begin
        // Convert operands to signed for proper comparison
        logic signed [63:0] signed_op1 = $signed(operand1);
        logic signed [63:0] signed_op2 = $signed(operand2);
        
        // Set result to 1 if rs1 < rs2 (signed), 0 otherwise
        if (signed_op1 < signed_op2)
          temp_result = 64'h1;
        else
          temp_result = 64'h0;
      end
      
      ALU_SLTU: begin
        // Perform unsigned comparison
        // Set result to 1 if rs1 < rs2 (unsigned), 0 otherwise
        if (operand1 < operand2)
          temp_result = 64'h1;
        else
          temp_result = 64'h0;
      end
      ALU_MULHSU: begin
          // Signed * Unsigned, high bits
          temp_result = ($signed(operand1) * $unsigned(operand2)) >> 32;
      end
      
      ALU_MULHU: begin
          // Unsigned * Unsigned, high bits
          // temp_result = ($unsigned(operand1) * $unsigned(operand2)) >> 32;
          temp_result = ($unsigned(operand1) * $unsigned(operand2)) >> 32;

      end

      ALU_DIV: begin
          // Signed division
          // Handle division by zero and overflow case
          // if (operand2 == 0)
          //   temp_result = 64'hFFFFFFFFFFFFFFFF;  // All 1's for division by zero
          // else if (operand1 == 64'h8000000000000000 && operand2 == 64'hFFFFFFFFFFFFFFFF)
          //   temp_result = 64'h8000000000000000;  // Overflow case: most negative / -1
          // else
            // temp_result = $signed(operand1) / $signed(operand2);
            temp_result = $signed(operand1) / $signed(operand2);

        end
      
      ALU_DIVU: begin
          // Unsigned division
          // Handle division by zero
          // if (operand2 == 0)
          //   temp_result = 64'hFFFFFFFFFFFFFFFF;  // All 1's for division by zero
          // else
            temp_result = $unsigned(operand1) / $unsigned(operand2);
      end
      
      ALU_REM: begin
          // Signed remainder
          // Handle division by zero and overflow case
          // if (operand2 == 0)
          //   temp_result = operand1;  // Remainder is dividend when div by zero
          // else if (operand1 == 64'h8000000000000000 && operand2 == 64'hFFFFFFFFFFFFFFFF)
          //   temp_result = 64'h0000000000000000;  // Overflow case: remainder is 0
          // else
            // temp_result = $signed(operand1) % $signed(operand2);
            temp_result = $signed(operand1) % $signed(operand2);

        end
      
      ALU_REMU: begin
          // Unsigned remainder
          // Handle division by zero
          // if (operand2 == 0)
          //   temp_result = $unsigned(operand1);  // Remainder is dividend when div by zero
          // else
            temp_result = $unsigned(operand1) % $unsigned(operand2);
      end

  // RV64I Word Register Arithmetic
  //     ALU_ADDW: begin
  //       // Add the lower 32 bits, then sign-extend result to 64-bit
  //       temp_result32 = $signed(operand1[31:0]) + $signed(operand2[31:0]);
  //       // temp_result = {{32{result32[31]}}, result32};
  //     end

  //     ALU_SUBW: begin
  //       // Subtract the lower 32 bits, then sign-extend result to 64-bit
  //       temp_result32 = $signed(operand1[31:0]) - $signed(operand2[31:0]);
  //       // temp_result = {{32{result32[31]}}, result32};
  //     end

  //     ALU_SLLW: begin
  //       // Shift left the lower 32 bits using lower 5 bits of operand2, then sign-extend
  //       temp_result32 = operand1[31:0] << operand2[4:0];
  //       // temp_result = {{32{result32[31]}}, result32};
  //     end

  //     ALU_SRLW: begin
  //       // Shift right logical the lower 32 bits using lower 5 bits of operand2, then sign-extend
  //       temp_result32 = $unsigned(operand1[31:0]) >> operand2[4:0];
  //       // temp_result = {{32{result32[31]}}, result32};
  //     end

  //     ALU_SRAW: begin
  //       // Shift right arithmetic the lower 32 bits using lower 5 bits of operand2, then sign-extend
  //       temp_result32 = $signed(operand1[31:0]) >>> operand2[4:0];
  //       // temp_result = {{32{result32[31]}}, result32};
  //     end



  // // RV64M Word Multiplication and Division
  //     ALU_MULW: begin
  //       // Multiply the lower 32 bits, then sign-extend result to 64-bit
  //       temp_result32 = $signed(operand1[31:0]) * $signed(operand2[31:0]);
  //       // temp_result = {{32{result32[31]}}, result32};
  //     end

  //     ALU_DIVW: begin
  //       // Signed division of lower 32 bits, then sign-extend result to 64-bit
  //       // Handle division by zero and overflow case (most negative / -1)
  //       // logic [31:0] dividend = operand1[31:0];
  //       // logic [31:0] divisor = operand2[31:0];
  //       // logic [31:0] result32;
        
  //       // if (divisor == 0)
  //       //     result32 = 32'hFFFFFFFF;  // All 1's for division by zero
  //       // else if (dividend == 32'h80000000 && divisor == 32'hFFFFFFFF)
  //       //     result32 = 32'h80000000;  // Overflow case: most negative / -1
  //       // else
  //       //     // result32 = $signed(dividend) / $signed(divisor);

  //       //     result32 = dividend/divisor;
  //       temp_result32 = $signed(operand1[31:0]) / $signed(operand2[31:0]);
  //       // temp_result = {{32{result32[31]}}, result32};
  //     end

  //     ALU_DIVUW: begin
  //       // Unsigned division of lower 32 bits, then sign-extend result to 64-bit
  //       // Handle division by zero
  //       // logic [31:0] dividend = operand1[31:0];
  //       // logic [31:0] divisor = operand2[31:0];
  //       // logic [31:0] result32;
        
  //       // if (divisor == 0)
  //       //     result32 = 32'hFFFFFFFF;  // All 1's for division by zero
  //       // else
  //       //     result32 = dividend / divisor;  // Unsigned division
  //       temp_result32 = $unsigned(operand1[31:0]) / $unsigned(operand2[31:0]);

  //       // temp_result = {{32{result32[31]}}, result32};
  //     end

  //     ALU_REMW: begin
  //       // Signed remainder of lower 32 bits, then sign-extend result to 64-bit
  //       // Handle division by zero and overflow case
  //       // logic [31:0] dividend = operand1[31:0];
  //       // logic [31:0] divisor = operand2[31:0];
  //       // logic [31:0] result32;
        
  //       // if (divisor == 0)
  //       //     result32 = dividend;  // Remainder is dividend when div by zero
  //       // else if (dividend == 32'h80000000 && divisor == 32'hFFFFFFFF)
  //       //     result32 = 32'h00000000;  // Overflow case: remainder is 0
  //       // else
  //       temp_result32 = $signed(operand1[31:0]) % $signed(operand2[31:0]);  // Sign handling done in execute stage
            
  //       // temp_result = {{32{result32[31]}}, result32};
  //     end

  //     ALU_REMUW: begin
  //       // Unsigned remainder of lower 32 bits, then sign-extend result to 64-bit
  //       // Handle division by zero
  //       // logic [31:0] dividend = operand1[31:0];
  //       // logic [31:0] divisor = operand2[31:0];
  //       // logic [31:0] result32;
        
  //       // if (divisor == 0)
  //       //     result32 = dividend;  // Remainder is dividend when div by zero
  //       // else
  //       //     result32 = dividend % divisor;  // Unsigned remainder
  //       temp_result32 = $unsigned(operand1[31:0]) % $unsigned(operand2[31:0]);

  //       // temp_result = {{32{result32[31]}}, result32};
  //     end
  // RV64I Word Operations (Register-Register)
    ALU_ADDW: begin
      // 1. Extract lower 32 bits of source registers
      logic [31:0] rs1_32bit = operand1[31:0];
      logic [31:0] rs2_32bit = operand2[31:0];
      
      // 2. Perform 32-bit addition
      logic [31:0] result32 = rs1_32bit + rs2_32bit;
      
      // 3. Sign-extend the 32-bit result to 64 bits
      temp_result = {{32{result32[31]}}, result32};
      disable_aluext = 1;
    end

    ALU_SUBW: begin
      // 1. Extract lower 32 bits of source registers
      logic [31:0] rs1_32bit = operand1[31:0];
      logic [31:0] rs2_32bit = operand2[31:0];
      
      // 2. Perform 32-bit subtraction
      logic [31:0] result32 = rs1_32bit - rs2_32bit;
      
      // 3. Sign-extend the 32-bit result to 64 bits
      temp_result = {{32{result32[31]}}, result32};
      disable_aluext = 1;
    end

    ALU_SLLW: begin
      // 1. Extract lower 32 bits of source registers
      logic [31:0] rs1_32bit = operand1[31:0];
      
      // 2. Perform shift using only lower 5 bits of rs2
      logic [31:0] result32 = rs1_32bit << operand2[4:0];
      
      // 3. Sign-extend the 32-bit result to 64 bits
      temp_result = {{32{result32[31]}}, result32};
      disable_aluext = 1;
    end

    ALU_SRLW: begin
      // 1. Extract lower 32 bits of source registers
      logic [31:0] rs1_32bit = operand1[31:0];
      
      // 2. Perform logical right shift using only lower 5 bits of rs2
      logic [31:0] result32 = rs1_32bit >> operand2[4:0];
      
      // 3. Sign-extend the 32-bit result to 64 bits
      temp_result = {{32{result32[31]}}, result32};
      disable_aluext = 1;
    end

    ALU_SRAW: begin
      // 1. Extract lower 32 bits of source registers and convert to signed
      logic signed [31:0] rs1_signed = $signed(operand1[31:0]);
      
      // 2. Perform arithmetic right shift using only lower 5 bits of rs2
      logic signed [31:0] result32 = rs1_signed >>> operand2[4:0];
      
      // 3. Sign-extend the 32-bit result to 64 bits
      temp_result = {{32{result32[31]}}, result32[31:0]};
      disable_aluext = 1;
    end

    // RV64M Word Multiplication and Division
    ALU_MULW: begin
      // 1. Extract lower 32 bits of source registers and convert to signed
      logic signed [31:0] rs1_signed = $signed(operand1[31:0]);
      logic signed [31:0] rs2_signed = $signed(operand2[31:0]);
      
      // 2. Perform signed 32-bit multiplication
      logic signed [31:0] result32 = rs1_signed * rs2_signed;
      
      // 3. Sign-extend the 32-bit result to 64 bits
      temp_result = {{32{result32[31]}}, result32[31:0]};
      disable_aluext = 1;
    end

    ALU_DIVW: begin
      // 1. Extract lower 32 bits of source registers and convert to signed
      logic signed [31:0] rs1_signed = $signed(operand1[31:0]);
      logic signed [31:0] rs2_signed = $signed(operand2[31:0]);
      
      // 2. Handle division by zero and overflow cases
      logic signed [31:0] result32;
      
      if (rs2_signed == 0) begin
        // Division by zero - return all 1's
        result32 = -1; // 0xFFFFFFFF
      end else if (rs1_signed == 32'h80000000 && rs2_signed == -1) begin
        // Overflow case: most negative number divided by -1
        result32 = rs1_signed; // Return the dividend (32'h80000000)
      end else begin
        // Normal case
        result32 = rs1_signed / rs2_signed;
      end
      
      // 3. Sign-extend the 32-bit result to 64 bits
      temp_result = {{32{result32[31]}}, result32};
      disable_aluext = 1;
    end

    ALU_DIVUW: begin
      // 1. Extract lower 32 bits of source registers as unsigned
      logic [31:0] rs1_unsigned = operand1[31:0];
      logic [31:0] rs2_unsigned = operand2[31:0];
      
      // 2. Handle division by zero
      logic [31:0] result32;
      
      if (rs2_unsigned == 0) begin
        // Division by zero - return all 1's
        result32 = 32'hFFFFFFFF;
      end else begin
        // Normal case - unsigned division
        result32 = rs1_unsigned / rs2_unsigned;
      end
      
      // 3. Sign-extend the 32-bit result to 64 bits
      temp_result = {{32{result32[31]}}, result32};
      disable_aluext = 1;
    end

    ALU_REMW: begin
      // 1. Extract lower 32 bits of source registers and convert to signed
      logic signed [31:0] rs1_signed = $signed(operand1[31:0]);
      logic signed [31:0] rs2_signed = $signed(operand2[31:0]);
      
      // 2. Handle division by zero and overflow cases
      logic signed [31:0] result32;
      
      if (rs2_signed == 0) begin
        // Division by zero - return the dividend
        result32 = rs1_signed;
      end else if (rs1_signed == 32'h80000000 && rs2_signed == -1) begin
        // Overflow case: most negative number divided by -1
        result32 = 0; // Remainder is 0
      end else begin
        // Normal case
        result32 = rs1_signed % rs2_signed;
      end
      
      // 3. Sign-extend the 32-bit result to 64 bits
      temp_result = {{32{result32[31]}}, result32};
      disable_aluext = 1;
    end

    ALU_REMUW: begin
      // 1. Extract lower 32 bits of source registers as unsigned
      logic [31:0] rs1_unsigned = operand1[31:0];
      logic [31:0] rs2_unsigned = operand2[31:0];
      
      // 2. Handle division by zero
      logic [31:0] result32;
      
      if (rs2_unsigned == 0) begin
        // Division by zero - return the dividend
        result32 = rs1_unsigned;
      end else begin
        // Normal case - unsigned remainder
        result32 = rs1_unsigned % rs2_unsigned;
      end
      
      // 3. Sign-extend the 32-bit result to 64 bits
      temp_result = {{32{result32[31]}}, result32};
      disable_aluext = 1;
    end

  // B-Type Branch

      ALU_BEQ:  temp_result = (operand1 == operand2) ? 64'b1 : 64'b0;  // 0 when equal
      ALU_BNE:  temp_result = (operand1 != operand2) ? 64'b1 : 64'b0;  // 1 when not equal 
      ALU_BLT:  temp_result = ($signed(operand1) < $signed(operand2)) ? 64'b1 : 64'b0;   // 1 when less than
      ALU_BGE:  temp_result = ($signed(operand1) >= $signed(operand2)) ? 64'b1 : 64'b0;  // 0 when greater/equal
      ALU_BLTU: temp_result = ($unsigned(operand1) < $unsigned(operand2)) ? 64'b1 : 64'b0;   // 1 when less than unsigned
      ALU_BGEU: temp_result = ($unsigned(operand1) >= $unsigned(operand2)) ? 64'b1 : 64'b0;  // 0 when greater/equal unsigned
      
      // LUI AUIPC
      ALU_LUI:    temp_result = operand2;  // Pass the immediate value directly
      // ALU_AUIPC:  temp_result = operand1 + $signed(operand2);  // Add PC to immediate
      ALU_AUIPC: begin
        // 1. Extract the immediate from U-type instruction
        // For AUIPC, we use the upper 20 bits from the instruction
        logic [63:0] imm = {52'b0, instruction[31:12]};
        
        // 2. Extract the lower 20 bits of the immediate
        logic [19:0] imm_20bit = imm[19:0];
        
        // 3. Sign-extend the 20-bit immediate to 64 bits
        logic signed [63:0] signed_imm;
        signed_imm = {{44{imm_20bit[19]}}, imm_20bit};  // imm_20bit[19] is the sign bit
        
        // 4. Shift left by 12 and add to PC
        temp_result = pc + ($signed(signed_imm) << 12);
      end
    
  // Load operations (all variants calculate the effective address)
  //     ALU_LB, ALU_LH, ALU_LW, ALU_LD, ALU_LBU, ALU_LHU, ALU_LWU: begin
  //       // For all load operations, calculate the effective address
  //       temp_result = operand1 + $signed(operand2);
  //     end


  // // Store operations (all variants calculate the effective address)
      
  //     ALU_SB, ALU_SH, ALU_SW, ALU_SD: begin
  //       // For all store operations, calculate the effective address
  //       // Explicitly cast both operands as signed to ensure proper sign extension
  //       temp_result = operand1 + $signed(operand2);
  //     end
  // Load operations - all calculate the effective address
  ALU_LB, ALU_LH, ALU_LW, ALU_LD, ALU_LBU, ALU_LHU, ALU_LWU: begin
    // 1. Extract the lower 12 bits of the immediate
    logic [11:0] imm_12bit = imm[11:0];
    
    // 2. Sign-extend the 12-bit immediate to 64 bits
    logic signed [63:0] signed_imm = {{52{imm_12bit[11]}}, imm_12bit};
    
    // 3. Calculate the effective address (base + offset)
    temp_result = operand1 + signed_imm;
  end

  // Store operations - all calculate the effective address
  ALU_SB, ALU_SH, ALU_SW, ALU_SD: begin
    // 1. Extract the lower 12 bits of the immediate
    logic [11:0] imm_12bit = imm[11:0];
    
    // 2. Sign-extend the 12-bit immediate to 64 bits
    logic signed [63:0] signed_imm = {{52{imm_12bit[11]}}, imm_12bit};
    
    // 3. Calculate the effective address (base + offset)
    temp_result = operand1 + signed_imm;
  end

  // // I-Type Immediate instructions
  //     ALU_ADDI:  temp_result = operand1 + $signed(operand2);
  //     ALU_XORI:  temp_result = operand1 ^ $signed(operand2);
  //     ALU_ORI:   temp_result = operand1 | $signed(operand2);
  //     ALU_ANDI:  temp_result = operand1 & $signed(operand2);
  //     ALU_SLLI:  temp_result = operand1 << operand2[5:0]; // Only use bottom 6 bits for RV64I
  //     ALU_SRLI:  temp_result = operand1 >> operand2[5:0];
  //     ALU_SRAI:  temp_result = $signed(operand1) >>> operand2[5:0];
  //     // ALU_SLTI:  temp_result = ($signed(operand1) < $signed(operand2)) ? 64'b1 : 64'b0;
  //     ALU_SLTIU: temp_result = ($unsigned(operand1) < $unsigned(operand2)) ? 64'b1 : 64'b0;
  //     ALU_SLTI:  temp_result = (operand1 < $signed(operand2)) ? 64'b1 : 64'b0;
    // I-Type Immediate Arithmetic
      ALU_ADDI: begin
        // 1. Extract the lower 12 bits of the immediate
        logic [11:0] imm_12bit = imm[11:0];
        
        // 2. Sign-extend the 12-bit immediate to 64 bits
        logic signed [63:0] signed_imm = {{52{imm_12bit[11]}}, imm_12bit};
        
        // 3. Perform addition
        temp_result = operand1 + signed_imm;
      end

      ALU_XORI: begin
        // 1. Extract the lower 12 bits of the immediate
        logic [11:0] imm_12bit = imm[11:0];
        
        // 2. Sign-extend the 12-bit immediate to 64 bits
        logic signed [63:0] signed_imm = {{52{imm_12bit[11]}}, imm_12bit};
        
        // 3. Perform bitwise XOR
        temp_result = operand1 ^ signed_imm;
      end

      ALU_ORI: begin
        // 1. Extract the lower 12 bits of the immediate
        logic [11:0] imm_12bit = imm[11:0];
        
        // 2. Sign-extend the 12-bit immediate to 64 bits
        logic signed [63:0] signed_imm = {{52{imm_12bit[11]}}, imm_12bit};
        
        // 3. Perform bitwise OR
        temp_result = operand1 | signed_imm;
      end

      ALU_ANDI: begin
        // 1. Extract the lower 12 bits of the immediate
        logic [11:0] imm_12bit = imm[11:0];
        
        // 2. Sign-extend the 12-bit immediate to 64 bits
        logic signed [63:0] signed_imm = {{52{imm_12bit[11]}}, imm_12bit};
        
        // 3. Perform bitwise AND
        temp_result = operand1 & signed_imm;
      end

      ALU_SLLI: begin
        // 1. Extract the shift amount (5 or 6 bits depending on XLEN)
        // For RV64I, shamt is 6 bits (allowing shifts of 0-63)
        logic [5:0] shift_amount = shamt[5:0];
        
        // 2. Perform logical left shift
        temp_result = operand1 << shift_amount;
      end

      ALU_SRLI: begin
        // 1. Extract the shift amount (5 or 6 bits depending on XLEN)
        // For RV64I, shamt is 6 bits (allowing shifts of 0-63)
        logic [5:0] shift_amount = shamt[5:0];
        
        // 2. Perform logical right shift
        temp_result = operand1 >> shift_amount;
      end

      ALU_SRAI: begin
        // 1. Extract the shift amount (5 or 6 bits depending on XLEN)
        // For RV64I, shamt is 6 bits (allowing shifts of 0-63)
        logic [5:0] shift_amount = shamt[5:0];
        
        // 2. Convert to signed for proper sign extension
        logic signed [63:0] signed_operand = $signed(operand1);
        
        // 3. Perform arithmetic right shift
        temp_result = signed_operand >>> shift_amount;
      end

      ALU_SLTI: begin
        // 1. Extract the lower 12 bits of the immediate
        logic [11:0] imm_12bit = imm[11:0];
        
        // 2. Sign-extend the 12-bit immediate to 64 bits
        logic signed [63:0] signed_imm = {{52{imm_12bit[11]}}, imm_12bit};
        
        // 3. Convert operand1 to signed for proper comparison
        logic signed [63:0] signed_operand = $signed(operand1);
        
        // 4. Perform signed comparison
        if (signed_operand < signed_imm)
          temp_result = 64'h1;
        else
          temp_result = 64'h0;
      end

      ALU_SLTIU: begin
        // 1. Extract the lower 12 bits of the immediate
        logic [11:0] imm_12bit = imm[11:0];
        
        // 2. Sign-extend the 12-bit immediate to 64 bits (then treated as unsigned)
        logic [63:0] extended_imm = {{52{imm_12bit[11]}}, imm_12bit};
        
        // 3. Perform unsigned comparison
        if (operand1 < extended_imm)
          temp_result = 64'h1;
        else
          temp_result = 64'h0;
      end

  // RV64I Word Immediate operations
      // ALU_ADDIW: begin
      //   // Add as 32-bit, then sign-extend result to 64-bit
      //   // temp_result32 = $signed(operand1[31:0]) + $signed(operand2);
      //   // For ADDIW instruction
      //   // 1. Extract 32-bit value from rs1
      //   logic [31:0] rs1_32bit = operand1[31:0];
        
      //   // 2. Extract and sign-extend 12-bit immediate
      //   logic [11:0] imm_12bit = imm[11:0];
      //   logic signed [31:0] signed_imm_32 = {{20{imm_12bit[11]}}, imm_12bit};
        
      //   // 3. Perform signed 32-bit addition
      //   logic signed [31:0] temp_result32 = $signed(rs1_32bit) + signed_imm_32;
        
      //   // 4. Sign-extend the 32-bit result to 64 bits
      //   temp_result = {{32{temp_result32[31]}}, temp_result32[31:0]};
      //   // temp_result = {{32{result32[31]}}, result32};
      // end

      // ALU_SLLIW: begin
      //   // Shift left as 32-bit, then sign-extend result to 64-bit
      //   temp_result32 = $signed(operand1[31:0]) << operand2[4:0]; // Only lower 5 bits used for 32-bit shifts
      //   // temp_result = {{32{result32[31]}}, result32};
      // end

      // ALU_SRLIW: begin
      //   // Shift right logical as 32-bit, then sign-extend result to 64-bit
      //   temp_result32 = $unsigned(operand1[31:0]) >> operand2[4:0];
      //   // temp_result = {{32{result32[31]}}, result32};
      // end

      // ALU_SRAIW: begin
      //   // Shift right arithmetic as 32-bit, then sign-extend result to 64-bit
      //   temp_result32 = $signed(operand1[31:0]) >>> operand2[4:0];
      //   // temp_result = {{32{result32[31]}}, result32};
      // end
      // RV64I Word Immediate operations
      ALU_ADDIW: begin
        // 1. Extract 32-bit value from rs1
        logic [31:0] rs1_32bit = operand1[31:0];
        
        // 2. Extract and sign-extend 12-bit immediate
        logic [11:0] imm_12bit = imm[11:0];
        logic signed [31:0] signed_imm_32 = {{20{imm_12bit[11]}}, imm_12bit};
        
        // 3. Perform signed 32-bit addition
        logic signed [31:0] temp_result32 = $signed(rs1_32bit) + signed_imm_32;
        
        // 4. Sign-extend the 32-bit result to 64 bits
        temp_result = {{32{temp_result32[31]}}, temp_result32[31:0]};
        disable_aluext = 1;
      end

      ALU_SLLIW: begin
        // 1. Extract lower 32 bits of source register
        logic [31:0] rs1_32bit = operand1[31:0];
        
        // 2. Perform shift using only lower 5 bits of immediate
        logic [31:0] shift_result = rs1_32bit << operand2[4:0];
        
        // 3. Sign-extend result to 64 bits
        temp_result = {{32{shift_result[31]}}, shift_result};
        disable_aluext = 1;
      end

      ALU_SRLIW: begin
        // 1. Extract lower 32 bits of source register
        logic [31:0] rs1_32bit = operand1[31:0];
        
        // 2. Perform unsigned right shift using only lower 5 bits of immediate
        logic [31:0] shift_result = rs1_32bit >> operand2[4:0];
        
        // 3. Sign-extend result to 64 bits
        temp_result = {{32{shift_result[31]}}, shift_result};
        disable_aluext = 1;
      end

      ALU_SRAIW: begin
        // 1. Extract lower 32 bits of source register and convert to signed
        logic signed [31:0] signed_rs1 = $signed(operand1[31:0]);
        
        // 2. Perform arithmetic right shift using only lower 5 bits of immediate
        logic signed [31:0] shift_result = signed_rs1 >>> operand2[4:0];
        
        // 3. Sign-extend result to 64 bits
        temp_result = {{32{shift_result[31]}}, shift_result[31:0]};
        disable_aluext = 1;
      end

      ALU_JAL, ALU_JALR: begin
        temp_result = operand1 + $signed(operand2);  // This gives PC+4
      end

      ALU_ECALL: begin
        // ECALL doesn't compute anything in the ALU
        // The actual ECALL handling happens in the commit stage with do_ecall()
        temp_result = 64'b0;  // Default result
      end
      
      ALU_EBREAK: begin
          // EBREAK doesn't compute anything in the ALU
          temp_result = 64'b0;  // Default result
      end

      default:  begin
        temp_result = 64'b0;                              // Default (NOP or zero)

        // Log the error if this is a valid ALU operation that should be implemented
        if (alu_enable && alu_error_logfile) begin
          $fwrite(alu_error_logfile, "%0d,", $time);
          $fwrite(alu_error_logfile, "%h,", pc);
          $fwrite(alu_error_logfile, "%h,", instruction);
          $fwrite(alu_error_logfile, "%h,", alu_op);
          $fwrite(alu_error_logfile, "%h,", operand1);
          $fwrite(alu_error_logfile, "%h,", operand2);
          $fwrite(alu_error_logfile, "UNSUPPORTED_ALU_OP\n");
          
          // Console output as well
          // $display("[ALU_ERROR] Time=%0t | PC=%h | Instr=%h | Op=%h | Unsupported ALU operation",
          //          $time, pc, instruction, alu_op);
      end
    end

    endcase
    // if (enable_logging) begin
    // Add additional error logging for potential operand issues
    // if (alu_enable && (operand1 === 'X || operand2 === 'X) && alu_error_logfile) begin
      //     $fwrite(alu_error_logfile, "%0d,", $time);
      //     $fwrite(alu_error_logfile, "%h,", pc);
      //     $fwrite(alu_error_logfile, "%h,", instruction);
      //     $fwrite(alu_error_logfile, "%h,", alu_op);
      //     $fwrite(alu_error_logfile, "%h,", operand1);
      //     $fwrite(alu_error_logfile, "%h,", operand2);
      //     $fwrite(alu_error_logfile, "X_VALUE_IN_OPERANDS\n");
          
      //     $display("[ALU_ERROR] Time=%0t | PC=%h | Instr=%h | X values in operands", 
      //             $time, pc, instruction);
      // end

    if (alu_32 && !disable_aluext) begin
        result = {{32{temp_result32[31]}}, temp_result32[31:0]};
    end else begin
        result = temp_result;
    end

    zero = (result == 64'b0);  // Zero flag is set if result is zero

    if (enable_logging) begin 
      // Log all operations to the operations log file
      if (alu_log_file) begin
        $fwrite(alu_log_file, "%0d,", $time);              // TIME
        $fwrite(alu_log_file, "%h,", pc);                  // PC
        $fwrite(alu_log_file, "%h,", instruction);         // INSTRUCTION
        $fwrite(alu_log_file, "%s,", alu_op.name());              // ALU_OP as raw value
        $fwrite(alu_log_file, "%h,", operand1);            // OPERAND1
        $fwrite(alu_log_file, "%h,", operand2);            // OPERAND2
        $fwrite(alu_log_file, "%h,", result);              // RESULT
        $fwrite(alu_log_file, "%b,", zero);               // ZERO flag
        $fwrite(alu_log_file, "%b\n", alu_32);               // ZERO flag
      end
    end     
    // Additional result debug message
    // $display("[ALU RESULT] PC=%h | Result=%h | Zero=%b", pc, result, zero);
    alu_complete = 1;
  end else begin
    alu_complete = 0;
  end
end
final begin
  if (alu_error_logfile) begin
      $fclose(alu_error_logfile);
      // $display("[ALU] Closed error log file");
  end
  
  if (alu_log_file) begin
      $fclose(alu_log_file);
      // $display("[ALU] Closed operations log file");
  end
end
endmodule
