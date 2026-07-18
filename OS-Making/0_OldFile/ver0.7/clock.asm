; clock.asm
[ORG 0x1200]
[BITS 32]

start:
    ; I/O起動
    in al, dx
    out dx, al

    call main_loop
    call newline

    ret     ; kernel に戻る

main_loop:
    mov edi, 0xB8000+160

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

    call delay

    jmp main_loop

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

; 改行
newline:
    mov eax, edi
    sub eax, 0xB8000
    mov ebx, 160        ; 1行のバイト数
    xor edx, edx
    div ebx             ; eax = 現在の行番号
    inc eax             ; 次の行へ
    mul ebx
    add eax, 0xB8000
    mov edi, eax
    ret


delay:
    mov ecx, 0x5FFFFF
.loop:
    loop .loop
    ret

; データ領域
rtc_sec  db 0
rtc_min  db 0
rtc_hour db 0

times 512-($-$$) db 0   ; 1セクタ（512バイト）に調整
