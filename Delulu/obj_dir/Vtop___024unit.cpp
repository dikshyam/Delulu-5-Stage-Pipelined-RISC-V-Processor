// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtop.h for the primary calling header

#include "Vtop___024unit.h"    // For This
#include "Vtop__Syms.h"

#include "verilated_dpi.h"

//--------------------
// STATIC VARIABLES

string __Venumtab_enum_name0[256];
string __Venumtab_enum_name1[128];
string __Venumtab_enum_name2[8];

//--------------------

VL_CTOR_IMP(Vtop___024unit) {
    // Reset internal values
    // Reset structure values
    _ctor_var_reset();
}

void Vtop___024unit::__Vconfigure(Vtop__Syms* vlSymsp, bool first) {
    if (0 && first) {}  // Prevent unused
    this->__VlSymsp = vlSymsp;
}

Vtop___024unit::~Vtop___024unit() {
}

//--------------------
// Internal Methods

VL_INLINE_OPT void Vtop___024unit::__Vdpiimwrap_do_pending_write_TOP____024unit(QData addr, QData val, IData size) {
    VL_DEBUG_IF(VL_PRINTF("        Vtop___024unit::__Vdpiimwrap_do_pending_write_TOP____024unit\n"); );
    // Body
    long long addr__Vcvt;
    addr__Vcvt = addr;
    long long val__Vcvt;
    val__Vcvt = val;
    int size__Vcvt;
    size__Vcvt = size;
    do_pending_write(addr__Vcvt, val__Vcvt, size__Vcvt);
}

VL_INLINE_OPT void Vtop___024unit::__Vdpiimwrap_do_finish_write_TOP____024unit(QData addr, IData size) {
    VL_DEBUG_IF(VL_PRINTF("        Vtop___024unit::__Vdpiimwrap_do_finish_write_TOP____024unit\n"); );
    // Body
    long long addr__Vcvt;
    addr__Vcvt = addr;
    int size__Vcvt;
    size__Vcvt = size;
    do_finish_write(addr__Vcvt, size__Vcvt);
}

VL_INLINE_OPT void Vtop___024unit::__Vdpiimwrap_do_ecall_TOP____024unit(QData a7, QData a0, QData a1, QData a2, QData a3, QData a4, QData a5, QData a6, QData& a0ret) {
    VL_DEBUG_IF(VL_PRINTF("        Vtop___024unit::__Vdpiimwrap_do_ecall_TOP____024unit\n"); );
    // Body
    long long a7__Vcvt;
    a7__Vcvt = a7;
    long long a0__Vcvt;
    a0__Vcvt = a0;
    long long a1__Vcvt;
    a1__Vcvt = a1;
    long long a2__Vcvt;
    a2__Vcvt = a2;
    long long a3__Vcvt;
    a3__Vcvt = a3;
    long long a4__Vcvt;
    a4__Vcvt = a4;
    long long a5__Vcvt;
    a5__Vcvt = a5;
    long long a6__Vcvt;
    a6__Vcvt = a6;
    long long a0ret__Vcvt;
    do_ecall(a7__Vcvt, a0__Vcvt, a1__Vcvt, a2__Vcvt, a3__Vcvt, a4__Vcvt, a5__Vcvt, a6__Vcvt, &a0ret__Vcvt);
    a0ret = a0ret__Vcvt;
}

void Vtop___024unit::_ctor_var_reset() {
    VL_DEBUG_IF(VL_PRINTF("        Vtop___024unit::_ctor_var_reset\n"); );
    // Body
    { int __Vi=0; for (; __Vi<256; ++__Vi) {
	    __Venumtab_enum_name0[__Vi] = string("");
    }}
    __Venumtab_enum_name0[0] = string("ALU_ADD");
    __Venumtab_enum_name0[1] = string("ALU_SUB");
    __Venumtab_enum_name0[2] = string("ALU_XOR");
    __Venumtab_enum_name0[3] = string("ALU_OR");
    __Venumtab_enum_name0[4] = string("ALU_AND");
    __Venumtab_enum_name0[5] = string("ALU_SLL");
    __Venumtab_enum_name0[6] = string("ALU_SRL");
    __Venumtab_enum_name0[7] = string("ALU_SRA");
    __Venumtab_enum_name0[8] = string("ALU_SLT");
    __Venumtab_enum_name0[9] = string("ALU_SLTU");
    __Venumtab_enum_name0[10] = string("ALU_MUL");
    __Venumtab_enum_name0[11] = string("ALU_MULH");
    __Venumtab_enum_name0[12] = string("ALU_MULHSU");
    __Venumtab_enum_name0[13] = string("ALU_MULHU");
    __Venumtab_enum_name0[14] = string("ALU_DIV");
    __Venumtab_enum_name0[15] = string("ALU_DIVU");
    __Venumtab_enum_name0[16] = string("ALU_REM");
    __Venumtab_enum_name0[17] = string("ALU_REMU");
    __Venumtab_enum_name0[18] = string("ALU_ADDI");
    __Venumtab_enum_name0[19] = string("ALU_XORI");
    __Venumtab_enum_name0[20] = string("ALU_ORI");
    __Venumtab_enum_name0[21] = string("ALU_ANDI");
    __Venumtab_enum_name0[22] = string("ALU_SLLI");
    __Venumtab_enum_name0[23] = string("ALU_SRLI");
    __Venumtab_enum_name0[24] = string("ALU_SRAI");
    __Venumtab_enum_name0[25] = string("ALU_SLTI");
    __Venumtab_enum_name0[26] = string("ALU_SLTIU");
    __Venumtab_enum_name0[30] = string("ALU_ADDIW");
    __Venumtab_enum_name0[31] = string("ALU_SLLIW");
    __Venumtab_enum_name0[32] = string("ALU_SRLIW");
    __Venumtab_enum_name0[33] = string("ALU_SRAIW");
    __Venumtab_enum_name0[34] = string("ALU_ADDW");
    __Venumtab_enum_name0[35] = string("ALU_SUBW");
    __Venumtab_enum_name0[36] = string("ALU_SLLW");
    __Venumtab_enum_name0[37] = string("ALU_SRLW");
    __Venumtab_enum_name0[38] = string("ALU_SRAW");
    __Venumtab_enum_name0[39] = string("ALU_MULW");
    __Venumtab_enum_name0[40] = string("ALU_DIVW");
    __Venumtab_enum_name0[41] = string("ALU_DIVUW");
    __Venumtab_enum_name0[42] = string("ALU_REMW");
    __Venumtab_enum_name0[43] = string("ALU_REMUW");
    __Venumtab_enum_name0[50] = string("ALU_SB");
    __Venumtab_enum_name0[51] = string("ALU_SH");
    __Venumtab_enum_name0[52] = string("ALU_SW");
    __Venumtab_enum_name0[53] = string("ALU_SD");
    __Venumtab_enum_name0[60] = string("ALU_BEQ");
    __Venumtab_enum_name0[61] = string("ALU_BNE");
    __Venumtab_enum_name0[62] = string("ALU_BLT");
    __Venumtab_enum_name0[63] = string("ALU_BGE");
    __Venumtab_enum_name0[64] = string("ALU_BLTU");
    __Venumtab_enum_name0[65] = string("ALU_BGEU");
    __Venumtab_enum_name0[70] = string("ALU_JAL");
    __Venumtab_enum_name0[71] = string("ALU_JALR");
    __Venumtab_enum_name0[72] = string("ALU_LUI");
    __Venumtab_enum_name0[73] = string("ALU_AUIPC");
    __Venumtab_enum_name0[74] = string("ALU_ECALL");
    __Venumtab_enum_name0[75] = string("ALU_EBREAK");
    __Venumtab_enum_name0[80] = string("ALU_LB");
    __Venumtab_enum_name0[81] = string("ALU_LH");
    __Venumtab_enum_name0[82] = string("ALU_LW");
    __Venumtab_enum_name0[83] = string("ALU_LBU");
    __Venumtab_enum_name0[84] = string("ALU_LHU");
    __Venumtab_enum_name0[85] = string("ALU_LWU");
    __Venumtab_enum_name0[86] = string("ALU_LD");
    __Venumtab_enum_name0[255] = string("ALU_NOP");
    { int __Vi=0; for (; __Vi<128; ++__Vi) {
	    __Venumtab_enum_name1[__Vi] = string("");
    }}
    __Venumtab_enum_name1[3] = string("OP_LOAD");
    __Venumtab_enum_name1[15] = string("OP_MISC_MEM");
    __Venumtab_enum_name1[19] = string("OP_OP_IMM");
    __Venumtab_enum_name1[23] = string("OP_AUIPC");
    __Venumtab_enum_name1[27] = string("OP_IMM_32");
    __Venumtab_enum_name1[35] = string("OP_STORE");
    __Venumtab_enum_name1[51] = string("OP_OP");
    __Venumtab_enum_name1[55] = string("OP_LUI");
    __Venumtab_enum_name1[59] = string("OP_OP_32");
    __Venumtab_enum_name1[99] = string("OP_BRANCH");
    __Venumtab_enum_name1[103] = string("OP_JALR");
    __Venumtab_enum_name1[111] = string("OP_JAL");
    __Venumtab_enum_name1[115] = string("OP_SYSTEM");
    { int __Vi=0; for (; __Vi<8; ++__Vi) {
	    __Venumtab_enum_name2[__Vi] = string("");
    }}
    __Venumtab_enum_name2[0] = string("JUMP_NO");
    __Venumtab_enum_name2[1] = string("JUMP_YES");
    __Venumtab_enum_name2[2] = string("JUMP_ALU_EQZ");
    __Venumtab_enum_name2[3] = string("JUMP_ALU_NEZ");
    __Venumtab_enum_name2[4] = string("JUMP_ALU_LT");
    __Venumtab_enum_name2[5] = string("JUMP_ALU_GE");
    __Venumtab_enum_name2[6] = string("JUMP_ALU_LTU");
    __Venumtab_enum_name2[7] = string("JUMP_ALU_GEU");
}

void Vtop___024unit::_configure_coverage(Vtop__Syms* __restrict vlSymsp, bool first) {
    VL_DEBUG_IF(VL_PRINTF("        Vtop___024unit::_configure_coverage\n"); );
}
