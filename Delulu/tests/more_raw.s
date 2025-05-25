# raw_hazard_stress_test.s
.text
.global _start

_start:
    # Initialize registers with primes (avoid trivial patterns)
    li x1,  1009    # ra
    li x2,  0x10010000  # sp (valid memory region)
    li x3,  1013    # gp
    li x4,  1019    # tp
    li x5,  1021    # t0
    li x6,  1031    # t1
    li x7,  1033    # t2
    li x8,  1039    # s0
    li x9,  1049    # s1
    li x10, 1051    # a0
    li x11, 1061    # a1
    li x12, 1063    # a2
    li x13, 1069    # a3
    li x14, 1087    # a4
    li x15, 1091    # a5
    li x16, 1093    # a6
    li x17, 1097    # a7

    ##############################################
    # RAW Chain 1: Arithmetic → Store → Load → Branch
    ##############################################
    add x18, x5, x6      # x18 = t0 + t1 (1021 + 1031 = 2052)
    add x19, x18, x7     # x19 = x18 + t2 (2052 + 1033 = 3085) *RAW on x18*
    sd  x19, 0(x2)       # Store x19 to [sp] *RAW on x19/x2*
    ld  x20, 0(x2)       # Load back *RAW on x2*
    bne x19, x20, fail   # Verify *RAW on x19/x20*

    ##############################################
    # RAW Chain 2: Memory → Arithmetic → Conditional Branch
    ##############################################
    lw  x21, 0(x2)       # Load word *RAW on x2*
    add x22, x21, x8     # x22 = x21 + s0 *RAW on x21*
    slli x23, x22, 2     # x23 = x22 << 2 *RAW on x22*
    blt x23, x21, fail   # Should not branch *RAW on x23/x21*

    ##############################################
    # RAW Chain 3: Cross-Unit Hazards (ALU → Load → ALU)
    ##############################################
    mul x24, x9, x10     # x24 = s1 * a0 (1049 * 1051) *RV64M*
    addi x2, x2, 32      # Move sp *RAW on x2 (from earlier sd)*
    sd  x24, -32(x2)     # Store x24 to [sp-32] *RAW on x2/x24*
    ld  x25, -32(x2)     # Load back *RAW on x2*
    rem x26, x25, x11    # x26 = x25 % a1 *RAW on x25* *RV64M*

    ##############################################
    # RAW Chain 4: Branch → Jump → Memory (Control Hazard)
    ##############################################
    beqz x26, skip_fail  # Should not branch (x26 != 0) *RAW on x26*
    jal x1, func         # Jump to func *RAW on x1 (ra)*
skip_fail:
    add x27, x26, x12    # x27 = x26 + a2 *RAW on x26*
    j verify

func:
    sd  x27, 0(x2)       # Store x27 to [sp] *RAW on x27/x2*
    ret                  # Return *RAW on x1*

verify:
    ##############################################
    # Final Checks
    ##############################################
    # Verify all RAW chains
    li x28, 0xDEADBEEF
    xor x29, x28, x26    # XOR test *RAW on x26*
    sd x29, 0(x2)        # Store result *RAW on x29/x2*
    ld x30, 0(x2)        # Load back *RAW on x2*
    bne x29, x30, fail   # Final check *RAW on x29/x30*

    # Success exit
    li a7, 93
    li a0, 0
    ecall

fail:
    # Failure exit
    li a7, 93
    li a0, 1
    ecall