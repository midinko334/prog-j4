; kernel.asm

[ORG 0x1000]            ; カーネルのロード先アドレス
[BITS 16]               ; 16ビットリアルモードで動作

; プログラムの開始点
start:
    mov ax, 0           ; セグメントレジスタを初期化
    mov ds, ax          ; データセグメントを設定
    mov es, ax          ; エクストラセグメントを設定

    ; 文字列表示
    mov si, msg         ; msgアドレスを設定
    call print_string   ; 文字列表示ルーチンを呼び出し

    jmp halt            ; システム停止

; 文字列表示ルーチン
print_string:
    mov ah, 0x0E        ; BIOSの文字出力機能 (テレタイプモード)を選択
.loop:
    lodsb               ; SIから1バイトをALに読み込み、SIを進める
    cmp al, 0           ; 文字列終端（NULL文字）をチェック
    je .done            ; 終了
    int 0x10            ; BIOS割り込みで文字を表示
    jmp .loop           ; 次の文字へ
.done:
    ret                 ; 呼び出し元に戻る

; システム停止
halt:
    cli                 ; 割り込みを無効化
    hlt                 ; CPUを停止
    jmp halt            ; hltから復帰した場合に備えてループ

; データ領域
msg db 'Kernel Start', 0  ; 表示文字列と文字列終端（NULL文字）

; サイズ調整
times 512-($-$$) db 0   ; 1セクタ（512バイト）に調整
