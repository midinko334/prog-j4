%define SYS_read      0
%define SYS_write     1
%define SYS_getrandom 318
%define SYS_exit      60

section .data align=1
;title_len_b:  db title_end - title
;title:        db "=== M Sweeper ===", 10, 10
;title_end:

;prompt_len_b: db prompt_end - prompt
;prompt:       db 10, "open (x y): "
;prompt_end:

;err_len_b:    db err_end - err_msg
;err_msg:      db "Invalid input", 10
;err_end:

;already_len_b: db already_end - already_msg
;already_msg:   db "Already opened", 10
;already_end:

boom_len_b:   db boom_end - boom_msg
boom_msg:     db "GAME OVER"
boom_end:

win_len_b:    db win_end - win_msg
win_msg:      db "GAME CLEAR"
win_end:

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
    xor ebx, ebx                 ; placed count
.place_loop:
    cmp ebx, 10
    jge .place_done
    call get_random_index        ; eax = 0-63
    cmp byte [mine + rax], 1
    je .place_loop
    mov byte [mine + rax], 1
    inc ebx
    jmp .place_loop
.place_done:

    xor r14, r14                 ; opened_count = 0

;    mov esi, title
;    call print_str

; ------------------------------------------------------------
main_loop:
    call print_board

;    mov esi, prompt
;    call print_str

    call read_input               ; sets ebp=x, edi=y, CF=1 if invalid
    jc main_loop

    mov eax, edi
    shl eax, 3
    add eax, ebp
    mov ebx, eax                  ; index

    cmp byte [opened + rbx], 1
    je main_loop
;    je .already

    cmp byte [mine + rbx], 1
    je .gameover

    mov byte [opened + rbx], 1
    inc r14
    cmp r14, 54                   ; 64 - 10 mines
    je .gamewin
    jmp main_loop

;.already:
;    mov esi, already_msg
;    call print_str
;    jmp main_loop

.gameover:
    mov byte [game_over_flag], 1
    call print_board
    mov esi, boom_msg
    call print_str
    jmp exit1

.gamewin:
    call print_board
    mov esi, win_msg
    call print_str
    jmp exit0

exit1:
    mov edi, 1
    jmp exit_common
exit0:
    xor edi, edi
exit_common:
    mov eax, SYS_exit
    syscall

get_random_index:
    mov eax, SYS_getrandom
    mov edi, randbuf
    mov esi, 1
    xor edx, edx
    syscall
    movzx eax, byte [randbuf]
    and al, 0x3F
    ret

; eax = index (row*8+col) -> eax = mine count among 8 neighbors
calc_neighbors:
    mov ebp, eax
    shr ebp, 3               ; y
    mov esi, eax
    and esi, 7                ; x

    xor ebx, ebx               ; count
    mov ecx, -1                  ; dr
.dr_loop:
    cmp ecx, 1
    jg .dr_done
    mov edx, -1                    ; dc
.dc_loop:
    cmp edx, 1
    jg .dc_done

    test ecx, ecx
    jnz .checkbounds
    test edx, edx
    jz .next_dc

.checkbounds:
    lea eax, [ebp + ecx]           ; nr
    cmp eax, 0
    jl .next_dc
    cmp eax, 7
    jg .next_dc
    lea eax, [esi + edx]           ; nc
    cmp eax, 0
    jl .next_dc
    cmp eax, 7
    jg .next_dc

    lea eax, [ebp + ecx]           ; nr (recompute)
    shl eax, 3
    add eax, esi
    add eax, edx                    ; neighbor index = nr*8+nc
    cmp byte [mine + rax], 1
    jne .next_dc
    inc ebx

.next_dc:
    inc edx
    jmp .dc_loop
.dc_done:
    inc ecx
    jmp .dr_loop
.dr_done:
    mov eax, ebx
    ret

print_board:
    mov edi, board_buf
    mov al, 10
    stosb
    mov al, ' '
    stosb
    stosb
    xor ecx, ecx           ; col = 0
.hdr_loop:
    mov al, cl
    add al, '0'
    stosb
    mov al, ' '
    stosb
    inc ecx
    cmp ecx, 8
    jl .hdr_loop
    mov al, 10
    stosb
    xor ebp, ebp                 ; row = 0
.row_loop:
    cmp ebp, 8
    jge .row_done

    mov al, bpl
    add al, '0'
    stosb
    mov al, ' '
    stosb

    xor esi, esi                   ; col = 0
.col_loop:
    cmp esi, 8
    jge .col_done

    lea eax, [esi + ebp*8]         ; index = row*8+col

    cmp byte [opened + rax], 1
    je .print_number

    cmp byte [game_over_flag], 1
    jne .print_dot
    cmp byte [mine + rax], 1
    je .print_mine

.print_dot:
    mov al, '.'
    jmp .store_char
.print_mine:
    mov al, '*'
    jmp .store_char
.print_number:
    call calc_neighbors            ; eax already = index
    add al, '0'

.store_char:
    stosb
    mov al, ' '
    stosb
    inc esi
    jmp .col_loop
.col_done:
    mov al, 10
    stosb
    inc ebp
    jmp .row_loop
.row_done:

    mov eax, board_buf
    sub rdi, rax
    mov edx, edi                 ; length
    mov esi, board_buf
    jmp do_write

read_input:
    mov eax, SYS_read
    xor edi, edi
    mov esi, input_buf
    mov edx, 31
    syscall
    cmp eax, 0
    jl .read_error
    je .eof
    mov ebx, eax          ; n bytes
    xor ecx, ecx           ; i = 0

.skip1:
    cmp ecx, ebx
    jge .invalid
    mov al, [input_buf + rcx]
    cmp al, ' '
    je .skip1_inc
    cmp al, 9
    je .skip1_inc
    jmp .parse_row
.skip1_inc:
    inc ecx
    jmp .skip1

.parse_row:
    cmp ecx, ebx
    jge .invalid
    mov al, [input_buf + rcx]
    cmp al, '0'
    jl .invalid
    cmp al, '9'
    jg .invalid
    sub al, '0'
    movzx ebp, al          ; x
    inc ecx
    cmp ecx, ebx
    jge .after_row_check
    mov al, [input_buf + rcx]
    cmp al, '0'
    jl .after_row_check
    cmp al, '9'
    jg .after_row_check
    jmp .invalid
.after_row_check:
    cmp ebp, 7
    jg .invalid

.skip2:
    cmp ecx, ebx
    jge .invalid
    mov al, [input_buf + rcx]
    cmp al, ' '
    je .skip2_inc
    cmp al, 9
    je .skip2_inc
    jmp .parse_col
.skip2_inc:
    inc ecx
    jmp .skip2

.parse_col:
    cmp ecx, ebx
    jge .invalid
    mov al, [input_buf + rcx]
    cmp al, '0'
    jl .invalid
    cmp al, '9'
    jg .invalid
    sub al, '0'
    movzx edi, al           ; y
    inc ecx
    cmp ecx, ebx
    jge .after_col_check
    mov al, [input_buf + rcx]
    cmp al, '0'
    jl .after_col_check
    cmp al, '9'
    jg .after_col_check
    jmp .invalid
.after_col_check:
    cmp edi, 7
    jg .invalid

    clc
    jmp .done
.eof:
    jmp exit0
.read_error:
    jmp exit1
.invalid:
;    mov esi, err_msg
;    call print_str
    stc
.done:
    ret

print_str:
    movzx edx, byte [rsi-1]
do_write:
    mov eax, SYS_write
    mov edi, 1
    syscall
    ret
