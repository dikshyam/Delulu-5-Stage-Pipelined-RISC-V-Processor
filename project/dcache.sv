module dcache #(
  parameter ADDR_WIDTH = 64,
  parameter DATA_WIDTH = 64,
  parameter CACHE_LINES = 64
)(
  input  logic                 clk,
  input  logic                 reset,

  // Memory interface
  output logic [ADDR_WIDTH-1:0] mem_read_addr,
  output logic                  mem_read_valid,
  input  logic [DATA_WIDTH-1:0] mem_read_data,
  input  logic                  mem_read_ready,

  // CPU interface
  input  logic                  read_enable,
  input  logic [ADDR_WIDTH-1:0] read_address,
  output logic [DATA_WIDTH-1:0] read_data,
  output logic                  read_data_valid
);

  // ----------------------
  // Derived Parameters
  // ----------------------
  localparam LINE_ADDR_WIDTH = $clog2(CACHE_LINES);
  localparam TAG_WIDTH       = ADDR_WIDTH - LINE_ADDR_WIDTH - 3;

  // ----------------------
  // Internal Cache Memory
  // ----------------------
  logic [TAG_WIDTH-1:0]     tag_array   [CACHE_LINES-1:0];
  logic [DATA_WIDTH-1:0]    data_array  [CACHE_LINES-1:0];
  logic                     valid_array [CACHE_LINES-1:0];

  // ----------------------
  // Internal Signals
  // ----------------------
  logic [TAG_WIDTH-1:0] tag;
  logic [LINE_ADDR_WIDTH-1:0] index;
  logic [2:0] byte_offset;
  logic cache_hit;
  logic [DATA_WIDTH-1:0] data_out;

  assign byte_offset = read_address[2:0];
  assign index       = read_address[2 +: LINE_ADDR_WIDTH];
  assign tag         = read_address[ADDR_WIDTH-1 -: TAG_WIDTH];

  assign read_data = data_out;
  assign read_data_valid = cache_hit && read_enable;

  // ----------------------
  // FSM
  // ----------------------
  typedef enum logic [1:0] {
      IDLE,
      WAIT_MEM,
      FILL
  } state_t;

  state_t state, next_state;

  // ----------------------
  // Next State Logic + Output Control (sequential now)
  // ----------------------
  logic [ADDR_WIDTH-1:0] mem_read_addr_reg;
  logic                  mem_read_valid_reg;

  always_ff @(posedge clk or posedge reset) begin
      if (reset) begin
          state <= IDLE;
          mem_read_addr <= 0;
          mem_read_valid <= 0;
      end else begin
          state <= next_state;
          mem_read_addr <= mem_read_addr_reg;
          mem_read_valid <= mem_read_valid_reg;
      end
  end

  always_comb begin
      // defaults
      next_state = state;
      mem_read_addr_reg = 0;
      mem_read_valid_reg = 0;

      case (state)
          IDLE: begin
              if (read_enable && !cache_hit) begin
                  mem_read_valid_reg = 1;
                  mem_read_addr_reg = {read_address[ADDR_WIDTH-1:3], 3'b000};
                  next_state = WAIT_MEM;
              end
          end
          WAIT_MEM: begin
              if (mem_read_ready)
                  next_state = FILL;
          end
          FILL: begin
              next_state = IDLE;
          end
      endcase
  end

  // ----------------------
  // Tag Comparison & Cache Fill
  // ----------------------
  always_comb begin
      cache_hit = valid_array[index] && (tag_array[index] == tag);
      data_out = data_array[index];
  end

  always_ff @(posedge clk) begin
      if (state == FILL) begin
          tag_array[index]    <= tag;
          data_array[index]   <= mem_read_data;
          valid_array[index]  <= 1'b1;
      end
  end

endmodule
