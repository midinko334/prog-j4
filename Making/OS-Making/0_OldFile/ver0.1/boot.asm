; boot.asm

[ORG 0x7C00]            ; ブートセクタのロード先アドレス
[BITS 16]               ; 16ビットリアルモードで動作

; 定数定義
KERNEL_OFFSET EQU 0x1000  ; カーネルのロード先アドレス
SECTOR_COUNT  EQU 1       ; 読み込むセクタ数
START_SECTOR  EQU 2       ; 開始セクタ番号
CYLINDER_NUM  EQU 0       ; シリンダ番号
HEAD_NUM      EQU 0       ; ヘッド番号

; プログラムの開始点
start:
    mov ax, 0           ; セグメントレジスタを初期化
    mov ds, ax          ; データセグメントを設定
    mov es, ax          ; エクストラセグメントを設定
    mov ss, ax          ; スタックセグメントを設定
    mov sp, 0x7C00      ; スタックポインタを設定

    mov [boot_drive], dl  ; ブートドライブ番号を保存

    ; ディスクからカーネルを読み込む
    mov ah, 0x02           ; BIOSのディスク読み込み機能を選択
    mov al, SECTOR_COUNT   ; 読み込むセクタ数
    mov bx, KERNEL_OFFSET  ; 読み込み先アドレス
    mov ch, CYLINDER_NUM   ; シリンダ番号
    mov cl, START_SECTOR   ; 開始セクタ番号
    mov dh, HEAD_NUM       ; ヘッド番号
    mov dl, [boot_drive]   ; ドライブ番号
    int 0x13               ; BIOS割り込みでディスク読み込み
    jc disk_error          ; キャリーフラグ（CF）が立っていたらエラー処理へ

    ; カーネル移行準備
    cli                 ; 割り込みを無効化
    mov ax, 0x2401      ; A20ラインを有効化
    int 0x15            ; BIOS割り込みでA20ラインを有効化
    sti                 ; 割り込みを有効化
    jc a20_error        ; キャリーフラグ（CF）が立っていたらエラー処理へ

    jmp KERNEL_OFFSET   ; カーネルへジャンプ

; ディスク読み込みエラー処理
disk_error:
    mov si, disk_err_msg  ; エラーメッセージのアドレスを設定
    call print_string   ; 文字列表示ルーチンを呼び出し
    jmp halt            ; システム停止

; A20エラー処理
a20_error:
    mov si, a20_err_msg  ; エラーメッセージのアドレスを設定
    call print_string   ; 文字列表示ルーチンを呼び出し
    jmp halt            ; システム停止

; 文字列表示ルーチン
print_string:
    mov ah, 0x0E        ; BIOSの文字出力機能 (テレタイプモード)を選択
.loop:
    lodsb               ; SIから1バイトをALに読み込み、SIを進める
    cmp al, 0           ; 文字列終端（NULL文字）をチェック
    je .done            ; 終端ならルーチン終了
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
boot_drive   db 0       ; ブートドライブ番号
disk_err_msg db "Disk read error!", 0  ; ディスク読み込みエラーメッセージ
a20_err_msg  db "A20 enable failed!", 0  ; A20エラーメッセージ

; ブートセクタの調整と署名
times 510-($-$$) db 0   ; 残りをゼロ埋めし、全体を512バイトにする
dw 0xAA55               ; ブートセクタの署名
