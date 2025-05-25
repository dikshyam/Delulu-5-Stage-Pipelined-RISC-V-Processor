# advanced_jump_branch_mem_test.s
.text
.global _start

_start:
    # Initialize stack and test values
    li sp, 0x10010000     # Stack pointer
    li a0, 0xCAFEBABE     # Test pattern 1
    li a1, 0xDEADBEEF     # Test pattern 2
    li a2, -1             # -1 (for signed tests)
    li a3, 1              # +1 (for increments)

    ##############################################
    # Memory Write (Setup for later reads)
    ##############################################
    sd a0, 0(sp)          # Store 0xCAFEBABE at [sp+0]
    sd a1, 8(sp)          # Store 0xDEADBEEF at [sp+8]

    ##############################################
    # Branch Stress Test
    ##############################################
branch_test:
    # Test 1: beq (taken)
    beq a3, a3, branch1
    j fail

branch1:
    # Test 2: bne (not taken)
    bne a2, a2, fail
    # Test 3: blt (taken: -1 < 1)
    blt a2, a3, branch2
    j fail

branch2:
    # Test 4: bge (taken: 1 >= -1)
    bge a3, a2, branch3
    j fail

branch3:
    # Test 5: bltu (taken: 0xFFFFFFFF > 1 unsigned)
    li t0, 0xFFFFFFFF
    bltu a3, t0, branch4
    j fail

branch4:
    ##############################################
    # Jump & Memory Read Test
    ##############################################
    # Jump to subroutine
    jal ra, load_values

    # Verify loaded values
    li t0, 0xCAFEBABE
    bne a4, t0, fail      # Check first load
    li t1, 0xDEADBEEF
    bne a5, t1, fail      # Check second load

    ##############################################
    # Jump Register & Arithmetic
    ##############################################
    la t0, mul_test       # Load address
    jalr ra, t0           # Jump-and-link-register

    # Verify multiplication
    li t2, 0xCAFEBABE
    bne a6, t2, fail      # Should be unchanged
    li t3, 0xFFFFFFFF87654322
    bne a7, t3, fail      # 0xCAFEBABE * -1 (64M)

    ##############################################
    # Final Exit
    ##############################################
    li a7, 93             # Exit syscall
    li a0, 0              # Success
    ecall

    ##############################################
    # Subroutines
    ##############################################
load_values:
    # Memory reads (testing load hazards)
    ld a4, 0(sp)          # Load from [sp+0]
    ld a5, 8(sp)          # Load from [sp+8]
    ret

mul_test:
    # RV64M multiplication
    mul a7, a0, a2        # 0xCAFEBABE * -1
    mv a6, a0             # Preserve original
    ret

fail:
    # Failure exit
    li a7, 93
    li a0, 1
    ecall