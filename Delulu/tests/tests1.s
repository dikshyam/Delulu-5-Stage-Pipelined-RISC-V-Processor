# robust_memory_branch_jump_test.s
.text
.global _start

_start:
    # Initialize stack and test values
    li sp, 0x10010000     # Stack pointer
    li a0, 0xCAFEBABE     # Test pattern 1
    li a1, 0xDEADBEEF     # Test pattern 2
    li a2, -1             # For signed tests
    li a3, 1              # For increments

    ##############################################
    # Memory Setup (RAW hazard source)
    ##############################################
    sd a0, 0(sp)          # Store 0xCAFEBABE at [sp+0]
    sd a1, 8(sp)          # Store 0xDEADBEEF at [sp+8]

    ##############################################
    # Branch Test Mix
    ##############################################
    beq a3, a3, branch1   # Always taken
    j fail                # Should never reach

branch1:
    bne a2, a2, fail      # Never taken
    blt a2, a3, branch2   # Taken (-1 < 1)
    j fail

branch2:
    bge a3, a2, branch3   # Taken (1 >= -1)
    j fail

branch3:
    li t0, 0xFFFFFFFF
    bltu a3, t0, branch4  # Taken (1 < 0xFFFFFFFF unsigned)
    j fail

branch4:
    ##############################################
    # Memory RAW Hazard Chain
    ##############################################
    ld t1, 0(sp)          # Load 0xCAFEBABE (RAW on sd)
    add t2, t1, a3        # t2 = 0xCAFEBABF (RAW on t1)
    sd t2, 16(sp)         # Store to [sp+16] (RAW on t2)

    ld t3, 8(sp)          # Load 0xDEADBEEF (RAW on sd)
    sub t4, t3, a3        # t4 = 0xDEADBEEE (RAW on t3)
    sd t4, 24(sp)         # Store to [sp+24] (RAW on t4)

    ##############################################
    # Jump & Link with Memory
    ##############################################
    jal ra, load_and_verify
    bnez a0, fail         # Verify subroutine success

    ##############################################
    # Jump Register Test
    ##############################################
    la t0, mul_ops        # Load address
    jalr ra, t0           # Jump to mul_ops
    bnez a0, fail         # Verify success

    ##############################################
    # Final Exit
    ##############################################
    li a7, 93             # Exit syscall
    li a0, 0              # Success
    ecall

    ##############################################
    # Subroutines
    ##############################################
load_and_verify:
    # Memory RAW hazard test
    ld t5, 16(sp)         # Load 0xCAFEBABF (RAW on sd)
    li t6, 0xCAFEBABF
    bne t5, t6, fail_sub  # Verify
    ld t5, 24(sp)         # Load 0xDEADBEEE (RAW on sd)
    li t6, 0xDEADBEEE
    bne t5, t6, fail_sub  # Verify
    li a0, 0              # Success
    ret

fail_sub:
    li a0, 1              # Fail
    ret

mul_ops:
    # RV64M operations with memory
    ld t0, 0(sp)          # 0xCAFEBABE
    mul t1, t0, a3        # 0xCAFEBABE * 1
    mulh t2, t0, a2       # High bits (0xCAFEBABE * -1)
    sd t1, 32(sp)         # Store product
    li a0, 0              # Success
    ret

fail:
    li a7, 93
    li a0, 1              # Fail code
    ecall