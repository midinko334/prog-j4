; kernel.asm - PIT IRQ0 による2タスク・プリエンプティブスケジューラ
[ORG 0x1000]
[BITS 32]

CLOCK_IMAGE_TASK EQU 0x4000
GAME_IMAGE_TASK  EQU 0x5000
CLOCK_STACK_TOP  EQU 0x80000
; boot.asm が一時スタックに0x90000を使うため、ゲームは別の領域に置く。
GAME_STACK_TOP   EQU 0x70000
IDT              EQU 0x2000
VIDEO            EQU 0xB8000

; タスクとIRQ1が共有する小さなメールボックス。
CLOCK_KEY          EQU 0x3000
GAME_KEY           EQU 0x3001
SHUTDOWN_REQUESTED EQU 0x3002

%macro pic_out 1
    out %1, al
    out 0x80, al                    ; PICが直前のICWを反映するためのI/O wait
%endmacro

start:
    cld
    ; 画面初期化
    mov edi, 0xB8000
    mov ax, 0x0720
    mov ecx, 2000
    rep stosw
    call draw_divider
    mov edi, 0xB8000
    mov esi, startup_message
    call print_string

    ; ディスクイメージ内のタスクを、カーネルと重ならない実行領域へコピー。
    mov esi, clock_image
    mov edi, CLOCK_IMAGE_TASK
    mov ecx, clock_image_end - clock_image
    rep movsb
    mov esi, game_image
    mov edi, GAME_IMAGE_TASK
    mov ecx, game_image_end - game_image
    rep movsb

    mov byte [CLOCK_KEY], 0
    mov byte [GAME_KEY], 0
    mov byte [SHUTDOWN_REQUESTED], 0
    mov byte [active_panel], 0
    mov byte [alt_down], 0
    mov byte [extended_key], 0
    call draw_focus_marker

    call setup_idt
    call setup_pic_and_pit

    ; 各スタックには IRQ0 の popad / iretd が復元する初期コンテキストを置く。
    mov eax, CLOCK_IMAGE_TASK
    mov edi, CLOCK_STACK_TOP
    mov edx, task_esp
    call make_initial_context
    mov eax, GAME_IMAGE_TASK
    mov edi, GAME_STACK_TOP
    mov edx, task_esp + 4
    call make_initial_context
    mov byte [current_task], 0

    ; ここでstiを先に実行すると、タスク用ESPを設定する前にIRQ0が発生して
    ; カーネルのスタックを保存してしまう。初期フレームのEFLAGS(IF=1)を
    ; iretdで復元することで、最初のタスクへ移った時点から割り込みを有効化する。
    ; task_esp[0] は popad, iretd 用のフレーム先頭。最初の時計タスクを開始する。
    mov esp, [task_esp]
    popad
    iretd

; IRQ0: 実行中のESP（汎用レジスタとCPUのiretフレームを含む）を保存し、
; 次タスクのESPを復元する。タスクはretする必要がない。
irq_timer:
    pushad
    mov al, 0x20
    out 0x20, al
    cmp byte [SHUTDOWN_REQUESTED], 0
    jne shutdown
    movzx ebx, byte [current_task]
    mov [task_esp + ebx * 4], esp
    xor ebx, 1
    mov byte [current_task], bl     ; active_panel など隣接バイトを壊さない
    mov esp, [task_esp + ebx * 4]
    popad
    iretd

; IRQ1: キーは割り込みで一度だけ取得し、フォーカス中タスクのメールボックスへ渡す。
irq_keyboard:
    pushad
    in al, 0x60
    call route_scancode
    mov al, 0x20
    out 0x20, al
    popad
    iretd

route_scancode:
    cmp al, 0xE0
    je .extended
    cmp al, 0x38                    ; Alt make
    je .alt_down
    cmp al, 0xB8                    ; Alt break
    je .alt_up
    test al, 0x80
    jz .make_code
    mov byte [extended_key], 0
    ret
.extended:
    mov byte [extended_key], 1
    ret
.alt_down:
    mov byte [alt_down], 1
    mov byte [extended_key], 0
    ret
.alt_up:
    mov byte [alt_down], 0
    mov byte [extended_key], 0
    ret
.make_code:
    cmp byte [extended_key], 0
    je .plain_key
    mov byte [extended_key], 0
    cmp byte [alt_down], 0
    je .deliver              ; Alt無しの矢印は通常入力として配送
    cmp al, 0x4B              ; Alt+Left
    je .left
    cmp al, 0x4D              ; Alt+Right
    je .right
    jmp .deliver
.plain_key:
    cmp byte [alt_down], 0
    je .deliver
    cmp al, 0x4B
    je .left
    cmp al, 0x4D
    je .right
    jmp .deliver
.right:
    mov byte [active_panel], 1
    call draw_focus_marker
    ret
.left:
    mov byte [active_panel], 0
    call draw_focus_marker
    ret
.deliver:
    cmp byte [active_panel], 0
    jne .game
    mov [CLOCK_KEY], al
    ret
.game:
    mov [GAME_KEY], al
.done:
    ret

; EAX=開始EIP, EDI=スタック上端, EDX=保存先task_esp。
; 割り込みハンドラ末尾と同じ popad / iretd のフレームを作る。
make_initial_context:
    sub edi, 12
    mov [edi], eax                  ; EIP
    mov dword [edi + 4], 0x08       ; CS
    mov dword [edi + 8], 0x202      ; EFLAGS (IF=1)
    mov ecx, 8
.zero_registers:
    sub edi, 4
    mov dword [edi], 0
    loop .zero_registers
    mov [edx], edi
    ret

setup_idt:
    mov edi, IDT
    xor eax, eax
    mov ecx, 512
    rep stosd
    mov edi, IDT + 8 * 32
    mov eax, irq_timer
    call set_gate
    mov edi, IDT + 8 * 33
    mov eax, irq_keyboard
    call set_gate
    lidt [idt_descriptor]
    ret

; EDI=IDTエントリ, EAX=ハンドラアドレス
set_gate:
    mov [edi], ax
    mov word [edi + 2], 0x08
    mov byte [edi + 4], 0
    mov byte [edi + 5], 0x8E
    shr eax, 16
    mov [edi + 6], ax
    ret

setup_pic_and_pit:
    ; PICをIRQ0=INT 0x20、IRQ1=INT 0x21へリマップし、IRQ0/IRQ1だけ許可する。
    mov al, 0x11
    pic_out 0x20
    pic_out 0xA0
    mov al, 0x20
    pic_out 0x21
    mov al, 0x28
    pic_out 0xA1
    mov al, 0x04
    pic_out 0x21
    mov al, 0x02
    pic_out 0xA1
    mov al, 0x01
    pic_out 0x21
    pic_out 0xA1
    mov al, 0xFC
    pic_out 0x21
    mov al, 0xFF
    pic_out 0xA1

    ; PIT channel 0: 1193182 / 11932 ≒ 100Hz。
    mov al, 0x36
    out 0x43, al
    mov ax, 11932
    out 0x40, al
    mov al, ah
    out 0x40, al
    ret

draw_divider:
    mov edi, 0xB8000 + 80
    mov ax, 0x075C
    mov ecx, 25
.loop:
    mov [edi], ax
    add edi, 160
    loop .loop
    ret

; 最下行の * が、キーボード入力を受け取るペインを示す。
; 左端=時計、右端=ゲーム。IRQ1から呼んでもよいようにレジスタは呼出元が保存する。
draw_focus_marker:
    mov edi, VIDEO + 160 * 24
    mov ax, 0x0720
    mov [edi], ax
    mov [edi + 82], ax
    mov ax, 0x702A                  ; 反転表示の '*'
    cmp byte [active_panel], 0
    jne .game
    mov [edi], ax
    ret
.game:
    mov [edi + 82], ax
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

shutdown:
    cli
    mov edi, 0xB8000
    mov esi, shutdown_message
    call print_string
.halt:
    hlt
    jmp .halt

startup_message db 'Kernel Loaded', 0
shutdown_message db 'Kernel Finished', 0
current_task db 0
active_panel db 0
alt_down db 0
extended_key db 0
task_esp dd 0, 0
idt_descriptor:
    dw 2048 - 1
    dd IDT

; カーネルは2セクタ。後続のincbin配置もこのサイズに合わせる。
times 1024-($-$$) db 0
clock_image:
    incbin "Bin/clock.bin"
clock_image_end:
game_image:
    incbin "Bin/mswp.bin"
game_image_end:
