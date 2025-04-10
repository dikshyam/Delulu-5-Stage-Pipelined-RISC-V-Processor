module cache_arbiter (
    input  logic clk,
    input  logic reset,

    input  logic icache_req,
    input  logic dcache_req,

    output logic icache_grant,
    output logic dcache_grant
);
    
    logic last_grant; // 0 = I-Cache, 1 = D-Cache
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            icache_grant <= 0;
            dcache_grant <= 0;
            last_grant   <= 0;
            $display("[ARBITER] Reset: clearing grants");
        end else begin
            case ({icache_req, dcache_req})
                2'b10: begin
                    icache_grant <= 1;
                    dcache_grant <= 0;
                    last_grant   <= 0;
                    $display("[ARBITER] Grant -> ICache (Only ICache requested)");
                end
                2'b01: begin
                    icache_grant <= 0;
                    dcache_grant <= 1;
                    last_grant   <= 1;
                    $display("[ARBITER] Grant -> DCache (Only DCache requested)");
                end
                2'b11: begin
                    if (last_grant == 0) begin
                        icache_grant <= 0;
                        dcache_grant <= 1;
                        last_grant   <= 1;
                        $display("[ARBITER] Both requested - Grant -> DCache (ICache was last)");
                    end else begin
                        icache_grant <= 1;
                        dcache_grant <= 0;
                        last_grant   <= 0;
                        $display("[ARBITER] Both requested - Grant -> ICache (DCache was last)");
                    end
                end
                default: begin
                    icache_grant <= 0;
                    dcache_grant <= 0;
                    $display("[ARBITER] No requests - No grant");
                end
            endcase
        end
    end
endmodule
