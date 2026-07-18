; boot.asm

[ORG 0x7C00]            ; ブートセクタのロード先アドレス
[BITS 16]               ; 16ビットリアルモードで動作

start:
    mov ax, 0           ; セグメントレジスタを初期化
    mov ds, ax          ; データセグメントを設定
    mov es, ax          ; エクストラセグメントを設定
    mov si, msg         ; msgアドレスを設定
    mov ah, 0x0E        ; BIOSの文字出力機能 (テレタイプモード)を選択

print_loop:
    lodsb               ; [si] から1バイト読み込んで al に格納し、si を進める
    cmp al, 0           ; 文字が 0（終端）かどうか確認
    je halt             ; 0 なら表示終了、halt へ

    int 0x10            ; BIOS割り込みで文字を表示
    jmp print_loop      ; 終端になるまで繰り返す

; システム停止
halt:
    cli                 ; 割り込みを無効化
    hlt                 ; CPUを停止
    jmp halt            ; hltから復帰した場合に備えてループ

; 表示したい文字列（最後に終端を表す 0 を置く）
msg db 'Test', 0

; ブートセクタの調整と署名
times 510-($-$$) db 0   ; 残りをゼロ埋めし、全体を512バイトにする
dw 0xAA55               ; ブートセクタの署名
