# robust_arithmetic_branch_jump_test.s
.text
.global _start

_start:
    # Initialize test values
    li a0, 0xFFFFFFFF  # -1 (32-bit)
    li a1, 1
    li a2, 0x12345678
    li a3, 0x7FFFFFFF  # INT32_MAX

    ##############################################
    # Branch Testing
    ##############################################
    # Test 1: beq (taken)
    beq a1, a1, branch1
    j fail  # Should never reach

branch1:
    # Test 2: bne (not taken)
    bne a0, a0, fail
    # Test 3: blt (taken, signed)
    blt a0, a1, branch2
    j fail

branch2:
    # Test 4: bge (taken, signed)
    bge a3, a0, branch3
    j fail

branch3:
    # Test 5: bltu (taken, unsigned)
    li t0, 0xFFFFFFFF
    bltu t0, a1, fail  # 0xFFFFFFFF > 1 unsigned (should NOT branch)
    bltu a1, t0, branch4  # 1 < 0xFFFFFFFF (should branch)
    j fail

branch4:
    ##############################################
    # Jump Testing
    ##############################################
    # Test 6: jal
    jal ra, func1
    # Verify return address
    la t1, return_point
    bne ra, t1, fail

return_point:
    # Test 7: jalr
    la t0, func2
    jalr ra, t0
    bne a0, a2, fail  # Verify func2 preserved a0

    ##############################################
    # Arithmetic Testing (RV32M/64M)
    ##############################################
    # Multiplication
    mul t2, a2, a1  # 0x12345678 * 1
    mulh t3, a2, a0  # High bits (signed)
    mulhu t4, a2, a0 # High bits (unsigned)

    # Division
    div t5, a3, a1   # INT32_MAX / 1
    divu t6, a3, a1  # Unsigned division

    ##############################################
    # Final Checks & Exit
    ##############################################
    # Verify critical results
    li t0, 0x12345678
    bne a2, t0, fail  # Ensure a2 unchanged

    # Success exit
    li a7, 93
    li a0, 0
    ecall

    ##############################################
    # Subroutines
    ##############################################
func1:
    # Modify temp regs
    addi t0, zero, 42
    ret  # pseudo-instruction (jalr zero, ra, 0)

func2:
    # Preserve a0, modify others
    addi t1, zero, 100
    jalr zero, ra, 0

fail:
    # Failure exit
    li a7, 93
    li a0, 1
    ecall