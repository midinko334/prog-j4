BITS 16
ORG 0x7C00

BOARD_WIDTH  equ 8
BOARD_HEIGHT equ 8
NUM_MINES    equ 10

CELL_HIDDEN   equ 0x00
CELL_MINE     equ 0x80
CELL_FLAGGED  equ 0x40
CELL_OPEN     equ 0x20
CELL_MASK     equ 0x1F

board equ 0x7E00

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

cell_index:
    mov di, dx
    imul di, BOARD_WIDTH
    add di, ax
    ret

neighbor_offsets:
    db -1,-1, -1,0, -1,1
    db  0,-1,        0,1
    db  1,-1,  1,0,  1,1
neighbor_count equ 8

count_neighbors:
    push di
    push cx
    push si
    xor cx, cx
    mov si, neighbor_offsets
    mov bx, neighbor_count
.loop:
    movsx dx, byte [si]
    inc si
    movsx ax, byte [si]
    inc si
    push di
    call cell_index
    mov di, ax
    pop ax
    mov dx, ax
    shr dx, 8
    mov ax, di
    cmp dx, 0
    jl .skip
    cmp dx, BOARD_HEIGHT-1
    jg .skip
    cmp ax, 0
    jl .skip
    cmp ax, BOARD_WIDTH-1
    jg .skip
    call cell_index
    test byte [board + di], CELL_MINE
    jz .skip
    inc cx
.skip:
    dec bx
    jnz .loop
    mov al, cl
    pop si
    pop cx
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

putchar:
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    ret

putdigit:
    add al, '0'
    call putchar
    ret

reveal db 0

; draw_board also handles the "reveal all" (game-over/win) display,
; selected via the `reveal` flag, so a separate show_all_mines routine
; is no longer needed.
draw_board:
    call clear_screen
    mov dh, 1
.row_loop:
    mov dl, 1
.col_loop:
    call set_cursor
    mov di, dx
    call cell_index
    mov al, [board + di]
    cmp byte [reveal], 0
    jne .reveal_mode
    test al, CELL_OPEN
    jz .hidden
    test al, CELL_MINE
    jnz .mine
    and al, CELL_MASK
    call putdigit
    jmp .next
.hidden:
    test al, CELL_FLAGGED
    jz .dot
    mov al, 'F'
    call putchar
    jmp .next
.reveal_mode:
    test al, CELL_MINE
    jz .dot
.mine:
    mov al, '*'
    call putchar
    jmp .next
.dot:
    mov al, '.'
    call putchar
.next:
    inc dl
    cmp dl, BOARD_WIDTH+1
    jb .col_loop
    inc dh
    cmp dh, BOARD_HEIGHT+1
    jb .row_loop
    ret

getch:
    mov ah, 0
    int 0x16
    ret

get_coord:
    call getch
    sub al, '0'
    ret

input_x db 0
input_y db 0

handle_input:
    call get_coord
    mov [input_x], al
    call get_coord
    mov [input_y], al
    mov dl, [input_x]
    mov dh, [input_y]
    call cell_index
    call getch
    cmp al, 'o'
    je .open
    cmp al, 'f'
    je .flag
    cmp al, 'q'
    je .quit
    jmp .done
.open:
    mov al, [board + di]
    test al, CELL_OPEN
    jnz .done
    test al, CELL_FLAGGED
    jnz .done
    test al, CELL_MINE
    jnz .end_game
    or byte [board + di], CELL_OPEN
    call check_win
    jc .end_game
    jmp .done
.flag:
    test byte [board + di], CELL_OPEN
    jnz .done
    xor byte [board + di], CELL_FLAGGED
    jmp .done
.quit:
    mov al, 1
    ret
.end_game:
    mov byte [reveal], 1
    call draw_board
    mov al, 1
    ret
.done:
    xor al, al
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

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; board isn't stored in the image, so zero it out in RAM here
    mov di, board
    mov cx, BOARD_WIDTH * BOARD_HEIGHT
    xor al, al
    rep stosb

    mov ax, 0x40
    mov es, ax
    mov ax, [es:0x6C]
    mov [seed], ax

    call place_mines
    call calc_all_neighbors

game_loop:
    call draw_board
    call handle_input
    test al, al
    jz game_loop

    call getch
    cli
    hlt
    jmp $

times 510 - ($ - $$) db 0
dw 0xAA55
