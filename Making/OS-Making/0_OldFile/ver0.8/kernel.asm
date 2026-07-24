; kernel.asm

[ORG 0x1000]            ; カーネルのロード先アドレス
[BITS 32]               ; 32ビットプロテクトモード

CLOCK_TASK EQU 0x1200
MSWP_TASK  EQU 0x2000

; プログラムの開始点
start:

    ; 画面クリア
    mov edi, 0xB8000    ; ビデオメモリの開始アドレス
    mov ax, 0x0720      ; al: スペース（0x20）、ah: 属性（0x07: 白文字/黒背景）
    mov ecx, 2000       ; カウンタレジスタを設定（80x25文字）
    rep stosw           ; AXをECX回EDIに書き込み、EDIをインクリメント

    ; 起動表示
    mov edi, 0xB8000    ; ビデオメモリの開始アドレス
    mov esi, sttmsg     ; msgアドレスを設定
    call print_string   ; 文字列表示ルーチンを呼び出し
    call newline

    ; 時計を実行用アドレスへコピーする。
    cld
    mov esi, clock_image
    mov edi, 0x1200
    mov ecx, clock_image_end - clock_image
    rep movsb

    ; 組み込みアプリを実行用アドレスへコピーする。
    cld
    mov esi, minesweeper_image
    mov edi, 0x2000
    mov ecx, minesweeper_image_end - minesweeper_image
    rep movsb
    ; 各タスクは短時間で制御を返す。カーネルが交互に実行することで、
    ; 時計とゲームを協調的にマルチタスク実行する。
.scheduler:
    call CLOCK_TASK
    call MSWP_TASK
    jmp .scheduler

    ; シャットダウン表示
    mov esi, endmsg     ; msgアドレスを設定
    call print_string   ; 文字列表示ルーチンを呼び出し

    jmp halt            ; システム停止


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
endmsg db 'Kernel Finshed', 0  ; 表示文字列と文字列終端（NULL文字）

; サイズ調整
times 512-($-$$) db 0   ; カーネル本体を先頭1セクタに調整

; ローダを使わず、カーネルに同梱した各イメージを上でコピーする。
clock_image:
    incbin "Bin/clock.bin"
clock_image_end:

minesweeper_image:
    incbin "Bin/mswp.bin"
minesweeper_image_end:
