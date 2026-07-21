; boot.asm

[ORG 0x7C00]            ; ブートセクタのロード先アドレス
[BITS 16]               ; 16ビットリアルモードで動作

; プログラムの開始点
start:
    mov ax, 0           ; セグメントレジスタを初期化
    mov ds, ax          ; データセグメントを設定

    ; 画面クリア
    mov ax, 0xB800      ; VGAセグメント
    mov es, ax          ; エクストラセグメントを設定
    mov bx, 0x0000      ; オフセットを初期化
    mov ax, 0x0720      ; al: スペース（0x20）、ah: 属性（0x07: 白文字/黒背景）
    mov cx, 2000        ; カウンタレジスタを設定（80x25文字）
clear_loop:
    mov [es:bx], ax     ; ビデオメモリに書き込み
    add bx, 2           ; 次の位置へ
    loop clear_loop     ; CX をデクリメントし、0 になるまで繰り返し

    ; 文字列表示
    mov ax, 0xB800      ; VGAセグメント
    mov es, ax          ; エクストラセグメントを設定
    mov bx, 0x0000      ; オフセットを初期化
    mov si, msg         ; msgアドレスを設定
    mov ah, 0x07        ; 属性（0x07: 白文字/黒背景）を設定

; 文字列表示ループ
print_loop:
    lodsb               ; SIから1バイトをALに読み込み、SIを進める
    cmp al, 0           ; 文字列終端（NULL文字）をチェック
    je halt             ; 終了
    mov [es:bx], ax     ; ビデオメモリに書き込み
    add bx, 2           ; 次の位置へ
    jmp print_loop      ; 次の文字へ

; システム停止
halt:
    cli                 ; 割り込みを無効化
    hlt                 ; CPUを停止
    jmp halt            ; hltから復帰した場合に備えてループ

; データ領域
msg:
    db "HelloWorld", 0  ; 表示文字列と文字列終端（NULL文字）

; ブートセクタの調整と署名
times 510-($-$$) db 0   ; 残りをゼロ埋めし、全体を512バイトにする
dw 0xAA55               ; ブートセクタの署名
