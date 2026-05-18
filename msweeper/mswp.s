## global variable

    .equ BOARD_SIZE, 8
    .equ MINE_COUNT, 10

## sys call No.
    .equ SYS_READ,   0
    .equ SYS_WRITE,  1
    .equ SYS_EXIT,   60
    .equ STDOUT,     1
    .equ STDIN,      0

## .data  ─ string literals
    .section .data
msg_title:   .string "=== M Sweeper ===\n"
msg_header:  .string "  0 1 2 3 4 5 6 7\n"
msg_input:   .string "Open (row col) > "
msg_gameover:.string "*** GAME OVER ***\n"
msg_clear:   .string "*** GAME CLEAR ***\n"
msg_already: .string "Already opened. Try again.\n"
msg_invalid: .string "Invalid input. Try again.\n"
msg_newline: .string "\n"
msg_sep:     .string "| "
msg_space:   .string " "
msg_dot:     .string "."

## .bss  ─ uninit data
    .section .bss
board:      .skip 64       ## 1=unsafe, 0=safe
visible:    .skip 64       ## 1=opened, 0=unopened
input_buf:  .skip 16       ## buffer for read()
char_buf:   .skip 4        ## buffer for char

## .text  ─ code
    .section .text
    .global _start

## strlen: rsi → rax
## rsi(string pointer) to rax(string length)
strlen:
    xorq %rax, %rax
.strlen_loop:
    cmpb $0, (%rsi,%rax)
    je   .strlen_done
    incq %rax
    jmp  .strlen_loop
.strlen_done:
    ret

## print_str: call with string pointer set in "rsi"
## clobbers: rax, rdi, rdx
print_str:
    call  strlen           ## rax = len
    movq  %rax, %rdx
    movq  $SYS_WRITE, %rax
    movq  $STDOUT, %rdi
    syscall
    ret

## print_char: call with character set in "al"
print_char:
    movb  %al, char_buf(%rip)
    movq  $SYS_WRITE, %rax
    movq  $STDOUT, %rdi
    leaq  char_buf(%rip), %rsi
    movq  $1, %rdx
    syscall
    ret

## print_digit: call with 0~9 set in "rax"
print_digit:
    addb  $'0', %al
    call  print_char
    ret

## init_board: clear board and visible
init_board:
    pushq %rdi
    pushq %rcx
    leaq  board(%rip), %rdi
    movq  $64, %rcx
.ib_loop1:
    movb  $0, (%rdi)
    incq  %rdi
    loop  .ib_loop1
    leaq  visible(%rip), %rdi
    movq  $64, %rcx
.ib_loop2:
    movb  $0, (%rdi)
    incq  %rdi
    loop  .ib_loop2
    popq  %rcx
    popq  %rdi
    ret

## place_mines: place MINE_COUNT mines randomly
## pseudo random number: use lower bits of rdtsc
place_mines:
    pushq %rbx
    pushq %r12
    pushq %r13
    xorq  %r12, %r12
.pm_next:
    cmpq  $MINE_COUNT, %r12
    jge   .pm_done
    rdtsc
    andl  $63, %eax
    movl  %eax, %ebx
    leaq  board(%rip), %r9
    cmpb  $1, (%r9,%rbx)
    je    .pm_next
    movb  $1, (%r9,%rbx)
    incq  %r12
    movq  $255, %r13
.pm_spin:
    decq  %r13
    jnz   .pm_spin
    jmp   .pm_next
.pm_done:
    popq  %r13
    popq  %r12
    popq  %rbx
    ret

## count_mines: number of surrounding mines
count_mines:
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    movq  %rdi, %r12           ## row
    movq  %rsi, %r13           ## col
    xorq  %r14, %r14           ## count = 0
    movq  $-1, %r15            ## dr = -1
.cm_dr:
    cmpq  $1, %r15
    jg    .cm_done
    movq  $-1, %rbx            ## dc = -1
.cm_dc:
    cmpq  $1, %rbx
    jg    .cm_dr_next
    testq %r15, %r15
    jnz   .cm_not_center
    testq %rbx, %rbx
    jz    .cm_dc_next
.cm_not_center:
    movq  %r12, %rax
    addq  %r15, %rax           ## nr = row + dr
    js    .cm_dc_next
    cmpq  $BOARD_SIZE, %rax
    jge   .cm_dc_next
    movq  %r13, %rcx
    addq  %rbx, %rcx           ## nc = col + dc
    js    .cm_dc_next
    cmpq  $BOARD_SIZE, %rcx
    jge   .cm_dc_next
    ## index = nr*8 + nc
    imulq $BOARD_SIZE, %rax
    addq  %rcx, %rax
    leaq board(%rip),%r9
    cmpb  $1, (%r9,%rax)
    jne   .cm_dc_next
    incq  %r14
.cm_dc_next:
    incq  %rbx
    jmp   .cm_dc
.cm_dr_next:
    incq  %r15
    jmp   .cm_dr
.cm_done:
    movq  %r14, %rax
    popq  %r15
    popq  %r14
    popq  %r13
    popq  %r12
    popq  %rbx
    ret

## open_cell: rdi=row, rsi=col → rax
## 0: safe  1: unsafe  2: except
open_cell:
    pushq %rbx
    pushq %r12
    pushq %r13
    movq  %rdi, %r12
    movq  %rsi, %r13

    ## bounds check
    cmpq  $0, %r12
    jl    .oc_already
    cmpq  $BOARD_SIZE, %r12
    jge   .oc_already
    cmpq  $0, %r13
    jl    .oc_already
    cmpq  $BOARD_SIZE, %r13
    jge   .oc_already
    ## index = row*8 + col
    movq  %r12, %rbx
    imulq $BOARD_SIZE, %rbx
    addq  %r13, %rbx

    ## opened check
    leaq visible(%rip),%r10
    cmpb  $1, (%r10,%rbx)
    je    .oc_already

    ## mine check
    leaq board(%rip),%r9
    cmpb  $1, (%r9,%rbx)
    je    .oc_mine

    ## safe -> reveal
    leaq visible(%rip),%r10
    movb  $1, (%r10,%rbx)
    xorq  %rax, %rax
    jmp   .oc_done
.oc_mine:
    movq  $1, %rax
    jmp   .oc_done
.oc_already:
    movq  $2, %rax
.oc_done:
    popq  %r13
    popq  %r12
    popq  %rbx
    ret

## check_clear → rax  (1: clear  0: not clear)
check_clear:
    pushq %rbx
    xorq  %rbx, %rbx
.cc_loop:
    cmpq  $64, %rbx
    jge   .cc_yes
    leaq board(%rip),%r9
    cmpb  $1, (%r9,%rbx)
    je    .cc_skip           ## not include mine
    leaq visible(%rip),%r10
    cmpb  $1, (%r10,%rbx)
    jne   .cc_no             ## not opened safe
.cc_skip:
    incq  %rbx
    jmp   .cc_loop
.cc_yes:
    movq  $1, %rax
    jmp   .cc_ret
.cc_no:
    xorq  %rax, %rax
.cc_ret:
    popq  %rbx
    ret

## print_row_num: call with row number set in rax
print_row_num:
    call  print_digit
    leaq  msg_sep(%rip), %rsi
    call  print_str
    ret

## print_cell: r12=row, r13=col, rbx=index
print_cell:
    leaq visible(%rip),%r10
    cmpb  $1, (%r10,%rbx)
    jne   .pc_hidden
    movq  %r12, %rdi
    movq  %r13, %rsi
    call  count_mines
    call  print_digit
    jmp   .pc_done
.pc_hidden:
    leaq  msg_dot(%rip), %rsi
    call  print_str
.pc_done:
    ret

## print_board: display the entire board
print_board:
    pushq %rbx
    pushq %r12
    pushq %r13
    leaq  msg_header(%rip), %rsi
    call  print_str
    xorq  %r12, %r12           ## row = 0
.pb_row:
    cmpq  $BOARD_SIZE, %r12
    jge   .pb_done
    movq  %r12, %rax
    call  print_row_num
    xorq  %r13, %r13           ## col = 0
.pb_col:
    cmpq  $BOARD_SIZE, %r13
    jge   .pb_eol
    movq  %r12, %rbx
    imulq $BOARD_SIZE, %rbx
    addq  %r13, %rbx
    call  print_cell
    ## space except for the last column
    cmpq  $7, %r13
    je    .pb_no_sp
    leaq  msg_space(%rip), %rsi
    call  print_str
.pb_no_sp:
    incq  %r13
    jmp   .pb_col
.pb_eol:
    leaq  msg_newline(%rip), %rsi
    call  print_str
    incq  %r12
    jmp   .pb_row
.pb_done:
    popq  %r13
    popq  %r12
    popq  %rbx
    ret

## read_input → rax(row), rbx(col)
## if failed rax = -1
read_input:
    pushq %rcx
    ## read from stdin
    movq  $SYS_READ, %rax
    movq  $STDIN, %rdi
    leaq  input_buf(%rip), %rsi
    movq  $15, %rdx
    syscall
    cmpq  $3, %rax
    jl    .ri_fail
    ## 1st char = row
    movzbl input_buf(%rip), %ecx
    subl  $'0', %ecx
    cmpq  $0, %rcx
    jl    .ri_fail
    cmpq  $7, %rcx
    jg    .ri_fail
    movq  %rcx, %rax
    ## skip 2nd char and looking for col
    leaq  input_buf+1(%rip), %rcx
.ri_skip:
    cmpb  $' ', (%rcx)
    jne   .ri_parse_col
    incq  %rcx
    jmp   .ri_skip
.ri_parse_col:
    movzbl (%rcx), %ecx
    subl  $'0', %ecx
    cmpq  $0, %rcx
    jl    .ri_fail
    cmpq  $7, %rcx
    jg    .ri_fail
    movq  %rcx, %rbx
    jmp   .ri_done
.ri_fail:
    movq  $-1, %rax
.ri_done:
    popq  %rcx
    ret

## game_loop: main loop
game_loop:
    pushq %rbx
    pushq %r12
    pushq %r13
.gl_loop:
    call  print_board
    leaq  msg_input(%rip), %rsi
    call  print_str
    call  read_input
    cmpq  $-1, %rax
    je    .gl_invalid
    movq  %rax, %r12           ## row
    movq  %rbx, %r13           ## col
    movq  %r12, %rdi
    movq  %r13, %rsi
    call  open_cell
    cmpq  $1, %rax
    je    .gl_gameover
    cmpq  $2, %rax
    je    .gl_already
    call  check_clear
    cmpq  $1, %rax
    je    .gl_clear
    jmp   .gl_loop
.gl_invalid:
    leaq  msg_invalid(%rip), %rsi
    call  print_str
    jmp   .gl_loop
.gl_already:
    leaq  msg_already(%rip), %rsi
    call  print_str
    jmp   .gl_loop
.gl_gameover:
    call  print_board
    leaq  msg_gameover(%rip), %rsi
    call  print_str
    jmp   .gl_ret
.gl_clear:
    call  print_board
    leaq  msg_clear(%rip), %rsi
    call  print_str
.gl_ret:
    popq  %r13
    popq  %r12
    popq  %rbx
    ret

## _start: entry
_start:
    leaq  msg_title(%rip), %rsi
    call  print_str
    call  init_board
    call  place_mines
    call  game_loop
    ## exit(0)
    movq  $SYS_EXIT, %rax
    xorq  %rdi, %rdi
    syscall
