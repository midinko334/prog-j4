%define SYS_read      0
%define SYS_write     1
%define SYS_getrandom 318
%define SYS_exit      60

section .data align=1
title:      db "=== M Sweeper ===", 10, 10
title_len   equ $-title

board_header: db 10, "  0 1 2 3 4 5 6 7", 10
header_len    equ $-board_header

prompt:     db 10, "open (x y): "
prompt_len  equ $-prompt

err_msg:    db "Invalid input", 10
err_len     equ $-err_msg

already_msg: db "Already opened", 10
already_len  equ $-already_msg

boom_msg:   db 10, "*** GAME OVER ***", 10
boom_len    equ $-boom_msg

win_msg:    db 10, "*** GAME CLEAR ***", 10
win_len     equ $-win_msg

section .bss align=1
mine:           resb 64
opened:         resb 64
game_over_flag: resb 1
randbuf:        resb 1
input_buf:      resb 32
board_buf:      resb 512

section .text align=1
global _start

; ------------------------------------------------------------
_start:
    cld

    ; --- place 10 mines randomly ---
    xor r15, r15                 ; placed count
.place_loop:
    cmp r15, 10
    jge .place_done
    call get_random_index        ; rax = 0-63
    mov r10, rax
    cmp byte [mine + r10], 1
    je .place_loop
    mov byte [mine + r10], 1
    inc r15
    jmp .place_loop
.place_done:

    xor r14, r14                 ; opened_count = 0

    lea rsi, [title]
    mov rdx, title_len
    call print_str

; ------------------------------------------------------------
main_loop:
    call print_board

    lea rsi, [prompt]
    mov rdx, prompt_len
    call print_str

    call read_input               ; sets r12=row, r13=col, CF=1 if invalid
    jc main_loop

    mov rax, r12
    shl rax, 3
    add rax, r13
    mov r10, rax                  ; index

    cmp byte [opened + r10], 1
    je .already

    cmp byte [mine + r10], 1
    je .gameover

    mov byte [opened + r10], 1
    inc r14
    cmp r14, 54                   ; 64 - 10 mines
    je .gamewin
    jmp main_loop

.already:
    lea rsi, [already_msg]
    mov rdx, already_len
    call print_str
    jmp main_loop

.gameover:
    mov byte [game_over_flag], 1
    call print_board
    lea rsi, [boom_msg]
    mov rdx, boom_len
    call print_str
    mov rax, SYS_exit
    mov rdi, 1
    syscall

.gamewin:
    call print_board
    lea rsi, [win_msg]
    mov rdx, win_len
    call print_str
    mov rax, SYS_exit
    mov rdi, 0
    syscall

; ============================================================
; get_random_index: rax = random value 0-63 (uniform, via getrandom)
; ============================================================
get_random_index:
    mov rax, SYS_getrandom
    lea rdi, [randbuf]
    mov rsi, 1
    xor rdx, rdx
    syscall
    movzx rax, byte [randbuf]
    and rax, 0x3F
    ret

; ============================================================
; calc_neighbors: input rax = index(0-63), output rax = mine count around it
; clobbers only its own saved regs (r8,r9,r10,r11,rbx,rcx,rdx,rsi,rdi saved/restored)
; ============================================================
calc_neighbors:
    mov r10, rax
    mov rax, r10
    shr rax, 3
    mov r8, rax                  ; row
    mov rax, r10
    and rax, 7
    mov r9, rax                  ; col

    xor r11, r11                 ; count

    or  rcx, -1                  ; dr
.dr_loop:
    cmp rcx, 1
    jg .dr_done
    or  rdx, -1                  ; dc
.dc_loop:
    cmp rdx, 1
    jg .dc_done

    cmp rcx, 0
    jne .checkbounds
    cmp rdx, 0
    je .next_dc

.checkbounds:
    mov rax, r8
    add rax, rcx                 ; nr
    cmp rax, 0
    jl .next_dc
    cmp rax, 7
    jg .next_dc
    mov rbx, r9
    add rbx, rdx                 ; nc
    cmp rbx, 0
    jl .next_dc
    cmp rbx, 7
    jg .next_dc

    mov rsi, rax
    shl rsi, 3
    add rsi, rbx
    cmp byte [mine + rsi], 1
    jne .next_dc
    inc r11

.next_dc:
    inc rdx
    jmp .dc_loop
.dc_done:
    inc rcx
    jmp .dr_loop
.dr_done:
    mov rax, r11
    ret

print_board:
    lea rdi, [board_buf]
    lea rsi, [board_header]
    mov rcx, header_len
    rep movsb

    xor r8, r8                   ; row = 0
.row_loop:
    cmp r8, 8
    jge .row_done

    mov al, r8b
    add al, '0'
    stosb
    mov al, ' '
    stosb

    xor r9, r9                   ; col = 0
.col_loop:
    cmp r9, 8
    jge .col_done

    mov rax, r8
    shl rax, 3
    add rax, r9
    mov r10, rax                 ; index

    cmp byte [opened + r10], 1
    je .print_number

    cmp byte [game_over_flag], 1
    jne .print_dot
    cmp byte [mine + r10], 1
    je .print_mine

.print_dot:
    mov al, '.'
    jmp .store_char
.print_mine:
    mov al, '*'
    jmp .store_char
.print_number:
    mov rax, r10
    call calc_neighbors
    add al, '0'

.store_char:
    stosb
    mov al, ' '
    stosb
    inc r9
    jmp .col_loop
.col_done:
    mov al, 10
    stosb
    inc r8
    jmp .row_loop
.row_done:

    lea rax, [board_buf]
    sub rdi, rax
    mov rdx, rdi                 ; length
    mov rax, SYS_write
    mov rdi, 1
    lea rsi, [board_buf]
    syscall

    ret

; ============================================================
; read_input: reads a line, parses "row col" (each single digit 0-7)
; output: r12 = row, r13 = col, CF=0 valid / CF=1 invalid(+error printed)
; ============================================================
read_input:
    mov rax, SYS_read
    mov rdi, 0
    lea rsi, [input_buf]
    mov rdx, 31
    syscall
    cmp rax, 0
    jl .read_error
    je .eof
    mov r8, rax                  ; n bytes
    xor r9, r9                   ; i = 0

.skip1:
    cmp r9, r8
    jge .invalid
    mov al, [input_buf + r9]
    cmp al, ' '
    je .skip1_inc
    cmp al, 9
    je .skip1_inc
    jmp .parse_row
.skip1_inc:
    inc r9
    jmp .skip1

.parse_row:
    cmp r9, r8
    jge .invalid
    mov al, [input_buf + r9]
    cmp al, '0'
    jl .invalid
    cmp al, '9'
    jg .invalid
    sub al, '0'
    movzx r13, al
    inc r9
    cmp r9, r8
    jge .after_row_check
    mov al, [input_buf + r9]
    cmp al, '0'
    jl .after_row_check
    cmp al, '9'
    jg .after_row_check
    jmp .invalid
.after_row_check:
    cmp r13, 7
    jg .invalid

.skip2:
    cmp r9, r8
    jge .invalid
    mov al, [input_buf + r9]
    cmp al, ' '
    je .skip2_inc
    cmp al, 9
    je .skip2_inc
    jmp .parse_col
.skip2_inc:
    inc r9
    jmp .skip2

.parse_col:
    cmp r9, r8
    jge .invalid
    mov al, [input_buf + r9]
    cmp al, '0'
    jl .invalid
    cmp al, '9'
    jg .invalid
    sub al, '0'
    movzx r12, al
    inc r9
    cmp r9, r8
    jge .after_col_check
    mov al, [input_buf + r9]
    cmp al, '0'
    jl .after_col_check
    cmp al, '9'
    jg .after_col_check
    jmp .invalid
.after_col_check:
    cmp r12, 7
    jg .invalid

    clc
    jmp .done
.eof:
    mov rax, SYS_exit
    mov rdi, 0
    syscall
.read_error:
    mov rax, SYS_exit
    mov rdi, 1
    syscall
.invalid:
    lea rsi, [err_msg]
    mov rdx, err_len
    call print_str
    stc
.done:
    ret

print_str:
    mov rax, SYS_write
    mov rdi, 1
    syscall
    ret
