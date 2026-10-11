.section .rodata
vm_usage: .ascii "uso: brxvm0 modulo.brxe\n"
vm_usage_len = . - vm_usage
vm_bad: .ascii "BRXE: modulo invalido ou instrucao proibida\n"
vm_bad_len = . - vm_bad
vm_open: .ascii "BRXE: nao foi possivel abrir modulo\n"
vm_open_len = . - vm_open
vm_nl: .byte 10
.section .bss
.align 16
vm_file: .skip 131072
vm_stack: .skip 2048
vm_num_buf: .skip 32
vm_file_len: .quad 0
vm_code_size: .quad 0
vm_data_size: .quad 0
vm_pc: .quad 0
vm_code_end: .quad 0
vm_data: .quad 0
vm_sp: .quad 0
vm_tmp: .quad 0
.section .text
.global _start
_start:
    movq (%rsp), %rax
    cmpq $2, %rax
    jne .vm_usage
    movq 16(%rsp), %rdi
    movq $2, %rax
    xorq %rsi, %rsi
    syscall
    testq %rax, %rax
    js .vm_open_error
    movq %rax, %rdi
    leaq vm_file(%rip), %rsi
    movq $131071, %rdx
    xorq %rax, %rax
    syscall
    testq %rax, %rax
    js .vm_bad_error
    movq %rax, vm_file_len(%rip)
    cmpq $16, %rax
    jb .vm_bad_error
    leaq vm_file(%rip), %rsi
    cmpb $66, 0(%rsi)             # B
    jne .vm_bad_error
    cmpb $82, 1(%rsi)             # R
    jne .vm_bad_error
    cmpb $88, 2(%rsi)             # X
    jne .vm_bad_error
    cmpb $69, 3(%rsi)             # E
    jne .vm_bad_error
    cmpw $1, 4(%rsi)              # version 1
    jne .vm_bad_error
    cmpw $0, 6(%rsi)              # flags reserved
    jne .vm_bad_error
    movl 8(%rsi), %eax
    movq %rax, vm_code_size(%rip)
    movl 12(%rsi), %eax
    movq %rax, vm_data_size(%rip)
    movq vm_code_size(%rip), %rax
    addq vm_data_size(%rip), %rax
    addq $16, %rax
    cmpq vm_file_len(%rip), %rax
    jne .vm_bad_error
    leaq vm_file+16(%rip), %rax
    movq %rax, vm_pc(%rip)
    addq vm_code_size(%rip), %rax
    movq %rax, vm_code_end(%rip)
    movq %rax, vm_data(%rip)
    movq $0, vm_sp(%rip)
.vm_dispatch:
    movq vm_pc(%rip), %rsi
    cmpq vm_code_end(%rip), %rsi
    jae .vm_bad_error
    movzbl (%rsi), %eax
    incq %rsi
    movq %rsi, vm_pc(%rip)
    cmpq $0, %rax
    je .vm_halt
    cmpq $1, %rax
    je .vm_push_i64
    cmpq $4, %rax
    je .vm_add
    cmpq $5, %rax
    je .vm_sub
    cmpq $6, %rax
    je .vm_mul
    cmpq $7, %rax
    je .vm_div
    cmpq $8, %rax
    je .vm_mod
    cmpq $9, %rax
    je .vm_print_i64
    cmpq $10, %rax
    je .vm_print_const
    jmp .vm_bad_error
.vm_push_i64:
    movq vm_pc(%rip), %rsi
    leaq 8(%rsi), %rdx
    cmpq vm_code_end(%rip), %rdx
    ja .vm_bad_error
    movq (%rsi), %rax
    movq %rdx, vm_pc(%rip)
    movq vm_sp(%rip), %r8
    cmpq $256, %r8
    jae .vm_bad_error
    leaq vm_stack(%rip), %r9
    movq %rax, (%r9,%r8,8)
    incq %r8
    movq %r8, vm_sp(%rip)
    jmp .vm_dispatch
.vm_add:
    movq $1, vm_tmp(%rip)
    jmp .vm_binary
.vm_sub:
    movq $2, vm_tmp(%rip)
    jmp .vm_binary
.vm_mul:
    movq $3, vm_tmp(%rip)
    jmp .vm_binary
.vm_div:
    movq $4, vm_tmp(%rip)
    jmp .vm_binary
.vm_mod:
    movq $5, vm_tmp(%rip)
.vm_binary:
    movq vm_sp(%rip), %r8
    cmpq $2, %r8
    jb .vm_bad_error
    leaq vm_stack(%rip), %r9
    decq %r8
    movq (%r9,%r8,8), %rdx      # right operand
    decq %r8
    movq (%r9,%r8,8), %rax      # left operand
    movq vm_tmp(%rip), %rcx
    cmpq $1, %rcx
    je .vm_do_add
    cmpq $2, %rcx
    je .vm_do_sub
    cmpq $3, %rcx
    je .vm_do_mul
    movq %rdx, %r11
    testq %r11, %r11
    jz .vm_bad_error
    cmpq $-1, %r11
    jne .vm_div_safe
    movabsq $0x8000000000000000, %r10
    cmpq %r10, %rax
    je .vm_bad_error
.vm_div_safe:
    cqo
    idivq %r11
    cmpq $4, %rcx
    je .vm_store_result
    movq %rdx, %rax
    jmp .vm_store_result
.vm_do_add:
    addq %rdx, %rax
    jmp .vm_store_result
.vm_do_sub:
    subq %rdx, %rax
    jmp .vm_store_result
.vm_do_mul:
    imulq %rdx, %rax
.vm_store_result:
    movq %rax, (%r9,%r8,8)
    incq %r8
    movq %r8, vm_sp(%rip)
    jmp .vm_dispatch
.vm_print_i64:
    movq vm_sp(%rip), %r8
    testq %r8, %r8
    jz .vm_bad_error
    decq %r8
    leaq vm_stack(%rip), %r9
    movq (%r9,%r8,8), %rdi
    movq %r8, vm_sp(%rip)
    call vm_print_int
    jmp .vm_dispatch
.vm_print_const:
    movq vm_pc(%rip), %rsi
    leaq 8(%rsi), %rdx
    cmpq vm_code_end(%rip), %rdx
    ja .vm_bad_error
    movl 0(%rsi), %r8d
    movl 4(%rsi), %r9d
    movq %rdx, vm_pc(%rip)
    movq vm_data_size(%rip), %rax
    cmpq %rax, %r8
    ja .vm_bad_error
    subq %r8, %rax
    cmpq %rax, %r9
    ja .vm_bad_error
    movq $1, %rax
    movq $1, %rdi
    movq vm_data(%rip), %rsi
    addq %r8, %rsi
    movq %r9, %rdx
    syscall
    call vm_emit_nl
    jmp .vm_dispatch
.vm_halt:
    movq $60, %rax
    xorq %rdi, %rdi
    syscall

# Print signed integer in rdi; emit newline.
vm_print_int:
    leaq vm_num_buf+31(%rip), %rsi
    movb $10, (%rsi)
    movq %rdi, %rax
    xorq %r8, %r8
    testq %rax, %rax
    jns .vm_fmt_abs
    movq $1, %r8
    negq %rax
.vm_fmt_abs:
    movq $10, %r9
.vm_fmt_loop:
    xorq %rdx, %rdx
    divq %r9
    addb $48, %dl
    decq %rsi
    movb %dl, (%rsi)
    testq %rax, %rax
    jnz .vm_fmt_loop
    testq %r8, %r8
    jz .vm_fmt_write
    decq %rsi
    movb $45, (%rsi)
.vm_fmt_write:
    leaq vm_num_buf+32(%rip), %rdx
    subq %rsi, %rdx
    movq $1, %rax
    movq $1, %rdi
    syscall
    ret
vm_emit_nl:
    movq $1, %rax
    movq $1, %rdi
    leaq vm_nl(%rip), %rsi
    movq $1, %rdx
    syscall
    ret
.vm_usage:
    leaq vm_usage(%rip), %rsi
    movq $vm_usage_len, %rdx
    jmp .vm_error_exit
.vm_open_error:
    leaq vm_open(%rip), %rsi
    movq $vm_open_len, %rdx
    jmp .vm_error_exit
.vm_bad_error:
    leaq vm_bad(%rip), %rsi
    movq $vm_bad_len, %rdx
.vm_error_exit:
    movq $1, %rax
    movq $2, %rdi
    syscall
    movq $60, %rax
    movq $1, %rdi
    syscall
