; kernel.asm

[ORG 0x1000]            ; カーネルのロード先アドレス
[BITS 32]               ; 32ビットプロテクトモード

; プログラムの開始点
start:
    ; I/O起動
    in al, dx
    out dx, al

    ; 画面クリア
    mov edi, 0xB8000    ; ビデオメモリの開始アドレス
    mov ax, 0x0720      ; al: スペース（0x20）、ah: 属性（0x07: 白文字/黒背景）
    mov ecx, 2000       ; カウンタレジスタを設定（80x25文字）
    rep stosw           ; AXをECX回EDIに書き込み、EDIをインクリメント

    ; 文字列表示
    mov edi, 0xB8000    ; ビデオメモリの開始アドレス
    mov esi, sttmsg     ; msgアドレスを設定
    call print_string   ; 文字列表示ルーチンを呼び出し
    call newline

    call main_loop
    call newline

    mov esi, endmsg     ; msgアドレスを設定
    call print_string   ; 文字列表示ルーチンを呼び出し
    call read_rtc


    jmp halt            ; システム停止

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

; 文字列表示ルーチン
print_string:
    mov ah, 0x07        ; 属性（0x07: 白文字/黒背景）を設定
.loop:
    lodsb               ; SIから1バイトをALに読み込み、SIを進める
    cmp al, 0           ; 文字列終端（NULL文字）をチェック
    je .done            ; 終了
    mov [edi], ax       ; ビデオメモリに書き込み
    add edi, 2          ; 次の位置へ
    jmp .loop           ; 次の文字へ
.done:
    ret                 ; 呼び出し元に戻る

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

; システム停止
halt:
    cli                 ; 割り込みを無効化
    hlt                 ; CPUを停止
    jmp halt            ; hltから復帰した場合に備えてループ

; データ領域
sttmsg db 'Kernel Loaded!', 0  ; 表示文字列と文字列終端（NULL文字）
rtc_sec  db 0
rtc_min  db 0
rtc_hour db 0
endmsg db 'Kernel Finshed', 0  ; 表示文字列と文字列終端（NULL文字）

; サイズ調整
times 512-($-$$) db 0   ; 1セクタ（512バイト）に調整
