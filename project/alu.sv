`include "enums.sv"

module ALU (
    input  logic [63:0] operand1,       // First operand
    input  logic [63:0] operand2,       // Second operand
    input  ALUop        alu_op,         // ALU operation type
    input  logic alu_32,
    input  logic [31:0] instruction,    // Current instruction for debugging
    input  logic [63:0] pc,             // Program Counter for context
    output logic [63:0] result,         // Result of the ALU operation
    output logic        zero            // Zero flag
);

logic [63:0] temp_result;
 
  always_comb begin
    // Detailed debugging statement
    $display("[ALU DEBUG] PC=%h | Instr=%h | Operand1=%h | Operand2=%h | ALU_OP=%h", 
              pc, instruction, operand1, operand2, alu_op);
  
    case (alu_op)
      ALU_ADD:  temp_result = operand1 + operand2;                // Addition
      ALU_SUB:  temp_result = operand1 - operand2;                // Subtraction
      ALU_AND:  temp_result = operand1 & operand2;                // Bitwise AND
      ALU_OR:   temp_result = operand1 | operand2;                // Bitwise OR
      ALU_XOR:  temp_result = operand1 ^ operand2;                // Bitwise XOR
      ALU_SLL:  temp_result = operand1 << operand2[5:0];          // Shift Left Logical
      ALU_SRL:  temp_result = operand1 >> operand2[5:0];          // Shift Right Logical
      ALU_SRA:  temp_result = operand1 >>> operand2[5:0];         // Shift Right Arithmetic
      ALU_SLT:  temp_result = ($signed(operand1) < $signed(operand2)) ? 64'b1 : 64'b0; // Set Less Than (signed)
      ALU_SLTU: temp_result = ($unsigned(operand1) < $unsigned(operand2)) ? 64'b1 : 64'b0; // Set Less Than (unsigned)
      ALU_MUL:  temp_result = operand1 * operand2;                // Multiplication      
      ALU_MULH:  temp_result = ($signed(operand1) * $signed(operand2)) >> 64; // MULH
      ALU_MULHSU: temp_result = ($signed(operand1) * $unsigned(operand2)) >> 64; // MULHSU
      ALU_MULHU: temp_result = ($unsigned(operand1) * $unsigned(operand2)) >> 64; // MULHU
      ALU_DIV:   temp_result = (operand2 != 0) ? $signed(operand1) / $signed(operand2) : 64'b0; // DIV
      ALU_DIVU:  temp_result = (operand2 != 0) ? $unsigned(operand1) / $unsigned(operand2) : 64'b0; // DIVU
      ALU_REM:   temp_result = (operand2 != 0) ? $signed(operand1) % $signed(operand2) : 64'b0; // REM
      ALU_REMU:  temp_result = (operand2 != 0) ? $unsigned(operand1) % $unsigned(operand2) : 64'b0; // REMU

      // RV64M + RV64I Word Ops (32-bit)
      ALU_ADDW:   temp_result = $signed(operand1[31:0]) + $signed(operand2[31:0]);
      ALU_SUBW:   temp_result = $signed(operand1[31:0]) - $signed(operand2[31:0]);
      ALU_SLLW:   temp_result = $signed(operand1[31:0]) <<< operand2[4:0];
      ALU_SRLW:   temp_result = $unsigned(operand1[31:0]) >> operand2[4:0];
      ALU_SRAW:   temp_result = $signed(operand1[31:0]) >>> operand2[4:0];

      ALU_MULW:   temp_result = $signed(operand1[31:0]) * $signed(operand2[31:0]);
      ALU_DIVW:   temp_result = (operand2[31:0] != 0) ? $signed(operand1[31:0]) / $signed(operand2[31:0]) : 64'd0;
      ALU_DIVUW:  temp_result = (operand2[31:0] != 0) ? $unsigned(operand1[31:0]) / $unsigned(operand2[31:0]) : 64'd0;
      ALU_REMW:   temp_result = (operand2[31:0] != 0) ? $signed(operand1[31:0]) % $signed(operand2[31:0]) : 64'd0;
      ALU_REMUW:  temp_result = (operand2[31:0] != 0) ? $unsigned(operand1[31:0]) % $unsigned(operand2[31:0]) : 64'd0;


      default:  temp_result = 64'b0;                              // Default (NOP or zero)
    endcase

    if (alu_32) begin
        result = {{32{temp_result[31]}}, temp_result[31:0]};
    end else begin
        result = temp_result;
    end

    zero = (result == 64'b0);  // Zero flag is set if result is zero

    // Additional result debug message
    $display("[ALU RESULT] PC=%h | Result=%h | Zero=%b", pc, result, zero);
  end

endmodule
