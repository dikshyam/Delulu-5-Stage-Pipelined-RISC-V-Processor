# pure_riscv_test.s
.text
.global _start

_start:
    ##############################################
    # 1. Register Initialization
    ##############################################
    li x1,  0x11111111  # ra
    li x2,  0x10020000  # sp
    li x5,  0x55555555  # t0
    li x6,  0x66666666  # t1
    li x10, 0xAAAAAAAA  # a0
    li x11, 0xBBBBBBBB  # a1
    li x12, 0xCCCCCCCC  # a2

    ##############################################
    # 2. Arithmetic & RAW Hazards
    ##############################################
    add x7, x10, x11     # t2 = a0 + a1
    sub x8, x12, x7      # t3 = a2 - t2 (RAW hazard)
    xor x9, x10, x11     # t4 = a0 ^ a1

    ##############################################
    # 3. Memory Ops (No ECALLs)
    ##############################################
    sd x1,  0(sp)        # Store ra
    sd x5,  8(sp)        # Store t0
    ld x13, 0(sp)        # Load back (x13 = ra)
    ld x14, 8(sp)        # Load back (x14 = t0)

    ##############################################
    # 4. Branches & Jumps
    ##############################################
    beq x13, x1, branch_ok  # Verify load
    j fail

branch_ok:
    blt x5, x6, jump_test   # t0(0x55) < t1(0x66)
    j fail

jump_test:
    jal ra, subroutine
    bne x15, x1, fail      # Verify subroutine

    ##############################################
    # 5. ECALL Termination (ONLY ECALL)
    ##############################################
    li a7, 93              # EXIT (ONLY SYSCALL)
    li a0, 0               # Success
    ecall

    ##############################################
    # Subroutines
    ##############################################
subroutine:
    addi x15, x1, 0        # x15 = ra
    ret

fail:
    li a7, 93              # EXIT (ONLY SYSCALL)
    li a0, 1               # Fail
    ecall