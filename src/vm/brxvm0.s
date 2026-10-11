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
vm_locals: .skip 2048
vm_local_init: .skip 32
vm_verify_init: .skip 32
vm_num_buf: .skip 32
vm_file_len: .quad 0
vm_fd: .quad 0
vm_code_size: .quad 0
vm_data_size: .quad 0
vm_pc: .quad 0
vm_code_end: .quad 0
vm_data: .quad 0
vm_sp: .quad 0
vm_tmp: .quad 0
vm_verify_pc: .quad 0
vm_verify_depth: .quad 0
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
    movq %rax, vm_fd(%rip)
    movq $0, vm_file_len(%rip)
.vm_read_loop:
    movq vm_file_len(%rip), %rcx
    cmpq $131071, %rcx
    jae .vm_probe_extra
    movq vm_fd(%rip), %rdi
    leaq vm_file(%rip), %rsi
    addq %rcx, %rsi
    movq $131071, %rdx
    subq %rcx, %rdx
    xorq %rax, %rax
    syscall
    cmpq $-4, %rax                # retry read on EINTR
    je .vm_read_loop
    testq %rax, %rax
    js .vm_bad_error
    jz .vm_read_complete
    addq %rax, vm_file_len(%rip)
    jmp .vm_read_loop
.vm_probe_extra:
    movq vm_fd(%rip), %rdi
    leaq vm_file+131071(%rip), %rsi
    movq $1, %rdx
    xorq %rax, %rax
    syscall
    cmpq $-4, %rax                # retry size probe on EINTR
    je .vm_probe_extra
    testq %rax, %rax
    js .vm_bad_error
    testq %rax, %rax
    jnz .vm_bad_error            # reject input larger than the file buffer
.vm_read_complete:
    movq vm_file_len(%rip), %rax
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
    movq vm_pc(%rip), %rax
    movq %rax, vm_verify_pc(%rip)
    movq $0, vm_verify_depth(%rip)
    call vm_verify_code
    jmp .vm_dispatch
# Linear preflight: this ISA subset has no branches or calls yet.
# Therefore stack depth and local initialization have a single path.
vm_verify_code:
.vm_verify_loop:
    movq vm_verify_pc(%rip), %rsi
    cmpq vm_code_end(%rip), %rsi
    je .vm_verify_done
    ja .vm_bad_error
    movzbl (%rsi), %eax
    incq %rsi
    movq %rsi, vm_verify_pc(%rip)
    cmpq $0, %rax
    je .vm_verify_loop
    cmpq $1, %rax
    je .vm_verify_push
    cmpq $2, %rax
    je .vm_verify_load_local
    cmpq $3, %rax
    je .vm_verify_store_local
    cmpq $4, %rax
    je .vm_verify_binary
    cmpq $5, %rax
    je .vm_verify_binary
    cmpq $6, %rax
    je .vm_verify_binary
    cmpq $7, %rax
    je .vm_verify_binary
    cmpq $8, %rax
    je .vm_verify_binary
    cmpq $9, %rax
    je .vm_verify_print_int
    cmpq $10, %rax
    je .vm_verify_print_const
    jmp .vm_bad_error
.vm_verify_push:
    leaq 8(%rsi), %rdx
    cmpq vm_code_end(%rip), %rdx
    ja .vm_bad_error
    movq %rdx, vm_verify_pc(%rip)
    movq vm_verify_depth(%rip), %r8
    cmpq $256, %r8
    jae .vm_bad_error
    incq %r8
    movq %r8, vm_verify_depth(%rip)
    jmp .vm_verify_loop
.vm_verify_load_local:
    movq vm_verify_pc(%rip), %rsi
    leaq 2(%rsi), %rdx
    cmpq vm_code_end(%rip), %rdx
    ja .vm_bad_error
    movzwq (%rsi), %r8
    movq %rdx, vm_verify_pc(%rip)
    cmpq $256, %r8
    jae .vm_bad_error
    leaq vm_verify_init(%rip), %r10
    btq %r8, (%r10)
    jnc .vm_bad_error
    movq vm_verify_depth(%rip), %r9
    cmpq $256, %r9
    jae .vm_bad_error
    incq %r9
    movq %r9, vm_verify_depth(%rip)
    jmp .vm_verify_loop
.vm_verify_store_local:
    movq vm_verify_pc(%rip), %rsi
    leaq 2(%rsi), %rdx
    cmpq vm_code_end(%rip), %rdx
    ja .vm_bad_error
    movzwq (%rsi), %r8
    movq %rdx, vm_verify_pc(%rip)
    cmpq $256, %r8
    jae .vm_bad_error
    movq vm_verify_depth(%rip), %r9
    testq %r9, %r9
    jz .vm_bad_error
    decq %r9
    movq %r9, vm_verify_depth(%rip)
    leaq vm_verify_init(%rip), %r10
    btsq %r8, (%r10)
    jmp .vm_verify_loop
.vm_verify_binary:
    movq vm_verify_depth(%rip), %r8
    cmpq $2, %r8
    jb .vm_bad_error
    decq %r8
    movq %r8, vm_verify_depth(%rip)
    jmp .vm_verify_loop
.vm_verify_print_int:
    movq vm_verify_depth(%rip), %r8
    testq %r8, %r8
    jz .vm_bad_error
    decq %r8
    movq %r8, vm_verify_depth(%rip)
    jmp .vm_verify_loop
.vm_verify_print_const:
    leaq 8(%rsi), %rdx
    cmpq vm_code_end(%rip), %rdx
    ja .vm_bad_error
    movl 0(%rsi), %r8d
    movl 4(%rsi), %r9d
    movq vm_data_size(%rip), %rax
    cmpq %rax, %r8
    ja .vm_bad_error
    subq %r8, %rax
    cmpq %rax, %r9
    ja .vm_bad_error
    movq %rdx, vm_verify_pc(%rip)
    jmp .vm_verify_loop
.vm_verify_done:
    ret
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
    cmpq $2, %rax
    je .vm_load_local
    cmpq $3, %rax
    je .vm_store_local
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
.vm_load_local:
    movq vm_pc(%rip), %rsi
    leaq 2(%rsi), %rdx
    cmpq vm_code_end(%rip), %rdx
    ja .vm_bad_error
    movzwq (%rsi), %r8
    movq %rdx, vm_pc(%rip)
    cmpq $256, %r8
    jae .vm_bad_error
    leaq vm_local_init(%rip), %r10
    btq %r8, (%r10)
    jnc .vm_bad_error
    leaq vm_locals(%rip), %r10
    movq (%r10,%r8,8), %rax
    movq vm_sp(%rip), %r8
    cmpq $256, %r8
    jae .vm_bad_error
    leaq vm_stack(%rip), %r9
    movq %rax, (%r9,%r8,8)
    incq %r8
    movq %r8, vm_sp(%rip)
    jmp .vm_dispatch
.vm_store_local:
    movq vm_pc(%rip), %rsi
    leaq 2(%rsi), %rdx
    cmpq vm_code_end(%rip), %rdx
    ja .vm_bad_error
    movzwq (%rsi), %r8
    movq %rdx, vm_pc(%rip)
    cmpq $256, %r8
    jae .vm_bad_error
    movq vm_sp(%rip), %r9
    testq %r9, %r9
    jz .vm_bad_error
    decq %r9
    leaq vm_stack(%rip), %r10
    movq (%r10,%r9,8), %rax
    movq %r9, vm_sp(%rip)
    leaq vm_locals(%rip), %r10
    movq %rax, (%r10,%r8,8)
    leaq vm_local_init(%rip), %r10
    btsq %r8, (%r10)
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
