`include "enums.sv"
// ALU Module with ALUop Enum
// module ALU(
//     input logic [63:0] src1,        // First operand
//     input logic [63:0] src2,        // Second operand
//     input ALUop alu_op,             // ALU operation code using enum
//     output logic [63:0] alu_result,     // ALU result
//     output logic zero_flag          // Zero flag (1 if result == 0, else 0)
// );

//   always_comb begin
//     case (ALUop)
//       ALU_ADD:  result = src1 + src2;                  // ADD
//       ALU_SUB:  result = src1 - src2;                  // SUB
//       ALU_AND:  result = src1 & src2;                  // AND
//       ALU_OR:   result = src1 | src2;                  // OR
//       ALU_XOR:  result = src1 ^ src2;                  // XOR
//       ALU_SLL:  result = src1 << src2[5:0];            // SHIFT LEFT (using lower 6 bits of src2 for shift count)
//       ALU_SRL:  result = src1 >> src2[5:0];            // SHIFT RIGHT (logical)
//       ALU_SRA:  result = src1 >>> src2[5:0];           // SHIFT RIGHT (arithmetic)
//       ALU_SLT:  result = (src1 < src2) ? 64'b1 : 64'b0; // Set Less Than (signed)
//       ALU_SLTU: result = (src1 < src2) ? 64'b1 : 64'b0; // Set Less Than (unsigned)
//       ALU_MUL:  result = src1 * src2;                  // MUL (multiplication)
//       ALU_MULH: result = (src1 * src2) >> 64;          // MULH (high 64-bits of the product)
//       ALU_DIV:  result = src1 / src2;                  // DIV (integer division)
//       ALU_REM:  result = src1 % src2;                  // REM (remainder)
//       default:   result = 64'b0;                        // Default case (NOP or zero)
//     endcase
//     zero_flag = (alu_result == 64'b0); // Set zero_flag if result is zero
//   end
// endmodule

// typedef struct {
//     ALUop alu_op;           // ALU operation field of type ALUop
//     logic alu_use_immed;    // Flag for using immediate
//     logic [31:0] rs1, rs2, immed; // Register operands and immediate value
// } alu_input;
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
