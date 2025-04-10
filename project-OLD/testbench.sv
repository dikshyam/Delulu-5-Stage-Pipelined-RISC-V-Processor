`timescale 1ns/1ps

module top_tb;

    // Clock and reset signals
    logic clk;
    logic reset;

    // Instantiate the top module
    top uut (
        .clk(clk),
        .reset(reset),
        .entry(64'h0000000000000000),
        .stackptr(64'h0000000000001000),
        .satp(64'h0000000000000000)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100 MHz clock
    end

    // Reset generation
    initial begin
        reset = 1;
        #20 reset = 0;
    end

    // Test procedure
    initial begin
        // Wait for reset deassertion
        @(negedge reset);

        // Test instruction cache
        test_icache();

        // Test data cache
        test_dcache();

        // Finish simulation
        $finish;
    end

    // Task to test instruction cache
    task test_icache;
        begin
            // Simulate instruction fetches
            @(posedge clk);
            uut.f_pc = 64'h0000000000000000;
            @(posedge clk);
            uut.f_pc = 64'h0000000000000004;
            @(posedge clk);
            uut.f_pc = 64'h0000000000000008;
            @(posedge clk);
            uut.f_pc = 64'h000000000000000C;

            // Check cache hits and misses
            @(posedge clk);
            if (uut.icache_inst.cache_hit) begin
                $display("ICACHE HIT: Address %h", uut.f_pc);
            end else begin
                $display("ICACHE MISS: Address %h", uut.f_pc);
            end
        end
    endtask

    // Task to test data cache
    task test_dcache;
        begin
            // Simulate data reads and writes
            @(posedge clk);
            uut.mem_address = 64'h0000000000001000;
            uut.mem_data_in = 64'hDEADBEEFDEADBEEF;
            uut.mem_size = 3'b011; // Word size
            uut.mem_wb_wr_en = 1;
            @(posedge clk);
            uut.mem_wb_wr_en = 0;

            // Check cache hits and misses
            @(posedge clk);
            if (uut.dcache_inst.cache_hit) begin
                $display("DCACHE HIT: Address %h", uut.mem_address);
            end else begin
                $display("DCACHE MISS: Address %h", uut.mem_address);
            end

            // Simulate data read
            @(posedge clk);
            uut.mem_address = 64'h0000000000001000;
            uut.mem_wb_wr_en = 0;
            @(posedge clk);
            if (uut.dcache_inst.cache_hit) begin
                $display("DCACHE HIT: Address %h, Data %h", uut.mem_address, uut.mem_data_out);
            end else begin
                $display("DCACHE MISS: Address %h", uut.mem_address);
            end
        end
    endtask

endmodule