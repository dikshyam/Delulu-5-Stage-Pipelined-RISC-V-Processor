// register_file.sv
// Module that handles reading and writing to architectural registers, with RAW hazard tracking.

module register_file 
    #(
      parameter ADDR_WIDTH = 5,
      parameter DATA_WIDTH = 64
    )
    (
        input clk,
        input reset,
        input [DATA_WIDTH-1:0] stackptr,
    
        // Read interface
        input  [ADDR_WIDTH-1:0] rs1_addr,
        input  [ADDR_WIDTH-1:0] rs2_addr,
        output logic signed [DATA_WIDTH-1:0] rs1_data,
        output logic signed [DATA_WIDTH-1:0] rs2_data,
    
        // Write interface
        input  logic reg_write_en,
        input  [ADDR_WIDTH-1:0] rd_addr,
        input  signed [DATA_WIDTH-1:0] rd_data,
        output logic reg_write_complete,
    
        // RAW hazard tracking
        input  [ADDR_WIDTH-1:0] mark_busy_addr,
        input  [ADDR_WIDTH-1:0] clear_busy_addr,
        output logic raw_hazard,
    
        // Debug
        output logic [DATA_WIDTH-1:0] registers [31:0]
    );
    
        logic [31:0] reg_busy;
        logic raw1, raw2;
    
        // READ LOGIC
        always_comb begin
            rs1_data = registers[rs1_addr];
            rs2_data = registers[rs2_addr];
    
            raw1 = (rs1_addr != 0) && reg_busy[rs1_addr];
            raw2 = (rs2_addr != 0) && reg_busy[rs2_addr];
    
            raw_hazard = raw1 || raw2;
        end
    
        // WRITE + BUSY TRACKING LOGIC
        always_ff @(posedge clk) begin
            if (reset) begin
                for (int i = 0; i < 32; i++) begin
                    if (i == 2) begin
                        registers[i] <= stackptr;
                        $display("[RESET] Register x%0d initialized to stackptr: %h", i, stackptr);
                    end else begin
                        registers[i] <= 64'd0;
                        $display("[RESET] Register x%0d initialized to 0", i);
                    end
                    reg_busy[i] <= 1'b0;
                end
                reg_write_complete <= 0;
            end else begin
                // Register writeback
                if (reg_write_en && (rd_addr != 0)) begin
                    registers[rd_addr] <= rd_data;
                    reg_busy[rd_addr] <= 1'b0;
                    reg_write_complete <= 1;
                    $display("[REGISTER WRITE] x%0d <= %h", rd_addr, rd_data);
                end else begin
                    reg_write_complete <= 0;
                end
    
                // Set busy when decode stage schedules a write
                if (mark_busy_addr != 0) begin
                    reg_busy[mark_busy_addr] <= 1'b1;
                    $display("[RAW TRACK] Marked x%0d as busy", mark_busy_addr);
                end
    
                // Clear busy when WB stage completes write
                if (clear_busy_addr != 0) begin
                    reg_busy[clear_busy_addr] <= 1'b0;
                    $display("[RAW TRACK] Cleared busy bit for x%0d", clear_busy_addr);
                end
            end
        end
    
    endmodule
    