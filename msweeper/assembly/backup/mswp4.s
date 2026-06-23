

    .equ SYS_READ,   0
    .equ SYS_WRITE,  1
    .equ SYS_EXIT,   60
    .equ STDOUT,     1
    .equ STDIN,      0

    .section .data
msg_board:   .string "Board size (Max 36 Min 2): "
msg_mines:   .string "Mine count : "
msg_title:   .string "=== M Sweeper ===\n"
msg_input:   .string "Open (x y) : "
msg_gameover:.string "*** GAME OVER ***\n"
msg_clear:   .string "*** GAME CLEAR ***\n"
msg_already: .string "Already opened. Try again.\n"
msg_invalid: .string "Invalid input. Try again.\n"
msg_newline: .string "\n"
msg_space:   .string " "
msg_dot:     .string "."

    .section .bss
board:       .skip 1500     ## 1=unsafe, 0=safe
visible:     .skip 1500     ## 1=opened, 0=unopened
input_buf:   .skip 16       ## buffer for read()
num_buf:     .skip 16       ## buffer for read()
char_buf:    .skip 4        ## buffer for char
board_size:  .quad 0
mine_count:  .quad 0
fcl_done:    .quad 0        ## 0=first  1=done
opcell_stack: .skip 12000
randflag:    .quad 0

    .section .text
    .global _start

## rsi → rax
strlen:
    xorq %rax, %rax
.strlen_loop:
    cmpb $0, (%rsi,%rax)
    je   .strlen_done
    incq %rax
    jmp  .strlen_loop
.strlen_done:
    ret

## call with string pointer set in "rsi"
## clobbers: rax, rdi, rdx
print_str:
    call  strlen
    movq  %rax, %rdx
    movq  $SYS_WRITE, %rax
    movq  $STDOUT, %rdi
    syscall
    ret

print_header:
    pushq %rbx
    pushq %r12

    movb  $' ', %al
    call  print_char
    movb  $' ', %al
    call  print_char

    xorq  %r12, %r12

.ph_loop:
    ## if x >= board_size -> end
    movq  board_size(%rip), %rbx
    cmpq  %rbx, %r12
    jge   .ph_done

    ## print digit
    movq  %r12, %rax
    call  print_number

    ## space if not end
    movq  board_size(%rip), %rbx
    decq  %rbx
    cmpq  %rbx, %r12
    je    .ph_next

    movb  $' ', %al
    call  print_char

.ph_next:
    incq  %r12
    jmp   .ph_loop

.ph_done:
    movb  $'\n', %al
    call  print_char

    popq  %r12
    popq  %rbx
    ret

## call with character set in "al"
print_char:
    movb  %al, char_buf(%rip)
    movq  $SYS_WRITE, %rax
    movq  $STDOUT, %rdi
    leaq  char_buf(%rip), %rsi
    movq  $1, %rdx
    syscall
    ret

## input: rax
print_number:
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rsi

    leaq num_buf(%rip), %rsi
    addq $15, %rsi
    movb $0, (%rsi)
    movq $36, %rbx

    testq %rax, %rax
    jnz .pn_loop

    movb $'0', %al
    call print_char
    jmp .pn_done

.pn_loop:
    xorq %rdx, %rdx
    divq %rbx

    cmpb $9, %dl
    jle .pn_digit

    addb $('A' - 10), %dl
    jmp .pn_store

.pn_digit:
    addb $'0', %dl

.pn_store:
    decq %rsi
    movb %dl, (%rsi)

    testq %rax, %rax
    jnz .pn_loop

    call print_str

    popq %rsi
    popq %rdx
    popq %rcx
    popq %rbx
    ret

.pn_done:
    popq %rsi
    popq %rdx
    popq %rcx
    popq %rbx
    ret

rand:
    movq  randflag(%rip), %rax
    testq %rax, %rax
    jnz   .r_ok
    rdtsc
    shlq  $32, %rdx
    orq   %rdx, %rax
    testq %rax, %rax
    jnz   .r_seed
    movq  $0x123456789ABCDEF, %rax
.r_seed:
    movq  %rax, randflag(%rip)
.r_ok:
    movq  %rax, %rcx
    shlq  $13, %rcx
    xorq  %rcx, %rax
    movq  %rax, %rcx
    shrq  $7, %rcx
    xorq  %rcx, %rax
    movq  %rax, %rcx
    shlq  $17, %rcx
    xorq  %rcx, %rax
    movq  %rax, randflag(%rip)
    ret

## clear board and visible
init_board:
    pushq %rdi
    pushq %rcx
    leaq  board(%rip), %rdi
    movq  board_size(%rip), %rcx
    imulq %rcx, %rcx
.ib_loop1:
    movb  $0, (%rdi)
    incq  %rdi
    loop  .ib_loop1
    leaq  visible(%rip), %rdi
    movq  board_size(%rip), %rcx
    imulq %rcx, %rcx
.ib_loop2:
    movb  $0, (%rdi)
    incq  %rdi
    loop  .ib_loop2
    popq  %rcx
    popq  %rdi
    ret



## place MINE_COUNT mines randomly
## use lower bits of rdtsc
place_mines:
    pushq  %rbx
    pushq  %r12
    pushq  %r13
    pushq  %r14
    pushq  %r15
    movq   board_size(%rip), %r14
    imulq  %r14, %r14
    xorq   %r12, %r12
.pm_next:
    movq  mine_count(%rip), %rax
    cmpq  %rax, %r12
    jge   .pm_done

    call  rand
    xorq  %rdx, %rdx
    divq  %r14
    movq  %rdx, %r13
    movq  %r13, %r15
.pm_scan:
    leaq  board(%rip), %r9
    cmpb  $1, (%r9,%r13)
    je    .pm_scanext

    movb  $1, (%r9,%r13)
    incq  %r12
    jmp   .pm_next
.pm_scanext:
    incq  %r13
    cmpq  %r14, %r13
    jl    .pm_scwrap
    xorq  %r13, %r13
.pm_scwrap:
    cmpq  %r15, %r13
    je    .pm_done
    jmp   .pm_scan
.pm_done:
    popq  %r15
    popq  %r14
    popq  %r13
    popq  %r12
    popq  %rbx
    ret

## rdi=y, rsi=x
## move mine if first click cell is mine
first_click:
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    pushq %rbx

    movq  %rdi, %r12
    movq  %rsi, %r13
    movq  board_size(%rip), %rax
    imulq %rax, %r12
    addq  %r13, %r12

    ## nothing to do if its not mine
    leaq  board(%rip), %r9
    cmpb  $1, (%r9,%r12)
    jne   .fc_done
    ## remove mine
    movb  $0, (%r9,%r12)
    ## decide cell with rdtsc and start scan
    movq  board_size(%rip), %r14
    imulq %r14, %r14

    call  rand
    xorq  %rdx, %rdx
    divq  %r14
    movq  %rdx, %r13
    movq  %r13, %r15
.fc_scan:
    ## skip if its same cell
    cmpq  %r12, %r13
    je    .fc_scanext
    ## skip if it already is mine
    leaq  board(%rip), %r9
    cmpb  $1, (%r9,%r13)
    je    .fc_scanext
    movb  $1, (%r9,%r13)
    jmp   .fc_done
.fc_scanext:
    incq  %r13
    cmpq  %r14, %r13
    jl    .fc_scwrap
    xorq  %r13, %r13
.fc_scwrap:
    cmpq  %r15, %r13
    je    .fc_done
    jmp   .fc_scan
.fc_done:
    movq  $1, fcl_done(%rip)
    popq  %rbx
    popq  %r15
    popq  %r14
    popq  %r13
    popq  %r12
    ret

## number of surrounding mines
count_mines:
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    pushq %r8
    movq  %rdi, %r12            ## y
    movq  %rsi, %r13            ## x
    xorq  %r14, %r14            ## count = 0
    movq  board_size(%rip), %r8
    movq  $-1, %r15
.cm_dr:
    cmpq  $1, %r15
    jg    .cm_done
    movq  $-1, %rbx
.cm_dc:
    cmpq  $1, %rbx
    jg    .cm_drnext
    testq %r15, %r15
    jnz   .cm_around
    testq %rbx, %rbx
    jz    .cm_dcnext
.cm_around:
    movq  %r12, %rax
    addq  %r15, %rax
    js    .cm_dcnext
    cmpq  %r8, %rax
    jge   .cm_dcnext
    movq  %r13, %rcx
    addq  %rbx, %rcx
    js    .cm_dcnext
    cmpq  %r8, %rcx
    jge   .cm_dcnext
    ## index = nr*board_size + nc
    imulq %r8, %rax
    addq  %rcx, %rax
    leaq board(%rip),%r9
    cmpb  $1, (%r9,%rax)
    jne   .cm_dcnext
    incq  %r14
.cm_dcnext:
    incq  %rbx
    jmp   .cm_dc
.cm_drnext:
    incq  %r15
    jmp   .cm_dr
.cm_done:
    movq  %r14, %rax
    popq  %r8
    popq  %r15
    popq  %r14
    popq  %r13
    popq  %r12
    popq  %rbx
    ret

## rdi=y, rsi=x → rax
## 0: safe  1: unsafe  2: except
open_cell:
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    movq  %rdi, %r12
    movq  %rsi, %r13
    movq  board_size(%rip), %r14

    ## bounds check
    cmpq  $0, %r12
    jl    .oc_already
    cmpq  %r14, %r12
    jge   .oc_already
    cmpq  $0, %r13
    jl    .oc_already
    cmpq  %r14, %r13
    jge   .oc_already
    ## index = y*8 + x
    movq  %r12, %rbx
    imulq %r14, %rbx
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
    popq  %r14
    popq  %r13
    popq  %r12
    popq  %rbx
    ret

## rdi=y, rsi=x → rax
## 0: safe  1: mine  2: already
## if the cell's adjacent is 0, open it with repeat DFS
open_cell_start:
    pushq %rbx
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15
    pushq %rbp

    call  open_cell
    cmpq  $0, %rax
    jne   .ocs_ret

    ## reset DFS stack (elements is managed by rbp)
    ## stack y*size+x to opcell_stack
    xorq  %rbp, %rbp
    movq  board_size(%rip), %rax
    imulq %rdi, %rax
    addq  %rsi, %rax
    leaq  opcell_stack(%rip), %r15
    movq  %rax, (%r15,%rbp,8)
    incq  %rbp

.ocs_loop:
    testq %rbp, %rbp
    jz    .ocs_done
    ## pop index
    decq  %rbp
    movq  (%r15,%rbp,8), %r12

    movq  board_size(%rip), %rbx
    movq  %r12, %rax
    xorq  %rdx, %rdx
    divq  %rbx
    movq  %rax, %r13
    movq  %rdx, %r14
    ## check cell's adjacent
    movq  %r13, %rdi
    movq  %r14, %rsi
    call  count_mines
    testq %rax, %rax
    jnz   .ocs_loop

    movq  $-1, %r8
.ocs_dr:
    cmpq  $1, %r8
    jg    .ocs_loop

    movq  $-1, %r9
.ocs_dc:
    cmpq  $1, %r9
    jg    .ocs_drnext

    ## center skip
    testq %r8, %r8
    jnz   .ocs_around
    testq %r9, %r9
    jz    .ocs_dcnext
.ocs_around:
    ## nr = r13 + dr
    movq  %r13, %rax
    addq  %r8, %rax
    js    .ocs_dcnext
    movq  board_size(%rip), %rbx
    cmpq  %rbx, %rax
    jge   .ocs_dcnext

    movq  %r14, %rcx
    addq  %r9, %rcx
    js    .ocs_dcnext
    cmpq  %rbx, %rcx
    jge   .ocs_dcnext
    ## skip if it already is opened
    imulq %rbx, %rax
    addq  %rcx, %rax
    leaq  visible(%rip), %r10
    cmpb  $1, (%r10,%rax)
    je    .ocs_dcnext
    ## skip if its mine
    leaq  board(%rip), %r11
    cmpb  $1, (%r11,%rax)
    je    .ocs_dcnext

    movb  $1, (%r10,%rax)
    movq  %rax, (%r15,%rbp,8)
    incq  %rbp

.ocs_dcnext:
    incq  %r9
    jmp   .ocs_dc
.ocs_drnext:
    incq  %r8
    jmp   .ocs_dr

.ocs_done:
    xorq  %rax, %rax
    ## return 0
.ocs_ret:
    popq  %rbp
    popq  %r15
    popq  %r14
    popq  %r13
    popq  %r12
    popq  %rbx
    ret

## check_clear → rax  (1: clear  0: not clear)
check_clear:
    pushq %rbx
    pushq %r12
    ## r12 = board_size * board_size
    movq  board_size(%rip), %r12
    imulq %r12, %r12
    xorq  %rbx, %rbx
.cc_loop:
    cmpq  %r12, %rbx
    jge   .cc_yes
    leaq  board(%rip),%r9
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
    popq  %r12
    popq  %rbx
    ret

## call with y number set in rax
print_ynum:
    call  print_number
    leaq  msg_space(%rip), %rsi
    call  print_str
    ret

## r12=y, r13=x, rbx=index
print_cell:
    leaq  visible(%rip),%r10
    cmpb  $1, (%r10,%rbx)
    jne   .pc_hidden
    movq  %r12, %rdi
    movq  %r13, %rsi
    call  count_mines
    testq %rax, %rax
    ## blank if cell's adjacent is 0

    jz    .pc_zero
    call  print_number
    jmp   .pc_done
.pc_zero:
    movb  $' ', %al
    call  print_char
    jmp   .pc_done
.pc_hidden:
    leaq  msg_dot(%rip), %rsi
    call  print_str
.pc_done:
    ret

## display the entire board
print_board:
    pushq %rbx
    pushq %r12
    pushq %r13
    call  print_header
    xorq  %r12, %r12
.pb_y:
    movq  board_size(%rip), %rax
    cmpq  %rax, %r12
    jge   .pb_done
    movq  %r12, %rax
    call  print_ynum
    xorq  %r13, %r13
.pb_x:
    movq  board_size(%rip), %rax
    cmpq  %rax, %r13
    jge   .pb_eol
    movq  %r12, %rbx
    movq board_size(%rip), %rax
    imulq %rax, %rbx
    addq  %r13, %rbx
    call  print_cell
    ## space except for the last x
    movq board_size(%rip), %rax
    decq %rax
    cmpq %rax, %r13
    je    .pb_nosp
    leaq  msg_space(%rip), %rsi
    call  print_str
.pb_nosp:
    incq  %r13
    jmp   .pb_x
.pb_eol:
    leaq  msg_newline(%rip), %rsi
    call  print_str
    incq  %r12
    jmp   .pb_y
.pb_done:
    popq  %r13
    popq  %r12
    popq  %rbx
    ret

## rax(xmax-x), rbx(ymax-y)
## failed -> rax=-1

read_input:
    pushq %rcx

    ## read
    movq  $SYS_READ, %rax
    movq  $STDIN, %rdi
    leaq  input_buf(%rip), %rsi
    movq  $15, %rdx
    syscall

    cmpq  $3, %rax
    jl    .ri_fail

    ## y
    movzbq input_buf(%rip), %rax
    call   char_base36
    cmpq   $-1, %rax
    je     .ri_fail

    movq   %rax, %rbx

    ## x
    movzbq input_buf+1(%rip), %rax
    call   char_base36
    cmpq   $-1, %rax
    je     .ri_fail

    ## range check
    movq  board_size(%rip), %rcx

    cmpq  %rcx, %rax
    jge   .ri_fail

    cmpq  %rcx, %rbx
    jge   .ri_fail

    popq  %rcx
    ret

.ri_fail:
    movq $-1, %rax
    popq %rcx
    ret

## input: al
## output: rax
## failed: -1

char_base36:
    ## '0'-'9'
    cmpb $'0', %al
    jl .ctb_upper
    cmpb $'9', %al
    jg .ctb_upper

    movzbq %al, %rax
    subq $'0', %rax
    ret

.ctb_upper:
    cmpb $'A', %al
    jl .ctb_lower
    cmpb $'Z', %al
    jg .ctb_lower

    movzbq %al, %rax
    subq $('A' - 10), %rax
    ret

.ctb_lower:
    cmpb $'a', %al
    jl .ctb_fail
    cmpb $'z', %al
    jg .ctb_fail

    movzbq %al, %rax
    subq $('a' - 10), %rax
    ret

.ctb_fail:
    movq $-1, %rax
    ret

## failed: rax = -1
read_number:
    pushq %rbx
    pushq %rcx
    pushq %rdx

    ## read(stdin, input_buf, 15)
    movq  $SYS_READ, %rax
    movq  $STDIN, %rdi
    leaq  input_buf(%rip), %rsi
    movq  $15, %rdx
    syscall

    cmpq  $1, %rax
    jle   .rn_fail

    xorq  %rax, %rax
    leaq  input_buf(%rip), %rbx

.rn_loop:
    movzbq (%rbx), %rcx

    ## newline?
    cmpb  $'\n', %cl
    je    .rn_done

    ## not digit?
    cmpb  $'0', %cl
    jl    .rn_fail

    cmpb  $'9', %cl
    jg    .rn_fail

    ## result *= 10
    imulq $10, %rax

    ## result += digit
    subb  $'0', %cl
    addq  %rcx, %rax

    incq  %rbx
    jmp   .rn_loop

.rn_fail:
    movq  $-1, %rax

.rn_done:
    popq  %rdx
    popq  %rcx
    popq  %rbx
    ret

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
    movq  %rax, %r12
    movq  %rbx, %r13
    movq  %r12, %rdi
    movq  %r13, %rsi
    call  open_cell_start

    cmpq  $0, fcl_done(%rip)
    jne   .gl_skip
    cmpq  $1, %rax
    jne   .gl_skip

    movq  %r12, %rdi
    movq  %r13, %rsi
    call  first_click
    movq  %r12, %rdi
    movq  %r13, %rsi
    call  open_cell_start
    jmp   .gl_check

.gl_skip:
    movq  $1, fcl_done(%rip)

.gl_check:
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

setup_game:

.sg_inputboard:
    ## print prompt
    leaq  msg_board(%rip), %rsi
    call  print_str

    ## read number
    call  read_number

    ## failed?
    cmpq  $2, %rax
    jl    .sg_invboard

    cmpq  $36, %rax
    jg    .sg_invboard

    ## save board_size
    movq  %rax, board_size(%rip)

    jmp   .sg_inputmine

.sg_invboard:
    leaq  msg_invalid(%rip), %rsi
    call  print_str
    jmp   .sg_inputboard

.sg_inputmine:
    leaq  msg_mines(%rip), %rsi
    call  print_str

    call  read_number

    ## must be >=1
    cmpq  $1, %rax
    jl    .sg_invmine

    ## max = size*size-1
    movq  board_size(%rip), %rbx
    imulq %rbx, %rbx
    decq  %rbx

    cmpq  %rbx, %rax
    jg    .sg_invmine

    ## save mine_count
    movq  %rax, mine_count(%rip)

    ret

.sg_invmine:
    leaq  msg_invalid(%rip), %rsi
    call  print_str
    jmp   .sg_inputmine

## after finish the game, open all mine
finish_game:
    pushq  %rbx
    pushq  %r12
    pushq  %r13
    call   print_header
    xorq   %r12, %r12

.fg_y:
    movq   board_size(%rip), %rax
    cmpq   %rax, %r12
    jge    .fg_done

    movq   %r12, %rax
    call   print_ynum

    xorq   %r13, %r13

.fg_x:
    movq   board_size(%rip), %rax
    cmpq   %rax, %r13
    jge    .fg_eol

    ## index = y*size + x
    movq   %r12, %rbx
    movq   board_size(%rip), %rax
    imulq  %rax, %rbx
    addq   %r13, %rbx

    leaq   board(%rip), %r9
    cmpb   $1, (%r9,%rbx)
    je     .fg_mine

    movq   %r12, %rdi
    movq   %r13, %rsi
    call   count_mines
    testq  %rax, %rax
    ## blank if cell's adjacent is 0

    jz     .fg_zero
    call   print_number
    jmp    .fg_spcheck
.fg_zero:
    movb   $' ', %al
    call   print_char
.fg_spcheck:
    movq   board_size(%rip), %rax
    decq   %rax
    cmpq   %rax, %r13
    je     .fg_nosp
    leaq   msg_space(%rip), %rsi
    call   print_str
    jmp    .fg_nosp

.fg_mine:
    movb   $'*', %al
    call   print_char
    movb   $' ', %al
    call   print_char

.fg_nosp:
    incq   %r13
    jmp    .fg_x

.fg_eol:
    leaq   msg_newline(%rip), %rsi
    call   print_str
    incq   %r12
    jmp    .fg_y

.fg_done:
    popq   %r13
    popq   %r12
    popq   %rbx
    ret

_start:
    leaq  msg_title(%rip), %rsi
    call  print_str
    call  setup_game
    call  init_board
    call  place_mines
    call  game_loop

    call finish_game
    ## exit(0)
    movq  $SYS_EXIT, %rax
    xorq  %rdi, %rdi
    syscall

