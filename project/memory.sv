`include "control_signals_struct.svh"
`include "dcache.sv"

module Memory #(
    parameter addr_width = 64
)(
    input  logic clk,
    input  logic reset,
    input  logic memory_enable,

    input  logic [63:0] pc_I_offset,
    input  logic [63:0] reg_b_contents,
    input  logic [63:0] alu_data,
    input  control_signals_struct control_signals,
    input  logic mem_wb_pipeline_valid,
    input  logic instruction_cache_reading,

    output logic [63:0] loaded_data_out,
    output logic memory_done,

    // AXI READ
    output logic [addr_width-1:0] mem_read_addr,
    output logic mem_read_valid,
    input  logic [63:0] mem_read_data,
    input  logic mem_read_ready,

    // AXI WRITE — unused for now
    input  logic m_axi_awready,
    input  logic m_axi_wready,
    input  logic m_axi_bvalid,
    input  logic [1:0] m_axi_bresp,
    output logic m_axi_awvalid,
    output logic [63:0] m_axi_awaddr,
    output logic [7:0]  m_axi_awlen,
    output logic [2:0]  m_axi_awsize,
    output logic [1:0]  m_axi_awburst,
    output logic [63:0] m_axi_wdata,
    output logic [7:0]  m_axi_wstrb,
    output logic m_axi_wvalid,
    output logic m_axi_wlast,
    output logic m_axi_bready,

    // Snoop
    input  logic m_axi_acvalid,
    output logic m_axi_acready,
    input  logic [addr_width-1:0] m_axi_acaddr,
    input  logic [3:0] m_axi_acsnoop,
    output logic snoop_stall,

    input  logic ecall_clean,
    output logic data_cache_reading
);

    // =================== Internal Control Signals ===================
    logic read_enable;
    logic [63:0] read_address;
    logic decache_result_ready;

    assign read_address = alu_data;

    // Memory request tracking
    logic pending_read;

    // =================== Register Request State ===================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pending_read <= 0;
        end else if (memory_enable && control_signals.read_memory_access && !decache_result_ready) begin
            pending_read <= 1;
        end else if (decache_result_ready) begin
            pending_read <= 0;
        end
    end

    assign read_enable = pending_read;

    // =================== Output Memory Done ===================
    assign memory_done = memory_enable && decache_result_ready && !mem_wb_pipeline_valid;

    // =================== Instantiate Cache ===================
    dcache data_cache (
        .clk(clk),
        .reset(reset),

        // CPU-side
        .read_enable(read_enable),
        .read_address(read_address),
        .read_data(loaded_data_out),
        .read_data_valid(decache_result_ready),

        // Memory-side
        .mem_read_addr(mem_read_addr),
        .mem_read_valid(mem_read_valid),
        .mem_read_data(mem_read_data),
        .mem_read_ready(mem_read_ready)
    );

    // =================== AXI Outputs (Dummy Default) ===================
    assign m_axi_awvalid = 0;
    assign m_axi_awaddr  = 64'b0;
    assign m_axi_awlen   = 8'b0;
    assign m_axi_awsize  = 3'b0;
    assign m_axi_awburst = 2'b0;
    assign m_axi_wdata   = 64'b0;
    assign m_axi_wstrb   = 8'b0;
    assign m_axi_wvalid  = 0;
    assign m_axi_wlast   = 0;
    assign m_axi_bready  = 0;

    assign m_axi_acready = 0;
    assign snoop_stall = 0;
    assign data_cache_reading = 0; // not supporting cache stall logic yet

    // =================== Debug Logs ===================
    always_ff @(posedge clk) begin
        if (reset) begin
            $display("[MEMORY RESET] Stage reset");
        end else if (memory_done) begin
            if (control_signals.read_memory_access) begin
                $display("[MemRead] PC: %h -> Read %h (%d) from %h into x%d",
                         control_signals.pc, loaded_data_out, loaded_data_out,
                         read_address, control_signals.dest_reg);
            end
            if (control_signals.write_memory_access) begin
                $display("[MemWrite] PC: %h -> Write %h (%d) to %h",
                         control_signals.pc, reg_b_contents, reg_b_contents, read_address);
            end
        end
    end

endmodule
