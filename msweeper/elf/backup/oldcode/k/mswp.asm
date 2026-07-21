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
    mov bl, 10
    mov ecx, esp
;    xor r14d, r14d
.place_loop:
    lea ecx, [rcx + rcx*4 + 1]
    mov eax, ecx
    shr eax, 26
    bts r14, rax
    jc .place_loop
    dec ebx
    jnz .place_loop
.place_done:
;    xor r13d, r13d

; ------------------------------------------------------------
main_loop:
    call print_board
.read_input:
    xor eax, eax
    xor edi, edi
    lea esi, [r15 + 2]
    mov dl, 3
    syscall

    movzx eax, word [r15 + 2]
    sub ax, 0x3030
    test ax, 0xf8f8
    jnz main_loop
.done:
    shl ah, 3
    add al, ah
    xor ah, ah

    cmp byte [r15 + 34 + rax], 1
    je main_loop
    bt r14, rax
    jc .gameend
    mov byte [r15 + 34 + rax], 1
    inc r13d
    cmp r13d, 54
    jne main_loop
.gameend:
    inc byte [r15]
    call print_board
exit:
    mov al, 60
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
    lea eax, [rsi + rdx]           ; nc
    cmp eax, 8                     ; unsigned: catches nc<0 and nc>7 in one test
    jae .next_dc
    lea eax, [rcx + rbp]           ; nr
    cmp eax, 8                     ; unsigned: catches nr<0 and nr>7 in one test
    jae .next_dc
    shl eax, 3
    add eax, esi
    add eax, edx
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
    lea edi, [r15 + 98]
    push rdi
    mov al, ' '
    stosb
    stosb
    xor ecx, ecx
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
    xor ebp, ebp
.row_loop:
    lea eax, [rbp + '0']
    stosb
    mov al, ' '
    stosb
    xor esi, esi
.col_loop:
    lea eax, [rsi + rbp*8]
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
    call calc_neighbors
    add al, '0'
.store_char:
    stosb
    mov al, ' '
    stosb
    inc esi
    cmp esi, 8
    jl .col_loop
.col_done:
    mov al, 10
    stosb
    inc ebp
    cmp ebp, 8
    jl .row_loop
.row_done:
    pop rax
    sub edi, eax
    mov edx, edi
    mov esi, eax

write:
    push 1
    pop rax
    mov edi, eax
    syscall
    ret
