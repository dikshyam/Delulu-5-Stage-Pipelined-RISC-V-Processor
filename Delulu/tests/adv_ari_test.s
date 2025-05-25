# exhaustive_arithmetic_test.s - Tests all arithmetic instructions
.text
.global _start

_start:
    # Initialize test values (64-bit)
    li a0, 0xFFFFFFFF80000000  # Large +ve (sign-extended)
    li a1, 0x000000007FFFFFFF  # Large +ve
    li a2, 0xFFFFFFFFFFFFFFFF  # -1
    li a3, 0x0000000000000001  # +1

    ##############################################
    # RV32I/RV64I Base Instructions
    ##############################################
    # Addition
    add a4, a0, a1        # Overflow test
    add a5, a2, a3        # -1 + 1 = 0

    # Subtraction
    sub a6, a0, a1        # Large -ve result
    sub a7, a3, a2        # 1 - (-1) = 2

    # Logical
    xor t0, a0, a1        # XOR test
    or  t1, a0, a3        # OR test
    and t2, a1, a2        # AND test

    # Shifts (32/64-bit)
    sll t3, a1, a3        # Logical left
    srl t4, a0, a3        # Logical right (zero-extend)
    sra t5, a0, a3        # Arithmetic right (sign-extend)

    ##############################################
    # RV32M Extension (32-bit multiply/divide)
    ##############################################
    # Multiplication (32-bit)
    mul t6, a0, a1        # 32-bit product (hi bits truncated)
    mulh s0, a0, a1       # High 32 bits of signed multiply
    mulhu s1, a0, a1      # High 32 bits of unsigned multiply

    # Division (32-bit)
    div s2, a0, a3        # Signed division
    divu s3, a1, a3       # Unsigned division
    rem s4, a0, a1        # Signed remainder
    remu s5, a1, a3       # Unsigned remainder

    ##############################################
    # RV64M Extension (64-bit multiply/divide)
    ##############################################
    # Multiplication (64-bit)
    mulw s6, a0, a1       # 64-bit product (truncated to 32, sign-ext to 64)
    mulhsu s7, a0, a1     # High 64 bits of signed-unsigned multiply

    # Division (64-bit)
    divw t0, a0, a2       # 64-bit signed division
    divuw t1, a1, a3      # 64-bit unsigned division
    remw t2, a0, a1       # 64-bit signed remainder
    remuw t3, a1, a3      # 64-bit unsigned remainder

    ##############################################
    # Final Checks & Exit
    ##############################################
    # Verify critical results
    add t4, zero, zero    # t4 = 0 (expected for a5)
    bne a5, t4, fail      # Check -1 + 1 = 0

    li t5, 2
    bne a7, t5, fail      # Check 1 - (-1) = 2

    # Successful exit
    li a7, 93             # Exit syscall
    li a0, 0              # Success
    ecall

fail:
    # Failure exit
    li a7, 93
    li a0, 1              # Error code
    ecall