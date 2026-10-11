.section .rodata
usage: .ascii "uso: brx0 arquivo.brx\n"
usage_len = . - usage
err_open: .ascii "BRX erro: nao foi possivel abrir arquivo\n"
err_open_len = . - err_open
err_syntax: .ascii "BRX erro: sintaxe ou variavel invalida\n"
err_syntax_len = . - err_syntax
kw_out: .asciz "out"
kw_var: .asciz "var"
kw_run: .asciz "run"
newline: .byte 10

.section .bss
.align 16
source: .skip 65536
vars: .skip 64*40
namebuf: .skip 64
num_buf: .skip 32
src_len: .quad 0
line_ptr: .quad 0
line_start: .quad 0
line_end: .quad 0
cur: .quad 0
name_len: .quad 0
var_ptr: .quad 0
val: .quad 0
op_kind: .quad 0

.section .text
.global _start
_start:
    movq (%rsp), %rax
    cmpq $2, %rax
    jne .usage
    movq 16(%rsp), %rdi
    movq $2, %rax                 # open(path, O_RDONLY)
    xorq %rsi, %rsi
    syscall
    testq %rax, %rax
    js .open_error
    movq %rax, %rdi
    leaq source(%rip), %rsi
    movq $65535, %rdx
    xorq %rax, %rax                # read(fd, source, cap)
    syscall
    testq %rax, %rax
    js .read_error
    movq %rax, src_len(%rip)
    movq %rax, %rdx
    leaq source(%rip), %rdi
    movb $0, (%rdi,%rdx)
    movq $0, line_ptr(%rip)
.next_line:
    movq line_ptr(%rip), %rax
    cmpq src_len(%rip), %rax
    jae .success
    leaq source(%rip), %rdi
    addq %rax, %rdi
    movq %rdi, line_start(%rip)
    movq %rdi, %rsi
.find_eol:
    cmpb $0, (%rsi)
    je .got_eol
    cmpb $10, (%rsi)
    je .got_eol
    incq %rsi
    jmp .find_eol
.got_eol:
    movq %rsi, line_end(%rip)
    leaq source(%rip), %rax
    subq %rax, %rsi
    incq %rsi
    movq %rsi, line_ptr(%rip)
    movq line_end(%rip), %rax
    movb $0, (%rax)
    movq line_start(%rip), %rdi
    movq %rdi, cur(%rip)
    call skip_space
    movq cur(%rip), %rdi
    cmpq line_end(%rip), %rdi
    jae .next_line
    cmpb $35, (%rdi)               # # comment
    je .next_line
    leaq kw_out(%rip), %rsi
    call has_word
    testq %rax, %rax
    jnz .do_out
    movq cur(%rip), %rdi
    leaq kw_var(%rip), %rsi
    call has_word
    testq %rax, %rax
    jnz .do_var
    movq cur(%rip), %rdi
    leaq kw_run(%rip), %rsi
    call has_word
    testq %rax, %rax
    jnz .next_line               # run is optional metadata for now
    jmp .do_assign

.do_out:
    addq $3, cur(%rip)
    call skip_space
    movq cur(%rip), %rsi
    cmpb $34, (%rsi)
    jne .out_variable
    incq %rsi
    movq %rsi, var_ptr(%rip)
    movq %rsi, %rdi
.out_string_scan:
    cmpq line_end(%rip), %rsi
    jae .syntax_error
    cmpb $34, (%rsi)
    je .out_string_emit
    incq %rsi
    jmp .out_string_scan
.out_string_emit:
    movq %rsi, %rdx
    subq %rdi, %rdx
    movq var_ptr(%rip), %rsi
    movq $1, %rax
    movq $1, %rdi
    syscall
    call emit_nl
    jmp .next_line
.out_variable:
    call read_name
    call find_var
    testq %rax, %rax
    jz .syntax_error
    movq 32(%rax), %rdi
    call print_integer
    jmp .next_line

.do_var:
    addq $3, cur(%rip)
    call skip_space
    call read_name
    cmpq $0, name_len(%rip)
    je .syntax_error
    # Optional type annotation, e.g. :num
    call skip_space
    movq cur(%rip), %rsi
    cmpb $58, (%rsi)
    jne .var_expect_eq
.skip_type:
    cmpq line_end(%rip), %rsi
    jae .syntax_error
    cmpb $61, (%rsi)
    je .var_at_eq
    incq %rsi
    jmp .skip_type
.var_at_eq:
    movq %rsi, cur(%rip)
.var_expect_eq:
    call skip_space
    movq cur(%rip), %rsi
    cmpb $61, (%rsi)
    jne .syntax_error
    incq %rsi
    movq %rsi, cur(%rip)
    call parse_integer
    movq %rax, val(%rip)
    call find_var
    testq %rax, %rax
    jnz .var_store
    call new_var
    testq %rax, %rax
    jz .syntax_error
.var_store:
    movq val(%rip), %rdx
    movq %rdx, 32(%rax)
    jmp .next_line

.do_assign:
    call read_name
    cmpq $0, name_len(%rip)
    je .syntax_error
    call find_var
    testq %rax, %rax
    jz .syntax_error
    movq %rax, var_ptr(%rip)
    call skip_space
    movq cur(%rip), %rsi
    movq $0, op_kind(%rip)
    cmpb $43, (%rsi)
    je .assign_plus
    cmpb $45, (%rsi)
    je .assign_minus
    cmpb $42, (%rsi)
    je .assign_times
    cmpb $47, (%rsi)
    je .assign_div
    cmpb $61, (%rsi)
    jne .syntax_error
    incq %rsi
    jmp .assign_parse
.assign_plus:
    movq $1, op_kind(%rip)
    incq %rsi
    jmp .assign_eq
.assign_minus:
    movq $2, op_kind(%rip)
    incq %rsi
    jmp .assign_eq
.assign_times:
    movq $3, op_kind(%rip)
    incq %rsi
    jmp .assign_eq
.assign_div:
    movq $4, op_kind(%rip)
    incq %rsi
.assign_eq:
    cmpb $61, (%rsi)
    jne .syntax_error
    incq %rsi
.assign_parse:
    movq %rsi, cur(%rip)
    call parse_integer
    movq %rax, val(%rip)
    movq var_ptr(%rip), %rdi
    movq 32(%rdi), %rax
    movq val(%rip), %rdx
    cmpq $1, op_kind(%rip)
    je .plus_op
    cmpq $2, op_kind(%rip)
    je .minus_op
    cmpq $3, op_kind(%rip)
    je .times_op
    cmpq $4, op_kind(%rip)
    je .divide_op
    movq %rdx, %rax
    jmp .store_assign
.plus_op:
    addq %rdx, %rax
    jmp .store_assign
.minus_op:
    subq %rdx, %rax
    jmp .store_assign
.times_op:
    imulq %rdx, %rax
    jmp .store_assign
.divide_op:
    testq %rdx, %rdx
    jz .syntax_error
    cqo
    idivq %rdx
.store_assign:
    movq %rax, 32(%rdi)
    jmp .next_line

# skip spaces/tabs at cur
skip_space:
    movq cur(%rip), %rsi
.skip_loop:
    cmpq line_end(%rip), %rsi
    jae .skip_done
    cmpb $32, (%rsi)
    je .skip_one
    cmpb $9, (%rsi)
    jne .skip_done
.skip_one:
    incq %rsi
    jmp .skip_loop
.skip_done:
    movq %rsi, cur(%rip)
    ret

# has_word(rdi=source, rsi=keyword) -> rax=1 iff exact command word
has_word:
    pushq %rbx
    movq %rdi, %rbx
.hw_loop:
    movb (%rsi), %al
    testb %al, %al
    jz .hw_end
    cmpb (%rbx), %al
    jne .hw_no
    incq %rbx
    incq %rsi
    jmp .hw_loop
.hw_end:
    cmpq line_end(%rip), %rbx
    jae .hw_yes
    cmpb $32, (%rbx)
    je .hw_yes
    cmpb $9, (%rbx)
    je .hw_yes
    jmp .hw_no
.hw_yes:
    movq $1, %rax
    popq %rbx
    ret
.hw_no:
    xorq %rax, %rax
    popq %rbx
    ret

# read identifier at cur to namebuf, updates cur/name_len
read_name:
    leaq namebuf(%rip), %rdi
    movq cur(%rip), %rsi
    xorq %rcx, %rcx
.rn_loop:
    cmpq line_end(%rip), %rsi
    jae .rn_end
    movb (%rsi), %al
    cmpb $95, %al
    je .rn_copy
    cmpb $48, %al
    jb .rn_alpha
    cmpb $57, %al
    jbe .rn_copy
.rn_alpha:
    cmpb $65, %al
    jb .rn_lower
    cmpb $90, %al
    jbe .rn_copy
.rn_lower:
    cmpb $97, %al
    jb .rn_end
    cmpb $122, %al
    ja .rn_end
.rn_copy:
    cmpq $63, %rcx
    jae .rn_end
    movb %al, (%rdi,%rcx)
    incq %rcx
    incq %rsi
    jmp .rn_loop
.rn_end:
    movb $0, (%rdi,%rcx)
    movq %rcx, name_len(%rip)
    movq %rsi, cur(%rip)
    ret

# find exact variable name, returns pointer or null
find_var:
    leaq vars(%rip), %r8
    movq $64, %r9
.fv_loop:
    cmpb $0, (%r8)
    je .fv_next
    leaq namebuf(%rip), %rsi
    movq %r8, %rdi
    movq name_len(%rip), %rcx
    movq %rcx, %rdx
    repe cmpsb
    jne .fv_next
    cmpb $0, (%r8,%rdx)
    je .fv_yes
.fv_next:
    addq $40, %r8
    decq %r9
    jnz .fv_loop
    xorq %rax, %rax
    ret
.fv_yes:
    movq %r8, %rax
    ret

# allocate new variable (name in namebuf)
new_var:
    leaq vars(%rip), %r8
    movq $64, %r9
.nv_loop:
    cmpb $0, (%r8)
    je .nv_found
    addq $40, %r8
    decq %r9
    jnz .nv_loop
    xorq %rax, %rax
    ret
.nv_found:
    leaq namebuf(%rip), %rsi
    movq %r8, %rdi
    movq name_len(%rip), %rcx
    rep movsb
    movb $0, (%rdi)
    movq %r8, %rax
    ret

# parse signed decimal integer at cur, return rax
parse_integer:
    call skip_space
    movq cur(%rip), %rsi
    xorq %rax, %rax
    xorq %r8, %r8
    cmpb $45, (%rsi)
    jne .pi_digits
    movq $1, %r8
    incq %rsi
.pi_digits:
    cmpq line_end(%rip), %rsi
    jae .pi_done
    movzbq (%rsi), %rdx
    cmpq $48, %rdx
    jb .pi_done
    cmpq $57, %rdx
    ja .pi_done
    imulq $10, %rax, %rax
    subq $48, %rdx
    addq %rdx, %rax
    incq %rsi
    jmp .pi_digits
.pi_done:
    movq %rsi, cur(%rip)
    testq %r8, %r8
    jz .pi_ret
    negq %rax
.pi_ret:
    ret

# Write signed integer in rdi, followed by LF
print_integer:
    leaq num_buf+31(%rip), %rsi
    movb $10, (%rsi)
    movq %rdi, %rax
    xorq %r8, %r8
    testq %rax, %rax
    jns .fmt_abs
    movq $1, %r8
    negq %rax
.fmt_abs:
    movq $10, %r9
.fmt_loop:
    xorq %rdx, %rdx
    divq %r9
    addb $48, %dl
    decq %rsi
    movb %dl, (%rsi)
    testq %rax, %rax
    jnz .fmt_loop
    testq %r8, %r8
    jz .fmt_write
    decq %rsi
    movb $45, (%rsi)
.fmt_write:
    leaq num_buf+32(%rip), %rdx
    subq %rsi, %rdx
    movq $1, %rax
    movq $1, %rdi
    syscall
    ret
emit_nl:
    movq $1, %rax
    movq $1, %rdi
    leaq newline(%rip), %rsi
    movq $1, %rdx
    syscall
    ret
.usage:
    leaq usage(%rip), %rsi
    movq $usage_len, %rdx
    jmp .write_stderr_exit
.open_error:
    leaq err_open(%rip), %rsi
    movq $err_open_len, %rdx
    jmp .write_stderr_exit
.read_error:
    leaq err_open(%rip), %rsi
    movq $err_open_len, %rdx
    jmp .write_stderr_exit
.syntax_error:
    leaq err_syntax(%rip), %rsi
    movq $err_syntax_len, %rdx
.write_stderr_exit:
    movq $1, %rax
    movq $2, %rdi
    syscall
    movq $60, %rax
    movq $1, %rdi
    syscall
.success:
    movq $60, %rax
    xorq %rdi, %rdi
    syscall
