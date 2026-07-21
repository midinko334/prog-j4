default rel
;%define SYS_read      0
%define SYS_write     1
%define SYS_getrandom 318
%define SYS_exit      60

section .bss align=1
gameflag:       resb 1
randbuf:        resb 1
input_buf:      resb 32
opened:         resb 64
board_buf:      resb 512

section .text align=1
global _start

; ------------------------------------------------------------
_start:
    mov r15d, gameflag
    xor ebx, ebx
    mov bl, 10                   ; mines remaining (countdown)
    mov ecx, esp                 ; seed from stack pointer (ASLR entropy)
    xor r14d, r14d
.place_loop:
    lea ecx, [rcx + rcx*4 + 1]
    mov eax, ecx
    shr eax, 26
    bts r14, rax
    jc .place_loop
    dec ebx
    jnz .place_loop
.place_done:
    xor r13d, r13d

; ------------------------------------------------------------
main_loop:
    call print_board
;    call read_input               ; sets ebp=x, edi=y, CF=1 if invalid
.read_input:
    xor eax, eax    ;(mov eax, SYS_read)
    xor edi, edi
    lea esi, [r15 + 2]
    mov dl, 31
    syscall

    movzx eax, word [r15 + 2]
    sub al, '0'
    cmp al, 7
    ja main_loop
    sub ah, '0'
    cmp ah, 7
    ja main_loop
.done:
    movzx edi, al
    movzx ebp, ah
    lea eax, [rdi + rbp*8]         ; index = y*8 + x, computed directly into eax

    cmp byte [r15 + 34 + rax], 1  ;(cmp byte [opened + rax], 1)
    je main_loop
    bt r14, rax
    jc .gameover
    mov byte [r15 + 34 + rax], 1  ;(mov byte [opened + rax], 1)
    inc r13d
    cmp r13d, 54                   ; 64 - 10 mines
    je .gamewin
    jmp main_loop
.gameover:
    mov al, 'F'
    jmp short .gameend
.gamewin:
    mov al, 'S'
.gameend:
    mov [r15], al
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
    or ecx, -1
.dr_loop:
    or edx, -1
.dc_loop:
    mov eax, ecx
    or eax, edx
    jz .next_dc
.checkbounds:
    lea eax, [rcx + rbp]           ; nr
    cmp eax, 8                     ; unsigned: catches nr<0 and nr>7 in one test
    jae .next_dc
    lea eax, [rsi + rdx]           ; nc
    cmp eax, 8                     ; unsigned: catches nc<0 and nc>7 in one test
    jae .next_dc
    lea eax, [rcx + rbp]           ; nr (recompute; no free reg to cache it in)
    shl eax, 3
    add eax, esi
    add eax, edx                    ; neighbor index = nr*8+nc
    bt r14, rax
    jnc .next_dc
    inc ebx
.next_dc:
    inc edx
    cmp edx, 2
    jl .dc_loop
    inc ecx
    cmp ecx, 2
    jl .dr_loop
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
    cmp byte [r15 + 34 + rax], 1
    je .print_number
    cmp byte [r15], 0
    je .print_dot
    bt r14, rax
    jc .print_mine
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
    cmp byte [r15], 0
    je .no_end
    mov al, [r15]          ; 'F' or 'S'
    stosb
    mov al, 10
    stosb
.no_end:
    pop rax
    sub edi, eax
    mov edx, edi
    mov esi, eax

write:
    push 1
    pop rax                       ; SYS_write = 1
    mov edi, eax
    syscall
    ret
