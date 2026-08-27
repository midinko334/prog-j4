BITS 64

%define WIDTH        60
%define HEIGHT       20
%define MAXROBOTS    40
%define CELL_EMPTY   0
%define CELL_ROBOT   1
%define CELL_SCRAP   2
%define CELL_PLAYER  3

%define SYS_write    1
%define SYS_exit     60

section .data
ch_wall:    db '#'
ch_empty:   db ' '
ch_robot:   db '+'
ch_scrap:   db '*'
ch_player:  db '@'
nl:         db 10

clr_screen: db 27,'[2J',27,'[H'
clr_len     equ $-clr_screen

msg_cannot:      db "You cannot move there.",10
msg_cannot_len   equ $-msg_cannot
msg_catch:       db "You cannot move there. (You are going to get caught)",10
msg_catch_len    equ $-msg_catch
msg_badinput:    db "Please enter a digit 0-9.",10
msg_badinput_len equ $-msg_badinput
msg_gameover:    db 10,"You have been caught!  GAME OVER.",10
msg_gameover_len equ $-msg_gameover
msg_finalscore:  db "Final score: "
msg_finalscore_len equ $-msg_finalscore
msg_levelup:     db 10,"*** Field cleared! ***",10
msg_levelup_len  equ $-msg_levelup

pfx_prompt:  db "(level:"
pfx_prompt_len equ $-pfx_prompt
mid_prompt:  db " score:"
mid_prompt_len equ $-mid_prompt
sfx_prompt:  db "):? "
sfx_prompt_len equ $-sfx_prompt

; Keypad offsets: dx, dy.
dirtable:
    db  0, 0
    db -1, 1
    db  0, 1
    db  1, 1
    db -1, 0
    db  0, 0
    db  1, 0
    db -1,-1
    db  0,-1
    db  1,-1

section .bss
grid:          resb WIDTH*HEIGHT
cand:          resb WIDTH*HEIGHT

robot_x:       resb MAXROBOTS
robot_y:       resb MAXROBOTS
robot_alive:   resb MAXROBOTS
cand_x:        resb MAXROBOTS
cand_y:        resb MAXROBOTS
dead_this_turn resb MAXROBOTS
touched_idx:   resd MAXROBOTS

player_x:      resb 1
player_y:      resb 1

level:         resd 1
score:         resd 1
num_robots:    resd 1
robot_count:   resd 1

rng_state:     resq 1

outbuf:        resb 4096
numbuf:        resb 12

section .text
global _start
extern getChar

_start:
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    mov     rbx, rax
    mov     rax, 39
    syscall
    xor     rbx, rax
    or      rbx, 1
    mov     [rng_state], rbx

    mov     dword [level], 1
    mov     dword [score], 0

    call    new_game_field

main_loop:
    call    draw_field

.read_command:
    call    read_command

    cmp     al, 0
    je      .do_teleport
    cmp     al, 5
    je      .do_wait
    jmp     .do_move

.do_teleport:
    call    do_teleport
    jmp     .robots_move

.do_wait:
    jmp     .robots_move

.do_move:
    call    do_directional_move
    cmp     al, 1
    jne     .read_command

.robots_move:
    call    robots_phase
    cmp     byte [caught_flag], 1
    je      .game_over

    cmp     dword [robot_count], 0
    jne     main_loop

    mov     eax, [level]
    imul    eax, eax, 10
    add     [score], eax
    inc     dword [level]

    call    print_levelup_msg
    call    new_game_field
    jmp     main_loop

.game_over:
    call    draw_field
    mov     rsi, msg_gameover
    mov     rdx, msg_gameover_len
    call    do_write
    mov     rsi, msg_finalscore
    mov     rdx, msg_finalscore_len
    call    do_write
    mov     eax, [score]
    call    print_uint_nl
    mov     rdi, 0
    mov     rax, SYS_exit
    syscall

section .bss
caught_flag: resb 1

section .text
new_game_field:
    push    rbx

    mov     eax, [level]
    cmp     eax, 1
    jne     .keep_player

    call    clear_grid
    call    rand_empty_cell
    mov     [player_x], al
    mov     [player_y], ah
    mov     dl, ah
    movzx   rbx, dl
    imul    rbx, rbx, WIDTH
    movzx   rcx, al
    add     rbx, rcx
    mov     byte [grid+rbx], CELL_PLAYER
    jmp     .place_robots

.keep_player:
    call    clear_grid
    movzx   rbx, byte [player_y]
    imul    rbx, rbx, WIDTH
    movzx   rcx, byte [player_x]
    add     rbx, rcx
    mov     byte [grid+rbx], CELL_PLAYER

.place_robots:
    mov     eax, [level]
    imul    eax, eax, 5
    cmp     eax, MAXROBOTS
    jle     .ok_count
    mov     eax, MAXROBOTS
.ok_count:
    mov     [num_robots], eax
    mov     [robot_count], eax

    xor     r12, r12
.place_loop:
    cmp     r12d, [num_robots]
    jge     .place_done

    call    rand_empty_cell
    mov     dl, ah
    mov     [robot_x+r12], al
    mov     [robot_y+r12], dl
    mov     byte [robot_alive+r12], 1

    movzx   rbx, dl
    imul    rbx, rbx, WIDTH
    movzx   rcx, al
    add     rbx, rcx
    mov     byte [grid+rbx], CELL_ROBOT

    inc     r12
    jmp     .place_loop
.place_done:
    mov     byte [caught_flag], 0
    pop     rbx
    ret

clear_grid:
    push    rdi
    push    rcx
    push    rax
    mov     rdi, grid
    mov     rcx, WIDTH*HEIGHT
    xor     rax, rax
    cld
    rep     stosb
    pop     rax
    pop     rcx
    pop     rdi
    ret

rand_next:
    mov     rax, [rng_state]
    mov     rcx, rax
    shr     rcx, 12
    xor     rax, rcx
    mov     rcx, rax
    shl     rcx, 25
    xor     rax, rcx
    mov     rcx, rax
    shr     rcx, 27
    xor     rax, rcx
    mov     [rng_state], rax
    mov     rcx, 0x2545F4914F6CDD1D
    mul     rcx
    ret

rand_range:
    push    rbx
    push    rdx
    mov     rbx, rcx
    call    rand_next
    xor     rdx, rdx
    div     rbx
    mov     eax, edx
    pop     rdx
    pop     rbx
    ret

rand_empty_cell:
    push    rbx
    push    rcx
    push    rdx
    push    r8

    mov     r8, 500
.try:
    mov     ecx, WIDTH
    call    rand_range
    mov     bl, al
    mov     ecx, HEIGHT
    call    rand_range
    mov     bh, al

    movzx   rdx, al
    imul    rdx, rdx, WIDTH
    movzx   rcx, bl
    add     rdx, rcx
    cmp     byte [grid+rdx], CELL_EMPTY
    je      .found

    dec     r8
    jnz     .try

    xor     rdx, rdx
.scan:
    cmp     rdx, WIDTH*HEIGHT
    jge     .give_up
    cmp     byte [grid+rdx], CELL_EMPTY
    je      .scan_found
    inc     rdx
    jmp     .scan
.scan_found:
    mov     rax, rdx
    xor     rdx, rdx
    mov     ecx, WIDTH
    div     ecx
    mov     bh, al
    mov     bl, dl
    jmp     .found
.give_up:
    xor     bl, bl
    xor     bh, bh
.found:
    mov     al, bl
    mov     ah, bh
    pop     r8
    pop     rdx
    pop     rcx
    pop     rbx
    ret

do_teleport:
    push    rbx
    push    rcx

    movzx   rbx, byte [player_y]
    imul    rbx, rbx, WIDTH
    movzx   rcx, byte [player_x]
    add     rbx, rcx
    mov     byte [grid+rbx], CELL_EMPTY

    call    rand_empty_cell
    mov     [player_x], al
    mov     [player_y], ah

    mov     dl, ah
    movzx   rbx, dl
    imul    rbx, rbx, WIDTH
    movzx   rcx, al
    add     rbx, rcx
    mov     byte [grid+rbx], CELL_PLAYER

    pop     rcx
    pop     rbx
    ret

; Returns AL=1 on success, AL=0 when the move is rejected.
do_directional_move:
    push    rbx
    push    rcx
    push    rdx
    push    r8
    push    r9

    movzx   rbx, al
    movsx   r8, byte [dirtable+rbx*2]
    movsx   r9, byte [dirtable+rbx*2+1]

    movsx   rcx, byte [player_x]
    add     rcx, r8
    movsx   rdx, byte [player_y]
    add     rdx, r9

    cmp     rcx, 0
    jl      .oob
    cmp     rcx, WIDTH
    jge     .oob
    cmp     rdx, 0
    jl      .oob
    cmp     rdx, HEIGHT
    jge     .oob

    mov     rbx, rdx
    imul    rbx, rbx, WIDTH
    add     rbx, rcx
    movzx   eax, byte [grid+rbx]

    cmp     al, CELL_SCRAP
    je      .blocked

    ; This also detects a robot already on the destination cell.
    call    destination_is_caught
    test    al, al
    jnz     .blocked_by_robot

    movzx   r10, byte [player_y]
    imul    r10, r10, WIDTH
    movzx   r11, byte [player_x]
    add     r10, r11
    mov     byte [grid+r10], CELL_EMPTY

    mov     byte [grid+rbx], CELL_PLAYER
    mov     [player_x], cl
    mov     [player_y], dl

    mov     al, 1
    jmp     .done

.oob:
.blocked:
    mov     rsi, msg_cannot
    mov     rdx, msg_cannot_len
    call    do_write
    mov     al, 0
    jmp     .done

.blocked_by_robot:
    mov     rsi, msg_catch
    mov     rdx, msg_catch_len
    call    do_write
    mov     al, 0

.done:
    pop     r9
    pop     r8
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; Input: RCX=x, RDX=y.  Returns AL=1 if a robot can reach the cell.
destination_is_caught:
    lea     r8, [rdx-1]
    lea     r9, [rdx+1]
.row_loop:
    cmp     r8, r9
    jg      .safe
    cmp     r8, 0
    jl      .next_row
    cmp     r8, HEIGHT
    jge     .next_row

    lea     r10, [rcx-1]
    lea     r11, [rcx+1]
.col_loop:
    cmp     r10, r11
    jg      .next_row
    cmp     r10, 0
    jl      .next_col
    cmp     r10, WIDTH
    jge     .next_col

    mov     rax, r8
    imul    rax, rax, WIDTH
    add     rax, r10
    cmp     byte [grid+rax], CELL_ROBOT
    je      .caught

.next_col:
    inc     r10
    jmp     .col_loop

.next_row:
    inc     r8
    jmp     .row_loop

.caught:
    mov     al, 1
    ret
.safe:
    xor     eax, eax
    ret

; Move robots simultaneously and resolve collisions.
robots_phase:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    movzx   r13, byte [player_x]
    movzx   r14, byte [player_y]

    xor     r12, r12
.calc_loop:
    cmp     r12d, [num_robots]
    jge     .calc_done
    cmp     byte [robot_alive+r12], 0
    je      .calc_next

    movsx   rax, byte [robot_x+r12]
    movsx   rbx, byte [robot_y+r12]

    xor     rcx, rcx
    cmp     r13, rax
    je      .dxdone
    jg      .dxpos
    mov     rcx, -1
    jmp     .dxdone
.dxpos:
    mov     rcx, 1
.dxdone:
    add     rax, rcx

    xor     rdx, rdx
    cmp     r14, rbx
    je      .dydone
    jg      .dypos
    mov     rdx, -1
    jmp     .dydone
.dypos:
    mov     rdx, 1
.dydone:
    add     rbx, rdx

    cmp     rax, 0
    jge     .cx0
    xor     rax, rax
.cx0:
    cmp     rax, WIDTH-1
    jle     .cx1
    mov     rax, WIDTH-1
.cx1:
    cmp     rbx, 0
    jge     .cy0
    xor     rbx, rbx
.cy0:
    cmp     rbx, HEIGHT-1
    jle     .cy1
    mov     rbx, HEIGHT-1
.cy1:

    mov     [cand_x+r12], al
    mov     [cand_y+r12], bl

    mov     r15, rbx
    imul    r15, r15, WIDTH
    add     r15, rax
    mov     [touched_idx+r12*4], r15d
    inc     byte [cand+r15]

.calc_next:
    inc     r12
    jmp     .calc_loop
.calc_done:

    push    rdi
    push    rcx
    push    rax
    mov     rdi, dead_this_turn
    mov     rcx, MAXROBOTS
    xor     rax, rax
    cld
    rep     stosb
    pop     rax
    pop     rcx
    pop     rdi

    xor     r12, r12
.judge_loop:
    cmp     r12d, [num_robots]
    jge     .judge_done
    cmp     byte [robot_alive+r12], 0
    je      .judge_next

    movzx   rax, byte [cand_x+r12]
    movzx   rbx, byte [cand_y+r12]

    cmp     rax, r13
    jne     .not_caught
    cmp     rbx, r14
    jne     .not_caught
    mov     byte [caught_flag], 1
    jmp     .judge_done_break

.not_caught:
    mov     r15, rbx
    imul    r15, r15, WIDTH
    add     r15, rax
    movzx   ecx, byte [cand+r15]
    cmp     ecx, 2
    jae     .becomes_scrap
    movzx   ecx, byte [grid+r15]
    cmp     ecx, CELL_SCRAP
    je      .becomes_scrap
    jmp     .judge_next

.becomes_scrap:
    mov     byte [dead_this_turn+r12], 1

.judge_next:
    inc     r12
    jmp     .judge_loop
.judge_done_break:
.judge_done:

    xor     r12, r12
.cleanup_loop:
    cmp     r12d, [num_robots]
    jge     .cleanup_done
    cmp     byte [robot_alive+r12], 0
    je      .cleanup_next
    mov     eax, [touched_idx+r12*4]
    mov     byte [cand+rax], 0
.cleanup_next:
    inc     r12
    jmp     .cleanup_loop
.cleanup_done:

    cmp     byte [caught_flag], 1
    je      .phase_end

    xor     r12, r12
.clearold_loop:
    cmp     r12d, [num_robots]
    jge     .clearold_done
    cmp     byte [robot_alive+r12], 0
    je      .clearold_next

    movzx   rax, byte [robot_x+r12]
    movzx   rbx, byte [robot_y+r12]
    mov     r15, rbx
    imul    r15, r15, WIDTH
    add     r15, rax
    mov     byte [grid+r15], CELL_EMPTY

.clearold_next:
    inc     r12
    jmp     .clearold_loop
.clearold_done:

    xor     r12, r12
.apply_loop:
    cmp     r12d, [num_robots]
    jge     .apply_done
    cmp     byte [robot_alive+r12], 0
    je      .apply_next

    movzx   rax, byte [cand_x+r12]
    movzx   rbx, byte [cand_y+r12]
    mov     r15, rbx
    imul    r15, r15, WIDTH
    add     r15, rax

    cmp     byte [dead_this_turn+r12], 1
    je      .this_dead

    mov     byte [grid+r15], CELL_ROBOT
    mov     [robot_x+r12], al
    mov     [robot_y+r12], bl
    jmp     .apply_next

.this_dead:
    mov     byte [grid+r15], CELL_SCRAP
    mov     byte [robot_alive+r12], 0
    dec     dword [robot_count]
    inc     dword [score]

.apply_next:
    inc     r12
    jmp     .apply_loop
.apply_done:

.phase_end:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

draw_field:
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    push    r12
    push    r13

    mov     rsi, clr_screen
    mov     rdx, clr_len
    call    do_write

    mov     rdi, outbuf

    mov     byte [rdi], '+'
    inc     rdi
    mov     rcx, WIDTH
    mov     al, '-'
    cld
    rep     stosb
    mov     byte [rdi], '+'
    inc     rdi
    mov     byte [rdi], 10
    inc     rdi

    xor     r12, r12
.row_loop:
    cmp     r12, HEIGHT
    jge     .row_done

    mov     byte [rdi], '|'
    inc     rdi

    xor     r13, r13
.col_loop:
    cmp     r13, WIDTH
    jge     .col_done

    mov     rax, r12
    imul    rax, rax, WIDTH
    add     rax, r13
    movzx   eax, byte [grid+rax]

    cmp     al, CELL_EMPTY
    je      .c_empty
    cmp     al, CELL_ROBOT
    je      .c_robot
    cmp     al, CELL_SCRAP
    je      .c_scrap
    mov     byte [rdi], '@'
    jmp     .c_next
.c_empty:
    mov     byte [rdi], ' '
    jmp     .c_next
.c_robot:
    mov     byte [rdi], '+'
    jmp     .c_next
.c_scrap:
    mov     byte [rdi], '*'
.c_next:
    inc     rdi
    inc     r13
    jmp     .col_loop
.col_done:

    mov     byte [rdi], '|'
    inc     rdi
    mov     byte [rdi], 10
    inc     rdi

    inc     r12
    jmp     .row_loop
.row_done:

    mov     byte [rdi], '+'
    inc     rdi
    mov     rcx, WIDTH
    mov     al, '-'
    cld
    rep     stosb
    mov     byte [rdi], '+'
    inc     rdi
    mov     byte [rdi], 10
    inc     rdi

    mov     rax, rdi
    sub     rax, outbuf
    mov     rsi, outbuf
    mov     rdx, rax
    call    do_write

    mov     rsi, pfx_prompt
    mov     rdx, pfx_prompt_len
    call    do_write
    mov     eax, [level]
    call    print_uint

    mov     rsi, mid_prompt
    mov     rdx, mid_prompt_len
    call    do_write
    mov     eax, [score]
    call    print_uint

    mov     rsi, sfx_prompt
    mov     rdx, sfx_prompt_len
    call    do_write

    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; Read a digit with the C getChar() function.
read_command:
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    push    r12

.again:
    ; The System V ABI requires 16-byte stack alignment before a call.
    sub     rsp, 8
    call    getChar
    add     rsp, 8

    mov     r12b, al
    mov     al, r12b
    cmp     al, '0'
    jl      .badinput
    cmp     al, '9'
    jg      .badinput

    sub     al, '0'
    jmp     .ret

.badinput:
    mov     rsi, msg_badinput
    mov     rdx, msg_badinput_len
    call    do_write
    jmp     .again

.ret:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret

print_levelup_msg:
    mov     rsi, msg_levelup
    mov     rdx, msg_levelup_len
    call    do_write
    ret

; Write RDX bytes from RSI to stdout.
do_write:
    push    rax
    push    rdi
    mov     rax, SYS_write
    mov     rdi, 1
    syscall
    pop     rdi
    pop     rax
    ret

print_uint:
    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rdi
    push    rsi

    mov     rdi, numbuf+11
    mov     byte [rdi], 0
    mov     rbx, 10
    mov     ecx, 0

    test    eax, eax
    jnz     .conv
    dec     rdi
    mov     byte [rdi], '0'
    inc     ecx
    jmp     .print

.conv:
.conv_loop:
    test    eax, eax
    jz      .conv_done
    xor     rdx, rdx
    div     ebx
    add     dl, '0'
    dec     rdi
    mov     [rdi], dl
    inc     ecx
    jmp     .conv_loop
.conv_done:

.print:
    mov     rsi, rdi
    mov     edx, ecx
    call    do_write

    pop     rsi
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret

print_uint_nl:
    call    print_uint
    mov     rsi, nl
    mov     rdx, 1
    call    do_write
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
