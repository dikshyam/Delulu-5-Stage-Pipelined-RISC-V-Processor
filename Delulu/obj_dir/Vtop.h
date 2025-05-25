// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Primary design header
//
// This header should be included by all source files instantiating the design.
// The class here is then constructed to instantiate the design.
// See the Verilator manual for examples.

#ifndef _Vtop_H_
#define _Vtop_H_

#include "verilated_heavy.h"
#include "Vtop__Inlines.h"
#include "Vtop__Dpi.h"

class Vtop__Syms;
class Vtop___024unit;

//----------

VL_MODULE(Vtop) {
  public:
    // CELLS
    // Public to allow access to /*verilator_public*/ items;
    // otherwise the application code can consider these internals.
    Vtop___024unit*    	__PVT____024unit;
    
    // PORTS
    // The application code writes and reads these signals to
    // propagate new values into/out from the Verilated model.
    VL_IN8(clk,0,0);
    VL_IN8(reset,0,0);
    VL_IN8(hz32768timer,0,0);
    VL_OUT8(m_axi_awlen,7,0);
    VL_OUT8(m_axi_awsize,2,0);
    VL_OUT8(m_axi_awburst,1,0);
    VL_OUT8(m_axi_awlock,0,0);
    VL_OUT8(m_axi_awcache,3,0);
    VL_OUT8(m_axi_awprot,2,0);
    VL_OUT8(m_axi_awvalid,0,0);
    VL_IN8(m_axi_awready,0,0);
    VL_OUT8(m_axi_wstrb,7,0);
    VL_OUT8(m_axi_wlast,0,0);
    VL_OUT8(m_axi_wvalid,0,0);
    VL_IN8(m_axi_wready,0,0);
    VL_IN8(m_axi_bresp,1,0);
    VL_IN8(m_axi_bvalid,0,0);
    VL_OUT8(m_axi_bready,0,0);
    VL_OUT8(m_axi_arlen,7,0);
    VL_OUT8(m_axi_arsize,2,0);
    VL_OUT8(m_axi_arburst,1,0);
    VL_OUT8(m_axi_arlock,0,0);
    VL_OUT8(m_axi_arcache,3,0);
    VL_OUT8(m_axi_arprot,2,0);
    VL_OUT8(m_axi_arvalid,0,0);
    VL_IN8(m_axi_arready,0,0);
    VL_IN8(m_axi_rresp,1,0);
    VL_IN8(m_axi_rlast,0,0);
    VL_IN8(m_axi_rvalid,0,0);
    VL_OUT8(m_axi_rready,0,0);
    VL_IN8(m_axi_acvalid,0,0);
    VL_OUT8(m_axi_acready,0,0);
    VL_IN8(m_axi_acsnoop,3,0);
    //char	__VpadToAlign33[1];
    VL_OUT16(m_axi_awid,12,0);
    VL_IN16(m_axi_bid,12,0);
    VL_OUT16(m_axi_arid,12,0);
    VL_IN16(m_axi_rid,12,0);
    //char	__VpadToAlign42[6];
    VL_IN64(entry,63,0);
    VL_IN64(stackptr,63,0);
    VL_IN64(satp,63,0);
    VL_OUT64(m_axi_awaddr,63,0);
    VL_OUT64(m_axi_wdata,63,0);
    VL_OUT64(m_axi_araddr,63,0);
    VL_IN64(m_axi_rdata,63,0);
    VL_IN64(m_axi_acaddr,63,0);
    
    // LOCAL SIGNALS
    // Internals; generally not touched by application code
    VL_SIG8(top__DOT__icache_request,0,0);
    VL_SIG8(top__DOT__dcache_request,0,0);
    VL_SIG8(top__DOT__icache_in_flight,0,0);
    VL_SIG8(top__DOT__dcache_in_flight,0,0);
    VL_SIG8(top__DOT__grant_icache,0,0);
    VL_SIG8(top__DOT__grant_dcache,0,0);
    VL_SIG8(top__DOT__ecall_req_received,0,0);
    VL_SIG8(top__DOT__stall_top_snoop_in_progress,0,0);
    VL_SIG8(top__DOT__upstream_stall,0,0);
    VL_SIG8(top__DOT__if_id_status,0,0);
    VL_SIG8(top__DOT__fetch_stage_complete,0,0);
    VL_SIG8(top__DOT__fetch_stage_enable,0,0);
    VL_SIG8(top__DOT__jump_or_branch_mux,0,0);
    VL_SIG8(top__DOT__jump_flush_initiate_clk1,0,0);
    VL_SIG8(top__DOT__flush_pipeline_initiate,0,0);
    VL_SIG8(top__DOT__reg_write_complete,0,0);
    VL_SIG8(top__DOT__id_ex_rs1_addr,4,0);
    VL_SIG8(top__DOT__id_ex_rs2_addr,4,0);
    VL_SIG8(top__DOT__out_id_ex_rs1_addr,4,0);
    VL_SIG8(top__DOT__out_id_ex_rs2_addr,4,0);
    VL_SIG8(top__DOT__decode_stage_complete,0,0);
    VL_SIG8(top__DOT__decode_module_enable,0,0);
    VL_SIG8(top__DOT__decode_stage_enable,0,0);
    VL_SIG8(top__DOT__id_ex_raw_hazard,0,0);
    VL_SIG8(top__DOT__id_ex_status,0,0);
    VL_SIG8(top__DOT__ex_mem_status,0,0);
    VL_SIG8(top__DOT__execute_stage_complete,0,0);
    VL_SIG8(top__DOT__execute_stage_enable,0,0);
    VL_SIG8(top__DOT__execute_module_enable,0,0);
    VL_SIG8(top__DOT__memory_stage_enable,0,0);
    VL_SIG8(top__DOT__memory_stage_complete,0,0);
    VL_SIG8(top__DOT__memory_module_enable,0,0);
    VL_SIG8(top__DOT__wb_stage_enable,0,0);
    VL_SIG8(top__DOT__wb_stage_complete,0,0);
    VL_SIG8(top__DOT__wb_module_enable,0,0);
    VL_SIG8(top__DOT__wb_reg_update_addr,4,0);
    VL_SIG8(top__DOT__wb_reg_wr_en,0,0);
    VL_SIG8(top__DOT__ecall_completed,0,0);
    VL_SIG8(top__DOT__ecall_flush_state,1,0);
    VL_SIG8(top__DOT__ecall_flush_counter,1,0);
    VL_SIG8(top__DOT__mem_wb_status,0,0);
    VL_SIG8(top__DOT__arbiter__DOT__last_grant,0,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__icache_request_ready,0,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__icache_resp_ack,0,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__jump_pending,0,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__jump_processing,0,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__icache_result_ready,0,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__instruction_cache__DOT__icache_hit,0,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__instruction_cache__DOT__icache_done,0,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__instruction_cache__DOT__read_request_pending,0,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__instruction_cache__DOT__num_transfers,7,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__instruction_cache__DOT__f_index,4,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__instruction_cache__DOT__word_offset,3,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__instruction_cache__DOT__fsm_state,2,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__instruction_cache__DOT__fsm_next_state,2,0);
    VL_SIG8(top__DOT__decode_inst__DOT__exception_detected,0,0);
    VL_SIG8(top__DOT__decode_inst__DOT__funct3,2,0);
    VL_SIG8(top__DOT__decode_inst__DOT__funct7,6,0);
    VL_SIG8(top__DOT__decode_inst__DOT__op_code,6,0);
    VL_SIG8(top__DOT__decode_inst__DOT__shamt,4,0);
    VL_SIG8(top__DOT__execute_stage__DOT__alu_enable,0,0);
    VL_SIG8(top__DOT__execute_stage__DOT__alu_done,0,0);
    VL_SIG8(top__DOT__execute_stage__DOT__jump_taken_temp,0,0);
    VL_SIG8(top__DOT__execute_stage__DOT__alu_op_local,7,0);
    VL_SIG8(top__DOT__execute_stage__DOT__alu_32_local,0,0);
    VL_SIG8(top__DOT__execute_stage__DOT__ex_tx_log_ptr,3,0);
    VL_SIG8(top__DOT__execute_stage__DOT__alu_zero,0,0);
    VL_SIG8(top__DOT__execute_stage__DOT__ALU_unit__DOT__disable_aluext,0,0);
    VL_SIG8(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk20__DOT__shift_amount,5,0);
    VL_SIG8(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk21__DOT__shift_amount,5,0);
    VL_SIG8(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk22__DOT__shift_amount,5,0);
    VL_SIG8(top__DOT__memory_stage__DOT__read_enable,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__write_enable,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_request_ready,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_result_received,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__ecall_clean_done,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__ecall_clean_begin,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__data_size,2,0);
    VL_SIG8(top__DOT__memory_stage__DOT__data_sign,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__ecall_clean_signal_ack,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_result_ready,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__dcache_hit_or_done,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__snoop_done,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__burst_counter,2,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__replace_index,4,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__access_way_comb,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__hit_way_comb,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__dirty_bits_write_complete,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__flush_index,4,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__flush_way,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__req_index,4,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__dcache_aligned_index_reg,4,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__ac_index,4,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__rr_counter,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__cache_line_ready,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__read_request_pending,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__read_result_ready,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__write_result_ready,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__access_way,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__fsm_state,3,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__fsm_next_state,3,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__snoop_log_ptr,4,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__dirty_replace,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__data_stored,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__word_offset,2,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__byte_offset,2,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__axi_channels_free,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__ecall_clean_done_comb,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__write_through_value,0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__unnamedblk1__DOT__found_match,0,0);
    VL_SIG8(top__DOT__wb_stage__DOT__ecall_done,0,0);
    //char	__VpadToAlign227[1];
    VL_SIG16(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk14__DOT__imm_12bit,11,0);
    VL_SIG16(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk15__DOT__imm_12bit,11,0);
    VL_SIG16(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk16__DOT__imm_12bit,11,0);
    VL_SIG16(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk17__DOT__imm_12bit,11,0);
    VL_SIG16(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk18__DOT__imm_12bit,11,0);
    VL_SIG16(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk19__DOT__imm_12bit,11,0);
    VL_SIG16(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk23__DOT__imm_12bit,11,0);
    VL_SIG16(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk24__DOT__imm_12bit,11,0);
    VL_SIG16(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk25__DOT__imm_12bit,11,0);
    VL_SIG16(top__DOT__memory_stage__DOT__dcache_inst__DOT__halfword,15,0);
    VL_SIG16(top__DOT__wb_stage__DOT__reg_update_ptr,9,0);
    //char	__VpadToAlign250[2];
    VL_SIG(top__DOT__out_if_id_instruction,31,0);
    VL_SIG(top__DOT__if_id_instruction,31,0);
    VL_SIG(top__DOT__in_id_ex_instruction,31,0);
    VL_SIG(top__DOT__out_id_ex_instruction,31,0);
    VL_SIG(top__DOT__in_ex_mem_instruction,31,0);
    VL_SIG(top__DOT__out_ex_mem_instruction,31,0);
    VL_SIG(top__DOT__in_mem_wb_instruction,31,0);
    VL_SIG(top__DOT__total_ecall_counter,31,0);
    VL_SIG(top__DOT__fetch_stage__DOT__instruction_cache__DOT__way_to_update,31,0);
    VL_SIG(top__DOT__fetch_stage__DOT__instruction_cache__DOT__icache_inst_out,31,0);
    //char	__VpadToAlign292[4];
    VL_SIGW(top__DOT__fetch_stage__DOT__instruction_cache__DOT__packed_line,511,0,16);
    VL_SIG(top__DOT__fetch_stage__DOT__instruction_cache__DOT__unnamedblk1__DOT__i,31,0);
    VL_SIG(top__DOT__fetch_stage__DOT__instruction_cache__DOT__unnamedblk5__DOT__i,31,0);
    VL_SIG(top__DOT__rf_inst__DOT__reg_busy,31,0);
    VL_SIG(top__DOT__decode_inst__DOT__decoder_error_logfile,31,0);
    VL_SIG(top__DOT__decode_inst__DOT__decoder_trace_logfile,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ex_logfile,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__alu_error_logfile,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__alu_log_file,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk3__DOT__rs1_32bit,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk3__DOT__rs2_32bit,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk3__DOT__result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk4__DOT__rs1_32bit,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk4__DOT__rs2_32bit,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk4__DOT__result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk5__DOT__rs1_32bit,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk5__DOT__result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk6__DOT__rs1_32bit,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk6__DOT__result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk7__DOT__rs1_signed,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk7__DOT__result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk8__DOT__rs1_signed,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk8__DOT__rs2_signed,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk8__DOT__result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk9__DOT__rs1_signed,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk9__DOT__rs2_signed,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk9__DOT__result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk10__DOT__rs1_unsigned,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk10__DOT__rs2_unsigned,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk10__DOT__result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk11__DOT__rs1_signed,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk11__DOT__rs2_signed,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk11__DOT__result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk12__DOT__rs1_unsigned,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk12__DOT__rs2_unsigned,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk12__DOT__result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk13__DOT__imm_20bit,19,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk25__DOT__rs1_32bit,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk25__DOT__signed_imm_32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk25__DOT__temp_result32,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk26__DOT__rs1_32bit,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk26__DOT__shift_result,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk27__DOT__rs1_32bit,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk27__DOT__shift_result,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk28__DOT__signed_rs1,31,0);
    VL_SIG(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk28__DOT__shift_result,31,0);
    VL_SIG(top__DOT__memory_stage__DOT__dcache_request_instruction,31,0);
    VL_SIG(top__DOT__memory_stage__DOT__dcache_inst__DOT__tx_logfile,31,0);
    VL_SIG(top__DOT__memory_stage__DOT__dcache_inst__DOT__snoop_logfile,31,0);
    VL_SIG(top__DOT__memory_stage__DOT__dcache_inst__DOT__word32,31,0);
    VL_SIG(top__DOT__wb_stage__DOT__reg_logfile,31,0);
    VL_SIG64(top__DOT__out_if_id_pc,63,0);
    VL_SIG64(top__DOT__if_id_pc,63,0);
    VL_SIG64(top__DOT__fetch_pc_input,63,0);
    VL_SIG64(top__DOT__jump_or_branch_address,63,0);
    VL_SIG64(top__DOT__rs1_data,63,0);
    VL_SIG64(top__DOT__rs2_data,63,0);
    VL_SIG64(top__DOT__in_id_ex_pc,63,0);
    VL_SIGW(top__DOT__in_decoded_inst,229,0,8);
    VL_SIG64(top__DOT__out_id_ex_pc,63,0);
    VL_SIG64(top__DOT__out_id_ex_rs1_data,63,0);
    VL_SIG64(top__DOT__out_id_ex_rs2_data,63,0);
    VL_SIGW(top__DOT__out_id_ex_decoded_inst,229,0,8);
    VL_SIG64(top__DOT__alu_result,63,0);
    VL_SIG64(top__DOT__ex_mem_pc_plus_offset,63,0);
    VL_SIGW(top__DOT__ex_mem_control_signals,229,0,8);
    VL_SIG64(top__DOT__out_id_ex_rs1_data_temp,63,0);
    VL_SIG64(top__DOT__out_id_ex_rs2_data_temp,63,0);
    VL_SIG64(top__DOT__out_ex_mem_alu_result,63,0);
    VL_SIG64(top__DOT__in_ex_mem_pc,63,0);
    VL_SIG64(top__DOT__out_ex_mem_pc,63,0);
    VL_SIG64(top__DOT__in_ex_mem_rs1_data,63,0);
    VL_SIG64(top__DOT__in_ex_mem_rs2_data,63,0);
    VL_SIG64(top__DOT__out_ex_mem_rs2_data,63,0);
    VL_SIGW(top__DOT__in_ex_mem_control_signals,229,0,8);
    VL_SIGW(top__DOT__out_ex_mem_control_signals,229,0,8);
    VL_SIG64(top__DOT__mem_wb_loaded_data,63,0);
    VL_SIG64(top__DOT__in_mem_wb_alu_result,63,0);
    VL_SIG64(top__DOT__out_mem_wb_alu_data,63,0);
    VL_SIG64(top__DOT__in_mem_wb_rs2_data,63,0);
    VL_SIG64(top__DOT__out_mem_wb_loaded_data,63,0);
    VL_SIGW(top__DOT__in_mem_wb_control_signals,229,0,8);
    VL_SIGW(top__DOT__out_mem_wb_control_signals,229,0,8);
    VL_SIG64(top__DOT__wb_mem_loaded_data,63,0);
    VL_SIG64(top__DOT__wb_alu_data,63,0);
    VL_SIG64(top__DOT__wb_reg_update_data,63,0);
    VL_SIGW(top__DOT__wb_control_signals,229,0,8);
    VL_SIG64(top__DOT__fetch_stage__DOT__cache_request_address,63,0);
    VL_SIG64(top__DOT__fetch_stage__DOT__jump_target,63,0);
    VL_SIG64(top__DOT__fetch_stage__DOT__instruction_cache__DOT__fetch_pc,63,0);
    VL_SIG64(top__DOT__fetch_stage__DOT__instruction_cache__DOT__f_tag,54,0);
    VL_SIG64(top__DOT__fetch_stage__DOT__instruction_cache__DOT__aligned_pc,63,0);
    VL_SIG64(top__DOT__fetch_stage__DOT__instruction_cache__DOT__icache_pc_out,63,0);
    VL_SIG64(top__DOT__decode_inst__DOT__immed_I,63,0);
    VL_SIG64(top__DOT__decode_inst__DOT__immed_S,63,0);
    VL_SIG64(top__DOT__decode_inst__DOT__immed_SB,63,0);
    VL_SIG64(top__DOT__decode_inst__DOT__immed_U,63,0);
    VL_SIG64(top__DOT__decode_inst__DOT__immed_UJ,63,0);
    VL_SIG64(top__DOT__decode_inst__DOT__immed_I_shamt,63,0);
    VL_SIG64(top__DOT__decode_inst__DOT__exception_cause,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__alu_result_temp,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__jump_pc_temp,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__regA_final,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__regB_final,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__temp_result,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk1__DOT__signed_operand,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk2__DOT__signed_op1,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk2__DOT__signed_op2,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk13__DOT__imm,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk13__DOT__signed_imm,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk14__DOT__signed_imm,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk15__DOT__signed_imm,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk16__DOT__signed_imm,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk17__DOT__signed_imm,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk18__DOT__signed_imm,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk19__DOT__signed_imm,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk22__DOT__signed_operand,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk23__DOT__signed_imm,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk23__DOT__signed_operand,63,0);
    VL_SIG64(top__DOT__execute_stage__DOT__ALU_unit__DOT__unnamedblk24__DOT__extended_imm,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_request_address,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_request_pc,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_write_data,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__computed_data_out,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__flush_addr,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__snoop_address,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__dirty_address,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__write_mask,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__shifted_data,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__write_address_track,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__dcache_aligned_address,63,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__req_tag,52,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__dcache_aligned_tag,52,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__ac_tag,52,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__word,63,0);
    VL_SIG64(top__DOT__wb_stage__DOT__ecall_data_out,63,0);
    string top__DOT__decode_inst__DOT__exception_details;
    VL_SIG64(top__DOT__rf_regs[32],63,0);
    VL_SIGW(top__DOT__fetch_stage__DOT__instruction_cache__DOT__cache_data[32][2],511,0,16);
    VL_SIG64(top__DOT__fetch_stage__DOT__instruction_cache__DOT__cache_tags[32][2],54,0);
    VL_SIG8(top__DOT__fetch_stage__DOT__instruction_cache__DOT__cache_valid[32][2],0,0);
    VL_SIG64(top__DOT__fetch_stage__DOT__instruction_cache__DOT__icache_line_buffer[8],63,0);
    VL_SIGW(top__DOT__execute_stage__DOT__ex_tx_log[16],556,0,18);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__tags[32][2],52,0);
    VL_SIGW(top__DOT__memory_stage__DOT__dcache_inst__DOT__data_lines[32][2],511,0,16);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__valid_bits[32][2],0,0);
    VL_SIG8(top__DOT__memory_stage__DOT__dcache_inst__DOT__dirty_bits[32][2],0,0);
    VL_SIG64(top__DOT__memory_stage__DOT__dcache_inst__DOT__burst_buffer[8],63,0);
    VL_SIGW(top__DOT__memory_stage__DOT__dcache_inst__DOT__snoop_log[32],193,0,7);
    VL_SIGW(top__DOT__wb_stage__DOT__reg_update_log[1024],295,0,10);
    VL_SIGW(top__DOT__wb_stage__DOT__reg_history[32],295,0,10);
    
    // LOCAL VARIABLES
    // Internals; generally not touched by application code
    static VL_ST_SIG8(__Vtable1_top__DOT__ecall_flush_state[128],1,0);
    static VL_ST_SIG8(__Vtable1_top__DOT__ecall_flush_counter[128],1,0);
    static VL_ST_SIG8(__Vtable1_top__DOT__fetch_stage_enable[128],0,0);
    static VL_ST_SIG8(__Vtable1_top__DOT__decode_stage_enable[128],0,0);
    static VL_ST_SIG8(__Vtable1_top__DOT__execute_stage_enable[128],0,0);
    static VL_ST_SIG8(__Vtable1_top__DOT__ecall_req_received[128],0,0);
    static VL_ST_SIG8(__Vtable1_top__DOT__ecall_completed[128],0,0);
    static VL_ST_SIG8(__Vtable2_top__DOT__grant_icache[16],0,0);
    static VL_ST_SIG8(__Vtable2_top__DOT__grant_dcache[16],0,0);
    static VL_ST_SIG8(__Vtable2_top__DOT__arbiter__DOT__last_grant[16],0,0);
    VL_SIG8(__Vdly__top__DOT__fetch_stage__DOT__instruction_cache__DOT__fsm_state,2,0);
    VL_SIG8(__Vdly__top__DOT__fetch_stage__DOT__instruction_cache__DOT__read_request_pending,0,0);
    VL_SIG8(__Vdly__m_axi_arvalid,0,0);
    VL_SIG8(__Vdly__top__DOT__fetch_stage__DOT__instruction_cache__DOT__num_transfers,7,0);
    VL_SIG8(__Vdly__top__DOT__fetch_stage__DOT__instruction_cache__DOT__icache_done,0,0);
    VL_SIG8(__Vdly__m_axi_rready,0,0);
    VL_SIG8(__Vdlyvset__top__DOT__fetch_stage__DOT__instruction_cache__DOT__icache_line_buffer__v0,0,0);
    VL_SIG8(__Vdly__top__DOT__memory_stage__DOT__dcache_inst__DOT__burst_counter,2,0);
    VL_SIG8(__Vdly__top__DOT__memory_stage__DOT__dcache_result_ready,0,0);
    VL_SIG8(__Vdly__top__DOT__memory_stage__DOT__dcache_inst__DOT__fsm_state,3,0);
    VL_SIG8(__Vdly__top__DOT__memory_stage__DOT__ecall_clean_done,0,0);
    VL_SIG8(__Vdly__m_axi_bready,0,0);
    VL_SIG8(__Vdly__m_axi_wlast,0,0);
    VL_SIG8(__Vdly__m_axi_acready,0,0);
    VL_SIG8(__Vdlyvset__top__DOT__memory_stage__DOT__dcache_inst__DOT__burst_buffer__v0,0,0);
    VL_SIG8(__Vdly__top__DOT__grant_icache,0,0);
    VL_SIG8(__Vdly__top__DOT__grant_dcache,0,0);
    VL_SIG8(__Vclklast__TOP__clk,0,0);
    VL_SIG8(__Vclklast__TOP__reset,0,0);
    VL_SIG8(__Vchglast__TOP__top__DOT__execute_stage__DOT__alu_done,0,0);
    VL_SIG8(__Vchglast__TOP__top__DOT__memory_stage__DOT__dcache_inst__DOT__replace_index,4,0);
    //char	__VpadToAlign55537[7];
    VL_SIG64(__Vdly__top__DOT__fetch_stage__DOT__instruction_cache__DOT__fetch_pc,63,0);
    VL_SIG64(__Vdly__top__DOT__memory_stage__DOT__dcache_inst__DOT__write_address_track,63,0);
    VL_SIG64(__Vchglast__TOP__top__DOT__execute_stage__DOT__alu_result_temp,63,0);
    VL_SIG64(__Vchglast__TOP__top__DOT__memory_stage__DOT__dcache_inst__DOT__dirty_address,63,0);
    VL_SIG64(top__DOT____Vcellout__rf_inst__registers[32],63,0);
    VL_SIG64(top__DOT____Vcellinp__wb_stage__registers[32],63,0);
    VL_SIG8(__Vtablechg1[128],6,0);
    VL_SIG8(__Vtablechg2[16],2,0);
    VL_SIG64(__Vchglast__TOP__top__DOT__memory_stage__DOT__dcache_inst__DOT__tags[32][2],52,0);
    
    // INTERNAL VARIABLES
    // Internals; generally not touched by application code
    //char	__VpadToAlign56748[4];
    Vtop__Syms*	__VlSymsp;		// Symbol table
    
    // PARAMETERS
    // Parameters marked /*verilator public*/ for use by application code
    
    // CONSTRUCTORS
  private:
    Vtop& operator= (const Vtop&);	///< Copying not allowed
    Vtop(const Vtop&);	///< Copying not allowed
  public:
    /// Construct the model; called by application code
    /// The special name  may be used to make a wrapper with a
    /// single model invisible WRT DPI scope names.
    Vtop(const char* name="TOP");
    /// Destroy the model; called (often implicitly) by application code
    ~Vtop();
    
    // USER METHODS
    
    // API METHODS
    /// Evaluate the model.  Application must call when inputs change.
    void eval();
    /// Simulation complete, run final blocks.  Application must call on completion.
    void final();
    
    // INTERNAL METHODS
  private:
    static void _eval_initial_loop(Vtop__Syms* __restrict vlSymsp);
  public:
    void __Vconfigure(Vtop__Syms* symsp, bool first);
  private:
    static QData	_change_request(Vtop__Syms* __restrict vlSymsp);
  public:
    static void	_combo__TOP__10(Vtop__Syms* __restrict vlSymsp);
    static void	_combo__TOP__12(Vtop__Syms* __restrict vlSymsp);
    static void	_combo__TOP__6(Vtop__Syms* __restrict vlSymsp);
  private:
    void	_configure_coverage(Vtop__Syms* __restrict vlSymsp, bool first);
    void	_ctor_var_reset();
  public:
    static void	_eval(Vtop__Syms* __restrict vlSymsp);
    static void	_eval_initial(Vtop__Syms* __restrict vlSymsp);
    static void	_eval_settle(Vtop__Syms* __restrict vlSymsp);
    static void	_final_TOP(Vtop__Syms* __restrict vlSymsp);
    static void	_initial__TOP__1(Vtop__Syms* __restrict vlSymsp);
    static void	_initial__TOP__4(Vtop__Syms* __restrict vlSymsp);
    static void	_sequent__TOP__2(Vtop__Syms* __restrict vlSymsp);
    static void	_sequent__TOP__3(Vtop__Syms* __restrict vlSymsp);
    static void	_sequent__TOP__7(Vtop__Syms* __restrict vlSymsp);
    static void	_sequent__TOP__9(Vtop__Syms* __restrict vlSymsp);
    static void	_settle__TOP__11(Vtop__Syms* __restrict vlSymsp);
    static void	_settle__TOP__5(Vtop__Syms* __restrict vlSymsp);
    static void	_settle__TOP__8(Vtop__Syms* __restrict vlSymsp);
} VL_ATTR_ALIGNED(128);

#endif  /*guard*/
