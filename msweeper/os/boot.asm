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

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; board を RAM 上でゼロクリア（reveal はイメージ内の db 0 で既に0）
    mov di, board
    mov cx, BOARD_WIDTH * BOARD_HEIGHT
    xor al, al
    rep stosb

    mov ax, 0x40
    mov es, ax
    mov ax, [es:0x6C]
    or al, 1              ; seedが0だとrandが0に固定され無限ループするため回避
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
    ; 入力: di = 調査するセルのインデックス
    ; 出力: al = 周囲の地雷数 (0～8)
    push bx
    push cx
    push dx
    push si
    push di

    ; 現在の行・列を取得 (row = di / BOARD_WIDTH, col = di % BOARD_WIDTH)
    mov ax, di
    xor dx, dx
    mov bx, BOARD_WIDTH
    div bx               ; ax = 行, dx = 列 (余り)
    mov si, ax           ; si = 行 (row) を保存
    ; dx = 列 (col) はこのまま使う

    xor cx, cx           ; 地雷カウンタ
    mov bx, neighbor_offsets
    mov di, 8            ; ループ回数

.loop:
    movsx ax, byte [bx]  ; 行オフセット
    inc bx
    movsx bp, byte [bx]  ; 列オフセット
    inc bx

    ; 隣接セルの行 = si + ax, 列 = dx + bp
    push si
    add ax, si
    mov si, ax           ; si = 隣接行

    push dx
    add dx, bp           ; dx = 隣接列

    ; 範囲チェック
    test si, si
    jl .skip
    cmp si, BOARD_HEIGHT
    jge .skip
    cmp dx, 0
    jl .skip
    cmp dx, BOARD_WIDTH
    jge .skip

    ; 有効なセル → board のインデックスを計算
    push ax
    mov ax, si
    shl ax, 3            ; ax = si * WIDTH (WIDTH=8)
    add ax, dx           ; ax = インデックス
    mov bp, ax
    pop ax

    test byte [board + bp], CELL_MINE
    jz .skip
    inc cx               ; 地雷発見
.skip:
    pop dx               ; 列を復元
    pop si               ; 行を復元
    dec di
    jnz .loop

    mov al, cl           ; 戻り値

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

calc_all_neighbors:
    mov di, BOARD_WIDTH * BOARD_HEIGHT
.loop:
    dec di
    test byte [board + di], CELL_MINE
    jnz .skip
    call count_neighbors       ; al = 隣接地雷数
    or byte [board + di], al   ; 下位5ビットに格納
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
    xor di, di
.cell_loop:
    mov ax, di
    mov cl, al
    and cl, BOARD_WIDTH-1   ; cl = col (0-based) = di mod 8
    shr ax, 3               ; al = row (0-based) = di / 8
    mov dh, al
    inc dh
    mov dl, cl
    inc dl
    call set_cursor
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
    inc di
    cmp di, BOARD_WIDTH*BOARD_HEIGHT
    jne .cell_loop
    ret

getch:
    mov ah, 0
    int 0x16
    ret

get_coord:
    call getch
    sub al, '0'
    ret

handle_input:
    call get_coord      ; 1文字目 = 行
    cbw
    mov dx, ax
    call get_coord      ; 2文字目 = 列
    cbw
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
