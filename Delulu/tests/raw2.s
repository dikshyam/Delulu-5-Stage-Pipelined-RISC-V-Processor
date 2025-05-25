# raw_hazard_verified_test.s
.text
.global _start

_start:
    # Initialize registers with primes
    li x1,  1009    # ra
    li x2,  0x10010000  # sp
    li x5,  1021    # t0
    li x6,  1031    # t1
    li x7,  1033    # t2
    li x8,  1039    # s0
    li x9,  1049    # s1
    li x10, 1051    # a0
    li x11, 1061    # a1

    ##############################################
    # RAW Chain 1: Arithmetic → Store → Load
    ##############################################
    add x18, x5, x6      # x18 = 1021 + 1031 = 2052
    add x19, x18, x7     # x19 = 2052 + 1033 = 3085 (RAW on x18)
    sd  x19, 0(x2)       # Store (RAW on x19/x2)
    ld  x20, 0(x2)       # Load back (RAW on x2)

    ##############################################
    # RAW Chain 2: Memory → ALU → Branch
    ##############################################
    lw  x21, 0(x2)       # Load (RAW on x2)
    add x22, x21, x8     # x22 = x21 + 1039 (RAW on x21)
    slli x23, x22, 2     # x23 = x22 << 2 (RAW on x22)

    ##############################################
    # Print All RAW Register Values Before Exit
    ##############################################
    # Store values to memory for debugging
    sd x18, 8(x2)        # x18 = 2052
    sd x19, 16(x2)       # x19 = 3085
    sd x20, 24(x2)       # x20 should = 3085
    sd x21, 32(x2)       # x21 = loaded word
    sd x22, 40(x2)       # x22 = x21 + 1039
    sd x23, 48(x2)       # x23 = x22 << 2

    # ECALL: Print debug info (mock)
    li a7, 64            # "write" syscall (mock)
    mv a1, x2            # Print from [sp]
    li a2, 56            # 7 values * 8 bytes
    li a0, 1             # stdout
    ecall

    # Success exit
    li a7, 93            # exit()
    li a0, 0
    ecall

fail:
    li a7, 93
    li a0, 1             # Fail
    ecall