_start:
    # Initialize critical registers
    li x2, 0x10010000  # sp (valid address)
    li x5, 0x1234      # t0
    li x4, 0x5678      # t1

    # RAW hazard chain
    add x6, x5, x4     # x6 = t2 (0x68AC)
    sd  x6, 0(x2)      # Store (depends on x6, x2)
    ld  x7, 0(x2)      # Load  (depends on x2)

    # Verify
    bne x6, x7, fail   # Check RAW correctness

    # Success exit
    li a7, 93
    li a0, 0
    ecall

fail:
    li a7, 93
    li a0, 1
    ecall