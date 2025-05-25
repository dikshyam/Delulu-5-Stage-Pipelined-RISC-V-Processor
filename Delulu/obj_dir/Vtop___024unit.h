// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtop.h for the primary calling header

#ifndef _Vtop___024unit_H_
#define _Vtop___024unit_H_

#include "verilated_heavy.h"
#include "Vtop__Inlines.h"
#include "Vtop__Dpi.h"

class Vtop__Syms;

//----------

VL_MODULE(Vtop___024unit) {
  public:
    // CELLS
    
    // PORTS
    
    // LOCAL SIGNALS
    
    // LOCAL VARIABLES
    string __Venumtab_enum_name0[256];
    string __Venumtab_enum_name1[128];
    string __Venumtab_enum_name2[8];
    
    // INTERNAL VARIABLES
  private:
    //char	__VpadToAlign12[4];
    Vtop__Syms*	__VlSymsp;		// Symbol table
  public:
    
    // PARAMETERS
    
    // CONSTRUCTORS
  private:
    Vtop___024unit& operator= (const Vtop___024unit&);	///< Copying not allowed
    Vtop___024unit(const Vtop___024unit&);	///< Copying not allowed
  public:
    Vtop___024unit(const char* name="TOP");
    ~Vtop___024unit();
    
    // USER METHODS
    
    // API METHODS
    
    // INTERNAL METHODS
    void __Vconfigure(Vtop__Syms* symsp, bool first);
    void	__Vdpiimwrap_do_ecall_TOP____024unit(QData a7, QData a0, QData a1, QData a2, QData a3, QData a4, QData a5, QData a6, QData& a0ret);
    void	__Vdpiimwrap_do_finish_write_TOP____024unit(QData addr, IData size);
    void	__Vdpiimwrap_do_pending_write_TOP____024unit(QData addr, QData val, IData size);
  private:
    void	_configure_coverage(Vtop__Syms* __restrict vlSymsp, bool first);
    void	_ctor_var_reset();
} VL_ATTR_ALIGNED(128);

#endif  /*guard*/
