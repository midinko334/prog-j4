%define SYS_read      0
%define SYS_write     1
%define SYS_getrandom 318
%define SYS_exit      60

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
.get_random_index:
    mov eax, SYS_getrandom
    mov edi, randbuf
    mov esi, 1
    xor edx, edx
    syscall
    movzx eax, byte [randbuf]
    and al, 0x3F
.place_loop2:
    cmp byte [mine + rax], 1
    je .place_loop
    mov byte [mine + rax], 1
    inc ebx
    jmp .place_loop
.place_done:

    xor r14, r14                 ; opened_count = 0

; ------------------------------------------------------------
main_loop:
    call print_board
;    call read_input               ; sets ebp=x, edi=y, CF=1 if invalid
.read_input:
    mov eax, SYS_read
    xor edi, edi
    mov esi, input_buf
    mov edx, 31
    syscall
    cmp eax, 2
    jl exit

    movzx ebp, byte [input_buf]
    sub ebp, '0'
    cmp ebp, 7
    ja main_loop

    movzx edi, byte [input_buf + 1]
    sub edi, '0'
    cmp edi, 7
    ja main_loop
.done:
    mov eax, edi
    shl eax, 3
    add eax, ebp
    mov ebx, eax                  ; index

    cmp byte [opened + rbx], 1
    je main_loop

    cmp byte [mine + rbx], 1
    je .gameover

    mov byte [opened + rbx], 1
    inc r14
    cmp r14, 54                   ; 64 - 10 mines
    je .gamewin
    jmp main_loop
.gameover:
    mov byte [game_over_flag], 1
    mov al, 'F'
    jmp short .gameend
.gamewin:
    mov al, 'S'
.gameend:
    push rax
    call print_board
    pop rax

    mov edi, board_buf
    stosb
    mov al, 10
    stosb

    mov edx, 2         ; "F\n" or "S\n"
    mov esi, board_buf
    mov edi, 1
    call write
exit:
    mov eax, SYS_exit
    syscall

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

write:
    mov eax, SYS_write
    mov edi, 1
    syscall
    ret
