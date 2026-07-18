; minesweeper.asm - kernel copies this image to 0x2000 and calls it once per tick

VIDEO        EQU 0xB8000
PANEL_START  EQU VIDEO + 82          ; column 41 (right of the divider)
BOARD_OFFSET EQU PANEL_START + 160 * 2
SAFE_CELLS   EQU 54
MINE_COUNT   EQU 10
PANEL_WIDTH  EQU 39

mswp:
    cmp byte [initialized], 0
    jne .poll_input
    call reset_game
    mov byte [initialized], 1
.poll_input:
    call poll_key
    test al, al
    jz .draw
    cmp byte [game_state], 0
    je .playing
    cmp byte [retry_prompt], 0
    jne .confirm_retry
    cmp byte [quit_prompt], 0
    jne .confirm_quit
    cmp al, 0x10                    ; Q
    je .ask_quit
    cmp al, 0x13                    ; R
    je .ask_retry
    jmp .draw
.confirm_retry:
    cmp al, 0x31                    ; N
    je .dismiss_retry
    call reset_game
    jmp .draw
.dismiss_retry:
    mov byte [retry_prompt], 0
    mov byte [screen_dirty], 1
    jmp .draw
.confirm_quit:
    cmp al, 0x31                    ; N
    je .dismiss_quit
    mov al, 1                       ; ask the kernel to shut down
    ret
.dismiss_quit:
    mov byte [quit_prompt], 0
    mov byte [screen_dirty], 1
    jmp .draw
.ask_retry:
    mov byte [retry_prompt], 1
    mov byte [screen_dirty], 1
    jmp .draw
.ask_quit:
    mov byte [quit_prompt], 1
    mov byte [screen_dirty], 1
    jmp .draw
.playing:
    cmp al, 0x11                    ; W
    je .up
    cmp al, 0x1E                    ; A
    je .left
    cmp al, 0x1F                    ; S
    je .down
    cmp al, 0x20                    ; D
    je .right
    cmp al, 0x39                    ; Space
    je .open
    jmp .draw
.up:
    cmp byte [cursor], 8
    jb .draw
    sub byte [cursor], 8
    jmp .changed
.down:
    cmp byte [cursor], 56
    jae .draw
    add byte [cursor], 8
    jmp .changed
.left:
    mov al, [cursor]
    and al, 7
    jz .draw
    dec byte [cursor]
    jmp .changed
.right:
    mov al, [cursor]
    and al, 7
    cmp al, 7
    je .draw
    inc byte [cursor]
    jmp .changed
.open:
    call open_cell
 .changed:
    mov byte [screen_dirty], 1
.draw:
    cmp byte [screen_dirty], 0
    je .done
    call print_board
    mov byte [screen_dirty], 0
.done:
    xor al, al                      ; continue running
    ret

; Start a new game with a fresh mine layout.
reset_game:
    cld
    mov byte [cursor], 0
    mov byte [safe_opened], 0
    mov byte [game_state], 0
    mov byte [retry_prompt], 0
    mov byte [quit_prompt], 0
    mov byte [screen_dirty], 1
    mov edi, opened
    xor eax, eax
    mov ecx, 64
    rep stosb
    call place_mines
    ret

; Read at most one make code.  AL=0 when there is no usable key input.
poll_key:
    in al, 0x64
    test al, 1
    jz .none
    in al, 0x60
    test al, 0x80                    ; ignore key-release codes
    jz .done
.none:
    xor al, al
.done:
    ret

; Opens only the selected square. Zero squares deliberately do not cascade.
open_cell:
    movzx ebx, byte [cursor]
    cmp byte [opened + ebx], 0
    jne .done
    mov byte [opened + ebx], 1
    cmp byte [mine_map + ebx], 0
    jne .mine
    inc byte [safe_opened]
    cmp byte [safe_opened], SAFE_CELLS
    jne .done
    mov byte [game_state], 1         ; all 54 safe cells opened
    call reveal_mines
    ret
.mine:
    mov byte [game_state], 2         ; opened a mine
    call reveal_mines
.done:
    ret

; Mark every mine as opened once the game has ended so the board reveals them.
reveal_mines:
    xor ebx, ebx
.cell:
    cmp byte [mine_map + ebx], 0
    je .next
    mov byte [opened + ebx], 1
.next:
    inc ebx
    cmp ebx, 64
    jb .cell
    ret

; Initialize the pseudo-random generator from the current RTC time, then place
; ten distinct mines in the 8x8 map.  RTC values are BCD, which is still a
; suitable varying seed once the three fields are mixed together.
place_mines:
    pushad
    call seed_from_rtc

    mov edi, mine_map
    xor eax, eax
    mov ecx, 64
    rep stosb
    xor ecx, ecx                    ; number of mines placed
.next_mine:
    call random_next
    and eax, 63                     ; board index: 0..63
    cmp byte [mine_map + eax], 0
    jne .next_mine                  ; retry duplicate positions
    mov byte [mine_map + eax], 1
    inc ecx
    cmp ecx, MINE_COUNT
    jb .next_mine
    popad
    ret

; Seed EAX from the current hour, minute and second in the CMOS RTC.
seed_from_rtc:
.wait_rtc:
    mov al, 0x0A
    out 0x70, al
    in al, 0x71
    test al, 0x80                   ; wait until the RTC update is complete
    jnz .wait_rtc

    mov al, 0x00                    ; seconds
    out 0x70, al
    in al, 0x71
    movzx eax, al
    mov [random_seed], eax

    mov al, 0x02                    ; minutes
    out 0x70, al
    in al, 0x71
    movzx eax, al
    shl eax, 8
    xor [random_seed], eax

    mov al, 0x04                    ; hours
    out 0x70, al
    in al, 0x71
    movzx eax, al
    shl eax, 16
    xor [random_seed], eax
    ret

; Numerical Recipes LCG.  Returns the next pseudo-random value in EAX.
random_next:
    mov eax, [random_seed]
    imul eax, eax, 1664525
    add eax, 1013904223
    mov [random_seed], eax
    ret

print_board:
    pushad
    ; 右半分（39文字幅）だけを消去する。左半分の時計と中央の区切り線は
    ; そのまま残す。
    mov edi, PANEL_START
    mov ax, 0x0720
    mov ebp, 25
.clear_row:
    mov ecx, PANEL_WIDTH
    rep stosw
    add edi, 82                    ; skip the left panel and divider
    dec ebp
    jnz .clear_row

    mov edi, PANEL_START
    mov esi, controls_message
    call mswp_print_string
    mov edi, BOARD_OFFSET
    xor ebx, ebx
    mov ecx, 8
.pby:
    push ecx
    mov ecx, 8
.cell:
    mov al, '.'
    cmp byte [opened + ebx], 0
    je .color
    cmp byte [mine_map + ebx], 0
    jne .mine
    push ebx
    call count_near
    pop ebx
    add al, '0'
    jmp .color
.mine:
    mov al, '*'
.color:
    mov ah, 0x07
    cmp bl, [cursor]
    jne .write
    mov ah, 0x70                    ; selected square
.write:
    mov [edi], ax
    add edi, 2
    mov ax, 0x0720
    mov [edi], ax
    add edi, 2
    inc ebx
    loop .cell
    add edi, 128                    ; next 80-x text y
    pop ecx
    loop .pby
    mov edi, PANEL_START + 160 * 12
    cmp byte [game_state], 1
    je .clear
    cmp byte [game_state], 2
    je .over
    jmp .done
.clear:
    mov esi, clear_message
    call mswp_print_string
    jmp .gameend
.over:
    mov esi, over_message
    call mswp_print_string
.gameend:
    mov edi, PANEL_START + 160 * 13
    mov esi, end_message
    call mswp_print_string
    cmp byte [retry_prompt], 0
    je .quit_question
    mov edi, PANEL_START + 160 * 13
    mov esi, retry_message
    call mswp_print_string
.quit_question:
    cmp byte [quit_prompt], 0
    je .done
    mov edi, PANEL_START + 160 * 13
    mov esi, quit_message
    call mswp_print_string
.done:
    popad
    ret

; EBX = cell index. Returns its adjacent mine count in AL.
count_near:
    push ebx
    push ecx
    push edx
    push esi
    push ebp
    mov eax, ebx
    xor edx, edx
    mov esi, 8
    div esi
    mov [calc_y], al
    mov [calc_x], dl
    xor ebp, ebp
    mov ecx, -1
.cny:
    movzx eax, byte [calc_y]
    add eax, ecx
    js .next_cny
    cmp eax, 7
    jg .next_cny
    imul eax, eax, 8
    mov edx, -1
.cnx:
    movzx esi, byte [calc_x]
    add esi, edx
    js .next_cnx
    cmp esi, 7
    jg .next_cnx
    add esi, eax
    cmp esi, ebx
    je .next_cnx
    cmp byte [mine_map + esi], 0
    je .next_cnx
    inc ebp
.next_cnx:
    inc edx
    cmp edx, 1
    jle .cnx
.next_cny:
    inc ecx
    cmp ecx, 1
    jle .cny
    mov eax, ebp
    pop ebp
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

mswp_print_string:
    mov ah, 0x07
.loop:
    lodsb
    test al, al
    jz .done
    mov [edi], ax
    add edi, 2
    jmp .loop
.done:
    ret

controls_message db 'WASD: Move  Space: Open', 0
clear_message db 'GAME CLEAR!', 0
over_message  db 'GAME OVER!', 0
end_message   db 'Retry:r Quit:q', 0
retry_message db 'Do you want to retry? (Y/n)', 0
quit_message db 'Do you want to shutdown system? (Y/n)', 0
cursor        db 0
safe_opened   db 0
game_state    db 0
retry_prompt  db 0
quit_prompt  db 0
initialized   db 0
screen_dirty  db 0
calc_y        db 0
calc_x        db 0
random_seed   dd 0
opened        times 64 db 0
mine_map      times 64 db 0

times 2048-($-mswp_image_start) db 0
