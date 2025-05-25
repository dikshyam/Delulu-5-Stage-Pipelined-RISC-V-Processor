`include "dcache.sv"

module memory (
input  logic         clk,
input  logic         reset,
input  logic         memory_enable,
input  logic [63:0]  alu_data,
input  logic [63:0]  pc,

input  logic [63:0]  reg_b_contents,
input  decoder_output control_signals,
input  logic         mem_wb_status,
input  logic         arbiter_dcache_grant,
input  logic         ecall_clean,

// D-Cache control lines
output  logic         dcache_in_flight, 
output logic         m_axi_dcache_request,

output logic [63:0]  loaded_data_out,
output logic         memory_done,

// AXI Read
input  logic         m_axi_arready,
input  logic         m_axi_rvalid,
input  logic         m_axi_rlast,
input  logic [63:0]  m_axi_rdata,
output logic         m_axi_arvalid,
output logic [63:0]  m_axi_araddr,
output logic [7:0]   m_axi_arlen,
output logic [2:0]   m_axi_arsize,
output logic [1:0]   m_axi_arburst,
output logic         m_axi_rready,

// AXI Write
input  logic         m_axi_awready,
input  logic         m_axi_wready,
input  logic         m_axi_bvalid,
input  logic [1:0]   m_axi_bresp,
output logic         m_axi_awvalid,
output logic [63:0]  m_axi_awaddr,
output logic [7:0]   m_axi_awlen,
output logic [2:0]   m_axi_awsize,
output logic [1:0]   m_axi_awburst,
output logic [63:0]  m_axi_wdata,
output logic [7:0]   m_axi_wstrb,
output logic         m_axi_wvalid,
output logic         m_axi_wlast,
output logic         m_axi_bready,

// AC Snoop
input  logic         m_axi_acvalid,
output logic         m_axi_acready,
input  logic [63:0]  m_axi_acaddr,
input  logic [3:0]   m_axi_acsnoop,
output logic         snoop_stall,
input logic enable_logging
);

    // Handshake signals
    logic read_enable, write_enable;
    logic dcache_request_ready, dcache_result_received;
    // logic dcache_result_ready;
    logic ecall_clean_done, ecall_clean_begin;
    // ===================== DCache Instance =====================
    dcache dcache_inst (
        .clk(clk),
        .reset(reset),

        .read_enable(read_enable),
        .write_enable(write_enable),
        .address(dcache_request_address),

        .data_size(data_size),
        .data_input(dcache_write_data),
        .load_sign(data_sign),
        .ecall_clean(ecall_clean_begin),
        .instruction(dcache_request_instruction),
        .pc(dcache_request_pc),

        .computed_data_out_next(loaded_data_out),
        .ecall_clean_done(ecall_clean_done),
        .ecall_clean_signal_ack(ecall_clean_signal_ack),

        // AXI Read
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rready(m_axi_rready),

        // AXI Write
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wready(m_axi_wready),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bready(m_axi_bready),

        // Coherency
        .m_axi_acvalid(m_axi_acvalid),
        .m_axi_acaddr(m_axi_acaddr),
        .m_axi_acsnoop(m_axi_acsnoop),
        .m_axi_acready(m_axi_acready),
        .stall_core(snoop_stall),

        // Arbiter integration
        .new_data_request(dcache_request_ready),
        .arbiter_dcache_grant(arbiter_dcache_grant),
        .dcache_request(m_axi_dcache_request),
        .dcache_in_flight(dcache_in_flight),
        .dcache_result_ready(dcache_result_ready),
        .dcache_result_ack(dcache_result_received),
        .enable_logging(enable_logging)
    );

    // Latched memory request metadata
    logic [63:0] dcache_request_address, dcache_request_pc;
    logic [31:0] dcache_request_instruction;
    // logic        latched_read_enable;
    // logic        latched_write_enable;
    logic [2:0]  data_size;
    logic [63:0] dcache_write_data;
    logic        data_sign;
    logic [2:0] memory_condition;
    logic ecall_clean_signal_ack;
    logic request_sent; 

    always_ff @(posedge clk) begin 
        if (reset) begin
            dcache_result_received <= 0;
        end else begin
            if (dcache_request_ready) begin
                dcache_result_received <= 0;
            end else if (dcache_result_ready) begin
                dcache_result_received <= 1;
            end else begin
                dcache_result_received <= 0;
            end
        end
        
    end

    always_comb begin
        // Default: retain current values
        read_enable            = read_enable;
        write_enable           = write_enable;
        dcache_request_ready   = dcache_request_ready;
        memory_done            = memory_done;
        dcache_request_address = dcache_request_address;
        data_size              = data_size;
        dcache_write_data      = dcache_write_data;
        data_sign              = data_sign;
        // dcache_result_received = 0; // can still reset
        memory_condition       = 3'd0;
        dcache_request_pc      = dcache_request_pc;
        ecall_clean_signal_ack = 0;
        ecall_clean_begin = ecall_clean_begin;
        if (reset) begin
            read_enable            = 0;
            write_enable           = 0;
            dcache_request_ready   = 0;
            memory_done            = 0;
            dcache_request_address = 64'b0;
            data_size              = 0;
            dcache_write_data      = 0;
            data_sign              = 0;
            // dcache_result_received = 0;
            ecall_clean_signal_ack = 0;
            memory_condition       = 0;
            dcache_request_pc      = 64'b0;
        end else if (memory_enable) begin
            if (control_signals.is_ecall) begin
                if (!ecall_clean_done) begin
                    ecall_clean_begin = 1;
                    ecall_clean_signal_ack = 0;
                    dcache_request_instruction = control_signals.instruction;
                    dcache_request_pc = control_signals.pc;
                end else begin
                    ecall_clean_signal_ack = 1;
                    memory_condition = 3'd4; // ECALL CLEAN
                    ecall_clean_begin = 0;
                    if (mem_wb_status) begin
                        memory_done = 0;
                    end else begin
                        memory_done = 1;
                    end
                end
            end else if (!control_signals.mem_read && !control_signals.mem_write) begin
                if (control_signals.instruction == 32'b0) begin
                    memory_condition = 3'd7;  // NOP_INSTRUCTION
                end else begin
                    memory_condition = 3'd5;  // NON_MEMORY_INSTRUCTION
                end
                // Always let non-memory ops proceed if writeback isn't stalling
                if (!mem_wb_status) memory_done = 1;
            end else if (!memory_done && !mem_wb_status) begin
                if (!dcache_result_ready) begin
                    if (!dcache_request_ready) begin
                        // START REQUEST
                        memory_condition         = 3'd1;
                        read_enable              = control_signals.mem_read;
                        write_enable             = control_signals.mem_write;
                        data_size                = control_signals.data_size;
                        dcache_write_data        = reg_b_contents;
                        data_sign                = control_signals.data_sign;
                        dcache_request_address   = alu_data;
                        dcache_request_pc = control_signals.pc;
                        dcache_request_instruction = control_signals.instruction;
                        dcache_request_ready     = 1;
                        // dcache_result_received   = 0;
                    end else begin
                        
                        // WAITING FOR DCACHE
                        memory_condition = 3'd2;
                        memory_done = 0;
                    end
                
                end 
            end

            if (dcache_result_ready) begin
                memory_condition = 3'd3;  // DCACHE_RESULT_READY

                dcache_request_ready   = 0;
                // dcache_result_received = 1;
                
                read_enable            = 0;
                write_enable           = 0;
                // dcache_request_address = 64'b0;
                data_size              = 0;
                // dcache_write_data      = 0;
                data_sign              = 0;
                if (!mem_wb_status) memory_done = 1;

            end
                // else begin
                    // DCACHE COMPLETED
                    // memory_condition = 3'd3;
                    // request_sent = 0;
                    // dcache_request_ready   = 0;
                    // dcache_result_received = 1;
                    
                    
                    // dcache_result_received = 0;
                    // ecall_clean_signal_ack = 0;
                    // // memory_condition       = 0;
                    // dcache_request_pc      = 64'b0;
                    // dcache_request_ready   = 0;
                    // memory_done            = 0;
                    // dcache_request_address = 64'b0;
                    // data_size              = 0;
                    // dcache_write_data      = 64'b0;;
                    // data_sign              = 0;
                    // dcache_result_received = 0;
                    // memory_condition       = 0;
                    // dcache_request_pc      = 0;
            if (mem_wb_status) begin
                memory_condition = 3'd4;  // WRITEBACK_STALLING
                memory_done = 0;
                
            end
            


                
                // if (ecall_clean_done) begin
                    
                // end
        // end else begin
        //         memory_condition = 3'd5; // NO MEM OP
        //         memory_done = 1;
        //     end
        end else begin
            memory_condition = 3'd6; // MEMORY DISABLED
            memory_done = 0;
        end
    end



    // always_ff @(posedge clk) begin
    //     if (reset) begin
    //         $display("[MEM STAGE] Reset at clk=%0t", $time);
    //     end
    //     else if (memory_enable) begin
    //         if (control_signals.mem_read || control_signals.mem_write) begin
    //             $display("[MEM STAGE] clk=%0t", $time);
    //             $display("  ├─ PC                 : 0x%h", control_signals.pc);
    //             $display("  ├─ Instruction        : 0x%h", control_signals.instruction);
    //             $display("  ├─ ALU Addr (eff addr): 0x%h", alu_data);
    //             $display("  ├─ Mem Read           : %b", control_signals.mem_read);
    //             $display("  ├─ Mem Write          : %b", control_signals.mem_write);
    //             $display("  ├─ RS2 Data (Store)   : 0x%h", reg_b_contents); // or whatever your store data is
    //             $display("  ├─ DCache Req Ready   : %b", dcache_request_ready);
    //             $display("  ├─ DCache In Flight   : %b", dcache_in_flight);
    //             $display("  ├─ DCache Result Ready: %b", dcache_result_ready);
    //             $display("  └─ Memory Done        : %b", memory_done);
    //             $display("  └─ Data        : %b", loaded_data_out);
    //             $display("--------------------------------------------------------------");
    //         end
    //         else if (control_signals.is_ecall && ecall_clean) begin
    //             $display("[MEM STAGE] ECALL handled at clk=%0t", $time);
    //             $display("  ├─ ECALL clean: %b", ecall_clean);
    //             $display("  └─ Mem clean done: %b", ecall_clean_done);
    //             $display("  └─ Mem clean done ACK: %b", ecall_clean_signal_ack);
    //         end
    //     end
    // end



endmodule
