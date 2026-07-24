; clock.asm
[ORG 0x1200]
[BITS 32]

; 0x1200 に配置され、呼び出し元へ戻る時計更新ルーチン。
; 画面の先頭行だけを書き換えるので、2行目以降のアプリ表示を壊さない。
clock_update:
    pushad
    cld

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

    ; カーネルはこのルーチンを高速に繰り返し呼び出す。RTC の秒が
    ; 変わっていない間は画面に触れないことで、消去と再描画による
    ; 点滅を防ぐ。
    cmp al, [last_displayed_sec]
    je .done
    mov [last_displayed_sec], al

    mov edi, 0xB8000
    mov ax, 0x0720
    mov ecx, 80
    rep stosw
    mov edi, 0xB8000

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

; データ領域
rtc_sec  db 0
rtc_min  db 0
rtc_hour db 0
last_displayed_sec db 0xFF

times 512-($-$$) db 0   ; 1セクタ（512バイト）に調整
