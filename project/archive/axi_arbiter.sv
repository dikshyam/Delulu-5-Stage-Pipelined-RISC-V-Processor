module cache_arbiter #(
    parameter ADDR_WIDTH = 64
)(
    input  logic         clk,
    input  logic         reset,

    // Arbiter control signals
    input  logic         axi_icache_active,
    input  logic         axi_dcache_active,

    // Inputs from ICache
    input  logic [ADDR_WIDTH-1:0] icache_araddr,
    input  logic                  icache_arvalid,

    // Inputs from DCache
    input  logic [ADDR_WIDTH-1:0] dcache_araddr,
    input  logic                  dcache_arvalid,

    // Shared AXI outputs
    output logic [ADDR_WIDTH-1:0] axi_araddr,
    output logic                  axi_arvalid
);

    always_comb begin
        // Default: no access
        axi_araddr  = 64'b0;
        axi_arvalid = 1'b0;

        // Arbitration logic
        if (axi_dcache_active) begin
            axi_araddr  = dcache_araddr;
            axi_arvalid = dcache_arvalid;
        end else if (axi_icache_active) begin
            axi_araddr  = icache_araddr;
            axi_arvalid = icache_arvalid;
        end
    end

endmodule
