# basic_arithmetic_test.s - Will definitely terminate
.text
.global _start

_start:
    # Initialize registers
    li a0, 10            # a0 = 10
    li a1, 20            # a1 = 20
    li a2, 30            # a2 = 30
    
    # Core arithmetic operations
    add a3, a0, a1       # a3 = 10 + 20 = 30
    add a4, a3, a2       # a4 = 30 + 30 = 60
    sub a5, a4, a0       # a5 = 60 - 10 = 50
    xor a6, a5, a1       # a6 = 50 ^ 20
    or a7, a6, a2        # a7 = a6 | 30
    
    # Prepare exit syscall
    li a7, 93            # Exit syscall number (93)
    li a0, 0             # Exit code 0 (success)
    ecall                # Terminate execution
    
    # Safety infinite loop (only reached if ECALL fails)
    infloop:
        j infloop