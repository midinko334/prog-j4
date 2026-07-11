default rel
;%define SYS_read      0
%define SYS_write     1
%define SYS_getrandom 318
%define SYS_exit      60

section .bss align=1
mine:           resb 64
game_over_flag: resb 1
randbuf:        resb 1
input_buf:      resb 32
opened:         resb 64
board_buf:      resb 512

section .text align=1
global _start

; ------------------------------------------------------------
_start:
    mov r15d, mine
    xor ebx, ebx                 ; placed count
    mov ecx, esp                 ; seed from stack pointer (ASLR entropy)
.place_loop:
    cmp ebx, 10
    jge .place_done
    imul ecx, ecx, 5
    inc ecx
    mov eax, ecx
    shr eax, 26
.place_loop2:
    cmp byte [r15 + rax], 1    ;(cmp byte [mine + rbx], 1)
    je .place_loop
    mov byte [r15 + rax], 1    ;(mov byte [mine + rbx], 1)
    inc ebx
    jmp .place_loop
.place_done:
    xor r13d, r13d

; ------------------------------------------------------------
main_loop:
    call print_board
;    call read_input               ; sets ebp=x, edi=y, CF=1 if invalid
.read_input:
    xor eax, eax    ;(mov eax, SYS_read)
    xor edi, edi
    lea esi, [r15+66]
    mov dl, 31
    syscall

    movzx ebp, byte [r15 + 66]
    sub ebp, '0'
    cmp ebp, 7
    ja main_loop

    movzx edi, byte [r15 + 67]
    sub edi, '0'
    cmp edi, 7
    ja main_loop
.done:
    mov eax, edi
    shl eax, 3
    add eax, ebp
    mov ebx, eax                  ; index

    cmp byte [r15 + 98 + rbx], 1  ;(cmp byte [opened + rbx], 1)
    je main_loop

    cmp byte [r15 + rbx], 1       ;(cmp byte [mine + rbx], 1)
    je .gameover

    mov byte [r15 + 98 + rbx], 1  ;(cmp byte [opened + rbx], 1)
    inc r13d
    cmp r13d, 54                   ; 64 - 10 mines
    je .gamewin
    jmp main_loop
.gameover:
    mov byte [r15 + 64], 'F'
    jmp short .gameend
.gamewin:
    mov byte [r15 + 64], 'S'
.gameend:
    call print_board
exit:
    xor eax, eax
    mov al, SYS_exit
    syscall

calc_neighbors:
    mov ebp, eax
    shr ebp, 3               ; y
    mov esi, eax
    and esi, 7                ; x
    xor ebx, ebx               ; count
    xor ecx, ecx
    dec ecx
.dr_loop:
    cmp ecx, 1
    jg .dr_done
    xor edx, edx
    dec edx
.dc_loop:
    cmp edx, 1
    jg .dc_done
    test ecx, ecx
    jnz .checkbounds
    test edx, edx
    jz .next_dc
.checkbounds:
    lea eax, [rcx + rbp]           ; nr
    test eax, eax
    js .next_dc
    cmp eax, 7
    jg .next_dc
    lea eax, [rsi + rdx]           ; nc
    test eax, eax
    js .next_dc
    cmp eax, 7
    jg .next_dc
    lea eax, [rcx + rbp]           ; nr (recompute; no free reg to cache it in)
    shl eax, 3
    add eax, esi
    add eax, edx                    ; neighbor index = nr*8+nc
    cmp byte [r15 + rax], 1
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
    push rdi
    mov al, ' '
    stosb
    stosb
    xor ecx, ecx           ; col = 0
.hdr_loop:
    lea eax, [rcx + '0']
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
    lea eax, [rbp + '0']
    stosb
    mov al, ' '
    stosb
    xor esi, esi                   ; col = 0
.col_loop:
    cmp esi, 8
    jge .col_done
    lea eax, [rsi + rbp*8]         ; index = row*8+col
    cmp byte [r15 + 98 + rax], 1
    je .print_number
    cmp byte [r15 + 64], 0
    je .print_dot
    cmp byte [r15 + rax], 1
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
    cmp byte [r15 + 64], 0
    je .no_end
    mov al, [r15 + 64]          ; 'F' or 'S'
    stosb
    mov al, 10
    stosb
.no_end:
    pop rax
    sub rdi, rax
    mov edx, edi
    mov esi, eax

write:
    push 1
    pop rax                       ; SYS_write = 1
    mov edi, eax
    syscall
    ret
