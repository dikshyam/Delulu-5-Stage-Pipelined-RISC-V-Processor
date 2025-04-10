`include "Sysbus.defs"
`include "enums.sv"
`include "decoder.sv"
`include "alu.sv"
// include enums, decoder, alu, regfile, pipe_reg, hazard, memory_system, mem_stage, privilege
module top
#(
  ID_WIDTH = 13,
  ADDR_WIDTH = 64,
  DATA_WIDTH = 64,
  STRB_WIDTH = DATA_WIDTH / 8,
  MAX_TIMEOUT = 10
)
(
  input  clk,
         reset,
         hz32768timer,

  // 64-bit addresses of the program entry point and initial stack pointer
  input  [63:0] entry,
  input  [63:0] stackptr,
  input  [63:0] satp,

  // interface to connect to the bus
  output  wire [ID_WIDTH-1:0]    m_axi_awid,
  // aw: write address
  output  wire [ADDR_WIDTH-1:0]  m_axi_awaddr,
  output  wire [7:0]             m_axi_awlen,
  output  wire [2:0]             m_axi_awsize,
  output  wire [1:0]             m_axi_awburst,
  output  wire                   m_axi_awlock,
  output  wire [3:0]             m_axi_awcache,
  output  wire [2:0]             m_axi_awprot,
  output  wire                   m_axi_awvalid,
  input   wire                   m_axi_awready,
  // w: write data
  output  wire [DATA_WIDTH-1:0]  m_axi_wdata,
  output  wire [STRB_WIDTH-1:0]  m_axi_wstrb,
  output  wire                   m_axi_wlast,
  output  wire                   m_axi_wvalid,
  input   wire                   m_axi_wready,
  // b: write response(signal)
  input   wire [ID_WIDTH-1:0]    m_axi_bid,
  input   wire [1:0]             m_axi_bresp,
  input   wire                   m_axi_bvalid,
  output  wire                   m_axi_bready,
  // ar: read address
  output  wire [ID_WIDTH-1:0]    m_axi_arid,
  output  wire [ADDR_WIDTH-1:0]  m_axi_araddr,
  output  wire [7:0]             m_axi_arlen,
  output  wire [2:0]             m_axi_arsize,
  output  wire [1:0]             m_axi_arburst,
  output  wire                   m_axi_arlock,
  output  wire [3:0]             m_axi_arcache,
  output  wire [2:0]             m_axi_arprot,
  output  wire                   m_axi_arvalid,
  input   wire                   m_axi_arready,
  // r: read data
  input   wire [ID_WIDTH-1:0]    m_axi_rid,
  input   wire [DATA_WIDTH-1:0]  m_axi_rdata,
  input   wire [1:0]             m_axi_rresp,
  input   wire                   m_axi_rlast,
  input   wire                   m_axi_rvalid,
  output  wire                   m_axi_rready,

  input   wire                   m_axi_acvalid,
  output  wire                   m_axi_acready,
  input   wire [ADDR_WIDTH-1:0]  m_axi_acaddr,
  input   wire [3:0]             m_axi_acsnoop
);

  // Internal signals
  logic [63:0] pc;
  logic receive_ready;
  logic receive_processing;
  logic [31:0] instruction_high;
  logic [31:0] instruction_low;

  logic [63:0] registers [0:31];
  logic [63:0] registers_temp [0:31];

  logic [63:0] result_low;
  logic [63:0] result_high;
  logic [4:0] rd; //Destination Register
  logic write_enable;
  logic zero_flag;

  integer count;
  logic [31:0] timeout_counter;
  logic [1:0] fsm_state;
  localparam [2:0] IDLE = 3'b000, FETCH = 3'b001, DECODE = 3'b010, EXECUTE = 3'b100, WAIT_FOR_DATA = 3'b011, HALT = 3'b100;  // Added WAIT_FOR_DATA
  logic terminate_simulation = 0;
  logic read_request_pending;

  // Signals for Decoder
  decoder_output decoded_inst_low, decoded_inst_high; //datatype def in decoder.sv
  logic gen_trap;
  logic [63:0] gen_trap_cause;
  logic [63:0] gen_trap_val;
  
  //alu_input  decoded_inst_low_alu, decoded_inst_high_alu;
  
  // Instantiate Decoders for low and high instructions
  Decoder decoder_low(
    .inst(instruction_low),
    .valid(receive_processing),
    .pc(pc),
    .out(decoded_inst_low),
    .curr_priv_mode(2'b00), // Default to user mode; can adjust as needed
    .gen_trap(gen_trap),
    .gen_trap_cause(gen_trap_cause),
    .gen_trap_val(gen_trap_val)
  );

  Decoder decoder_high(
    .inst(instruction_high),
    .valid(receive_processing),
    .pc(pc + 4),
    .out(decoded_inst_high),
    .curr_priv_mode(2'b00), // Default to user mode; can adjust as needed
    .gen_trap(gen_trap),
    .gen_trap_cause(gen_trap_cause),
    .gen_trap_val(gen_trap_val)
  );
  //Instantiate ALU for low instruction
  ALU alu_low(
    .operand1(registers[decoded_inst_low.rs1]),
    .operand2(decoded_inst_low.alu_use_immed ? decoded_inst_low.immed : registers[decoded_inst_low.rs2]),
    //.ALUop(decoded_inst_low.alu_op),
    .result(result_low),
    .zero(zero_flag_low) // Connect zero_flag to ALU zero output
  );

  // Instantiate ALU for high instruction
  ALU alu_high(
    .operand1(registers[decoded_inst_high.rs1]),
    .operand2(decoded_inst_high.alu_use_immed ? decoded_inst_high.immed : registers[decoded_inst_high.rs2]),
    //.ALUop(decoded_inst_high_alu.alu_op),
    .result(result_high),
    .zero(zero_flag_high) // Connect zero_flag to ALU zero output
  );
always_comb begin
    if (fsm_state == DECODE) begin
        if (instruction_high == 32'b0 && instruction_low == 32'b0) begin
            $display("Encountered all-zero instructions. Halting simulation at PC = %h, time %t", pc, $time);
            terminate_simulation = 1;
        end else begin
            $display("Non-decoded instruction:", instruction_low);
            // Decodels low instruction
            if (decoded_inst_low.en_rd && decoded_inst_low.rd != 0) begin
                registers[decoded_inst_low.rd] = decoded_inst_low.immed; //immediate value to register destination 
                $display("Decoded Low Instruction: Write immed = %h to Register[%0d] at time %t", decoded_inst_low.immed, decoded_inst_low.rd, $time);
            end
            $display(instruction_high);
            // Decode high instruction
            if (decoded_inst_high.en_rd && decoded_inst_high.rd != 0) begin
                registers[decoded_inst_high.rd] = decoded_inst_high.immed;
                $display("Decoded High Instruction: Write immed = %h to Register[%0d] at time %t", decoded_inst_high.immed, decoded_inst_high.rd, $time);
            end
        end
    end
end

always_ff @(posedge clk) begin
  if (reset) begin
    pc <= entry;
    fsm_state <= IDLE;
    m_axi_arvalid <= 0; 
    read_request_pending <= 0;
    timeout_counter <= 0;
    for (count = 0; count < 32; count = count + 1) begin
        registers[count] <= 64'b0;
      end
  end else if (!terminate_simulation) begin
    case (fsm_state)
      IDLE: begin
        fsm_state <= FETCH;
        end
      FETCH: begin
        if (read_request_pending) begin
          fsm_state <= WAIT_FOR_DATA; // Go back to WAIT_FOR_DATA to check for data availability
        end else if (m_axi_arvalid && m_axi_arready) begin 
          read_request_pending <= 1;
          m_axi_arvalid <= 0;
          $finish(0);

        end else if (!m_axi_arvalid && m_axi_arready && !read_request_pending) begin
          
          // $display("In Fetch BLOCK - issue new request");
          m_axi_araddr <= pc;
          m_axi_arvalid <= 1;
          m_axi_arid <= 0;
          m_axi_arlen <= 7; 
          m_axi_arsize <= 3'b010;
          m_axi_arburst <= 2'b10;
          read_request_pending <= 1;
          // if (m_axi_rvalid) begin
          fsm_state <= WAIT_FOR_DATA;
        end else begin
          $display("FETCH ERROR: m_axi_arready: %b, m_axi_arvalid: %b, fsm_state: %b", m_axi_arready, m_axi_arvalid, fsm_state);
        end
      end

      WAIT_FOR_DATA: begin
        if (m_axi_arvalid) begin
          m_axi_arvalid <= 0;  // De-assert arvalid after request is accepted
        end

        if (m_axi_rvalid) begin
          instruction_low <= m_axi_rdata[31:0];     // Lower 32 bits
          instruction_high <= m_axi_rdata[63:32];    // Upper 32 bits
          m_axi_rready <= 1;  // Signal that we're ready to accept the data
          read_request_pending <= 0;
          // decode_request_pending = 0;
          timeout_counter <= 0;
          
          if (m_axi_rdata == 64'b0 ) begin
            $display("Received all-zero data, terminating simulation. || INPUT");
            terminate_simulation = 1;
            read_request_pending <= 0;
            fsm_state <= EXECUTE;
            $finish;
          end else begin
              pc <= pc + 8; // Increment PC by 8 (fetching 64 bits)
              m_axi_arvalid <= 0;
              fsm_state <= DECODE;
        end
        
        end else begin
          timeout_counter <= timeout_counter + 1;
          if (timeout_counter > MAX_TIMEOUT) begin
            fsm_state <= IDLE; 
          end else begin
            fsm_state <= WAIT_FOR_DATA;
          end
        end
          
      end

      DECODE: begin
        m_axi_rready <= 0;  
        if (terminate_simulation) begin
          $display("Reached the end of Input");
          fsm_state <= HALT;
          $finish(0);
        end else begin
          fsm_state <= EXECUTE;
        end
      end

      
      EXECUTE: begin
         m_axi_rready <= 0; 
         $display("HELLOOooooo");
        // Write-back logic
        if (decoded_inst_low.en_rd && decoded_inst_low.rd != 0) begin
            registers[decoded_inst_low.rd] <= result_low;
            $display("Executed Low Instruction: Write result = %h to Register[%0d] at time %t", result_low, decoded_inst_low.rd, $time);
        end
        if (decoded_inst_high.en_rd && decoded_inst_high.rd != 0) begin
            registers[decoded_inst_high.rd] <= result_high;
            $display("Executed High Instruction: Write result = %h to Register[%0d] at time %t", result_high, decoded_inst_high.rd, $time);
        end
        fsm_state <= FETCH;
      end

      HALT: begin
        $display("terminate_simulation: %d, m_axi_rlast: %d",terminate_simulation, m_axi_rlast);
        $display("Simulation halted.");
        $finish; 
      end
    endcase
  end else if (terminate_simulation) begin
    $display("Simulation halted in Terminate!");
    // disable all; 
    fsm_state <= HALT;
    $finish;
  end
  else begin
    $display("Something is wrong with your FSM!");
  end
  end

endmodule