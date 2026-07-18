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

    ; 左右のアプリ領域を区切る。各アプリはこの区切り線を越えて
    ; 描画しないため、同時に画面を更新しても互いの表示を壊さない。
    call draw_divider

    ; 旧版（ver0.7）と同じく、起動メッセージは左上に固定表示する。
    mov edi, 0xB8000
    mov esi, sttmsg
    call print_string

    ; タスクイメージは起動時に一度だけコピーする。以後は各タスク内の
    ; 状態（時計のメッセージ、ゲーム盤面など）を保ったまま呼び出す。
    cld
    mov esi, clock_image
    mov edi, 0x1200
    mov ecx, clock_image_end - clock_image
    rep movsb

    mov esi, minesweeper_image
    mov edi, 0x2000
    mov ecx, minesweeper_image_end - minesweeper_image
    rep movsb

    mov byte [active_panel], 0       ; 0=時計（左）、1=ゲーム（右）
.scheduler:
    call poll_key
    call route_key
    mov al, [clock_key]
    mov byte [clock_key], 0
    call CLOCK_TASK
    mov al, [game_key]
    mov byte [game_key], 0
    call MSWP_TASK
    cmp al, 1                       ; minesweeper requested shutdown
    je shutdown
    jmp .scheduler

    ; シャットダウン表示
shutdown:
    mov edi, 0xB8000                ; display the message on the first row
    mov esi, endmsg     ; msgアドレスを設定
    call print_string   ; 文字列表示ルーチンを呼び出し

    jmp halt            ; システム停止

; 80文字画面の中央（40文字目）に縦の区切り線を描く。
draw_divider:
    mov edi, 0xB8000 + 80
    mov ax, 0x0720 + '|'
    mov ecx, 25
.loop:
    mov [edi], ax
    add edi, 160
    loop .loop
    ret

; キーを一度だけ読み、フォーカス中のタスクへ渡す。
; Alt+← / Alt+→ はタスク切替専用のイベントとして扱う。
poll_key:
    in al, 0x64
    test al, 1
    jz .none
    in al, 0x60
    cmp al, 0xE0
    je .extended
    cmp al, 0x38                    ; Left Alt make
    je .alt_down
    cmp al, 0xB8                    ; Left Alt break
    je .alt_up
    test al, 0x80
    jz .make_code
    mov byte [extended_key], 0      ; E0 + break code
    jmp .none
.make_code:
    ret
.extended:
    mov byte [extended_key], 1
    jmp .none
.alt_down:
    mov byte [alt_down], 1
    jmp .none
.alt_up:
    mov byte [alt_down], 0
    jmp .none
.none:
    xor al, al
    ret

route_key:
    test al, al
    jz .done
    cmp byte [extended_key], 0
    je .deliver
    mov byte [extended_key], 0
    cmp byte [alt_down], 1
    jne .done
    cmp al, 0x4B                    ; Alt+Left
    je .left
    cmp al, 0x4D                    ; Alt+Right
    jne .done
    mov byte [active_panel], 1
    jmp .done
.left:
    mov byte [active_panel], 0
    jmp .done
.deliver:
    cmp byte [active_panel], 0
    jne .game
    mov [clock_key], al
    jmp .done
.game:
    mov [game_key], al
.done:
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
sttmsg db 'Kernel Loaded', 0
endmsg db 'Kernel Finished', 0 ; 表示文字列と文字列終端（NULL文字）
active_panel db 0
alt_down db 0
extended_key db 0
clock_key db 0
game_key db 0

; サイズ調整
times 512-($-$$) db 0   ; カーネル本体を先頭1セクタに調整

clock_image:
    incbin "Bin/clock.bin"
clock_image_end:

minesweeper_image:
    incbin "Bin/mswp.bin"
minesweeper_image_end:
