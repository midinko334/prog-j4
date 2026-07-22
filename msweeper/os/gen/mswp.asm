BITS 16
ORG 0x7C00

BOARD_WIDTH  equ 8
BOARD_HEIGHT equ 8
NUM_MINES    equ 10

CELL_MINE     equ 0x80
CELL_OPEN     equ 0x20
CELL_MASK     equ 0x1F

board equ 0x7E00

start:
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

    mov di, board
    mov cx, BOARD_WIDTH * BOARD_HEIGHT
    xor al, al
    rep stosb

    int 0x1A
    mov ax, dx
    or al, 1
    mov [seed], ax

    call place_mines
    call calc_all_neighbors

game_loop:
    call draw_board
    call handle_input
    test al, al
    jz game_loop

    cli
    hlt
    jmp $

seed dw 0x1234

rand:
    mov ax, [seed]
    mov di, ax
    shl di, 7
    xor ax, di
    mov di, ax
    shr di, 9
    xor ax, di
    mov di, ax
    shl di, 8
    xor ax, di
    mov [seed], ax
    ret

rand_range:
    call rand
    xor dx, dx
    div bx
    mov ax, dx
    ret

place_mines:
    mov cx, NUM_MINES
.loop:
    mov bx, BOARD_WIDTH * BOARD_HEIGHT
    call rand_range
    mov bx, ax
    test byte [board + bx], CELL_MINE
    jnz .loop
    or byte [board + bx], CELL_MINE
    dec cx
    jnz .loop
    ret

neighbor_offsets:
    db -1,-1, -1,0, -1,1
    db  0,-1,        0,1
    db  1,-1,  1,0,  1,1

count_neighbors:
    push di
    mov ax, di
    xor dx, dx
    mov bx, BOARD_WIDTH
    div bx
    mov si, ax
    xor cx, cx
    mov bx, neighbor_offsets
    mov di, 8
.loop:
    movsx ax, byte [bx]
    inc bx
    movsx bp, byte [bx]
    inc bx
    push si
    add ax, si
    mov si, ax
    push dx
    add dx, bp
    test si, si
    jl .skip
    cmp si, BOARD_HEIGHT
    jge .skip
    cmp dx, 0
    jl .skip
    cmp dx, BOARD_WIDTH
    jge .skip
    push ax
    mov ax, si
    shl ax, 3
    add ax, dx
    mov bp, ax
    pop ax

    test byte [board + bp], CELL_MINE
    jz .skip
    inc cx
.skip:
    pop dx
    pop si
    dec di
    jnz .loop

    mov al, cl

    pop di
    ret

calc_all_neighbors:
    mov di, BOARD_WIDTH * BOARD_HEIGHT
.loop:
    dec di
    test byte [board + di], CELL_MINE
    jnz .skip
    call count_neighbors
    or byte [board + di], al
.skip:
    test di, di
    jnz .loop
    ret

clear_screen:
    mov ax, 0x0003
    int 0x10
    ret

set_cursor:
    mov ah, 0x02
    mov bh, 0
    int 0x10
    ret

reveal db 0
cursor db 0

draw_board:
    call clear_screen
    xor di, di
.cell_loop:
    mov ax, di
    cmp al, [cursor]
    mov bl, 0x07
    jne .nohi
    mov bl, 0x70
.nohi:
    mov cl, al
    and cl, BOARD_WIDTH-1
    shr ax, 3
    mov dh, al
    inc dh
    mov dl, cl
    inc dl
    call set_cursor
    mov al, [board + di]
    cmp byte [reveal], 0
    jne .reveal_mode
    test al, CELL_OPEN
    jz .dot
    test al, CELL_MINE
    jnz .mine
    and al, CELL_MASK
    add al, '0'
    jmp .print
.reveal_mode:
    test al, CELL_MINE
    jz .dot
.mine:
    mov al, '*'
    jmp .print
.dot:
    mov al, '.'
.print:
    mov ah, 0x09
    mov cx, 1
    int 0x10
.next:
    inc di
    cmp di, BOARD_WIDTH*BOARD_HEIGHT
    jne .cell_loop
    ret

getch:
    mov ah, 0
    int 0x16
    ret

handle_input:
    call getch
    cmp al, 'w'
    je .up
    cmp al, 's'
    je .down
    cmp al, 'a'
    je .left
    cmp al, 'd'
    je .right
    cmp al, ' '
    je .open
    cmp al, 'q'
    je .quit
    jmp .done
.up:
    cmp byte [cursor], BOARD_WIDTH
    jb .done
    sub byte [cursor], BOARD_WIDTH
    jmp .done
.down:
    cmp byte [cursor], BOARD_WIDTH*(BOARD_HEIGHT-1)
    jae .done
    add byte [cursor], BOARD_WIDTH
    jmp .done
.left:
    mov al, [cursor]
    and al, BOARD_WIDTH-1
    jz .done
    dec byte [cursor]
    jmp .done
.right:
    mov al, [cursor]
    and al, BOARD_WIDTH-1
    cmp al, BOARD_WIDTH-1
    je .done
    inc byte [cursor]
    jmp .done
.open:
    movzx di, byte [cursor]
    mov al, [board + di]
    test al, CELL_OPEN
    jnz .done
    test al, CELL_MINE
    jnz .end_game
    or byte [board + di], CELL_OPEN
    call check_win
    jc .end_game
.done:
    xor al, al
    ret
.quit:
    mov al, 1
    ret
.end_game:
    mov byte [reveal], 1
    call draw_board
    mov al, 1
    ret

check_win:
    mov cx, BOARD_WIDTH * BOARD_HEIGHT
    mov bx, cx
    sub bx, NUM_MINES
    xor dx, dx
    mov si, board
.loop:
    mov al, [si]
    test al, CELL_MINE
    jnz .skip
    test al, CELL_OPEN
    jz .skip
    inc dx
.skip:
    inc si
    dec cx
    jnz .loop
    cmp dx, bx
    je .win
    clc
    ret
.win:
    stc
    ret

times 510 - ($ - $$) db 0
dw 0xAA55
