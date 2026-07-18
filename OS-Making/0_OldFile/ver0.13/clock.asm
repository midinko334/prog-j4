; clock.asm
[ORG 0x1200]
[BITS 32]

VIDEO       EQU 0xB8000
PANEL_START EQU VIDEO               ; left panel (columns 0-39)
PANEL_WIDTH EQU 40

; 0x1200 に配置され、呼び出し元へ戻る時計更新ルーチン。
; 左半分だけを書き換えるので、右半分のゲーム表示を壊さない。
clock_update:
    pushad
    cld

    ; AL はカーネルがフォーカス中の時計へ渡したキー。どの入力でも
    ; 3 秒間だけ作業中メッセージを表示する。
    test al, al
    jz .read_clock
    mov byte [working], 1
    mov byte [new_input], 1
    mov byte [screen_dirty], 1
.read_clock:

    call read_rtc       ; 時計読み込み
    mov al, [rtc_hour]
    call bcd_to_bin
    mov [rtc_hour], al

    mov al, [rtc_min]
    call bcd_to_bin
    mov [rtc_min], al

    mov al, [rtc_sec]
    call bcd_to_bin
    mov [rtc_sec], al

    cmp byte [working], 0
    je .check_second
    cmp byte [new_input], 0
    je .check_second
    ; 入力を受けた時刻 + 3 秒を期限にする。
    mov al, [rtc_sec]
    add al, 3
    cmp al, 60
    jb .save_deadline
    sub al, 60
.save_deadline:
    mov [working_until], al
    mov byte [new_input], 0

.check_second:
    mov al, [rtc_sec]
    cmp al, [last_displayed_sec]
    je .draw_if_dirty
    mov [last_displayed_sec], al
    mov byte [screen_dirty], 1

    cmp byte [working], 0
    je .draw_if_dirty
    cmp al, [working_until]
    jne .draw_if_dirty
    mov byte [working], 0

.draw_if_dirty:
    cmp byte [screen_dirty], 0
    je .done
    mov byte [screen_dirty], 0

    ; 起動メッセージがある先頭行は残し、時計を表示する2行目だけを消す。
    mov edi, PANEL_START + 160
    mov ax, 0x0720
    mov ecx, PANEL_WIDTH
    rep stosw
    mov edi, PANEL_START + 160

    cmp byte [working], 0
    jne .working_message

    mov al, [rtc_hour]  ; 時計表示
    call print_dec_byte

    mov al, ':'
    mov ah, 0x07
    mov [edi], ax
    add edi, 2

    mov al, [rtc_min]
    call print_dec_byte

    mov al, ':'
    mov ah, 0x07
    mov [edi], ax
    add edi, 2

    mov al, [rtc_sec]
    call print_dec_byte
    jmp .done

.working_message:
    mov esi, working_message
    call print_string

.done:
    popad
    ret

wait_rtc:
    mov al, 0x0A
    out 0x70, al
.wait:
    in  al, 0x71
    test al, 0x80
    jnz .wait
    ret

read_rtc:
    call wait_rtc

    ; 秒
    mov al, 0x00
    out 0x70, al
    in  al, 0x71
    mov [rtc_sec], al

    ; 分
    mov al, 0x02
    out 0x70, al
    in  al, 0x71
    mov [rtc_min], al

    ; 時
    mov al, 0x04
    out 0x70, al
    in  al, 0x71
    mov [rtc_hour], al

    ret

bcd_to_bin:
    ; AL = BCD値
    push ebx

    mov bl, al
    and bl, 0x0F        ; 下位

    mov bh, al
    shr bh, 4           ; 上位

    movzx eax, bh
    imul eax, eax, 10   ; 上位×10
    add al, bl          ; +下位

    pop ebx
    ret

print_dec_byte:
    push eax
    push ebx

    mov ah, 0
    mov bl, 10
    div bl          ; AL=十の位, AH=一の位

    mov bh, ah      ; 一の位を退避

    ; 十の位表示
    add al, '0'
    mov ah, 0x07
    mov [edi], ax
    add edi, 2

    ; 一の位表示
    mov al, bh
    add al, '0'
    mov ah, 0x07
    mov [edi], ax
    add edi, 2

    pop ebx
    pop eax
    ret

print_string:
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

; データ領域
rtc_sec  db 0
rtc_min  db 0
rtc_hour db 0
last_displayed_sec db 0xFF
working db 0
working_until db 0
screen_dirty db 1
new_input db 0
working_message db 'still working!', 0

times 512-($-$$) db 0   ; 1セクタ（512バイト）に調整
