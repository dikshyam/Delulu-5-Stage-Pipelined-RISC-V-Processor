module cache_arbiter (
    input logic clk,
    input logic reset,

    // I-Cache signals
    input  logic i_cache_req,
    input  logic [63:0] i_cache_addr,
    output logic i_cache_grant,

    // D-Cache signals
    input  logic d_cache_req,
    input  logic [63:0] d_cache_addr,
    output logic d_cache_grant,

    // AXI Memory Interface
    input  logic m_axi_ready,
    output logic [63:0] m_axi_addr,
    output logic m_axi_valid
);

    // State Variables
    logic last_grant;  // 0 = I-Cache, 1 = D-Cache
    logic grant_pending;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            i_cache_grant <= 0;
            d_cache_grant <= 0;
            m_axi_valid   <= 0;
            last_grant    <= 0;  // Start with I-Cache
            grant_pending <= 0;
        end else begin
            case ({i_cache_req, d_cache_req})
                2'b10: begin  // I-Cache request only
                    i_cache_grant <= 1;
                    d_cache_grant <= 0;
                    m_axi_addr    <= i_cache_addr;
                    m_axi_valid   <= 1;
                    last_grant    <= 0;
                end
                2'b01: begin  // D-Cache request only
                    i_cache_grant <= 0;
                    d_cache_grant <= 1;
                    m_axi_addr    <= d_cache_addr;
                    m_axi_valid   <= 1;
                    last_grant    <= 1;
                end
                2'b11: begin  // Both caches request access
                    if (last_grant == 0) begin
                        i_cache_grant <= 0;
                        d_cache_grant <= 1;
                        m_axi_addr    <= d_cache_addr;
                        m_axi_valid   <= 1;
                        last_grant    <= 1;
                    end else begin
                        i_cache_grant <= 1;
                        d_cache_grant <= 0;
                        m_axi_addr    <= i_cache_addr;
                        m_axi_valid   <= 1;
                        last_grant    <= 0;
                    end
                end
                default: begin
                    i_cache_grant <= 0;
                    d_cache_grant <= 0;
                    m_axi_valid   <= 0;
                end
            endcase
        end
    end
endmodule
