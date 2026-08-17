// ============================================================
// minesweeper_all.v
//   mswp.asm のロジックを再現した8x8マインスイーパー FPGA実装
//   （全モジュールを1ファイルにまとめたもの）
//
//   構成:
//     seg7_decoder     : 7セグデコーダ(74LS47拡張, '-'と'H'対応)
//     rng_lcg           : 起動時シード + LCG擬似乱数(地雷配置用)
//     debounce          : ボタンのチャタリング除去
//     minesweeper_core  : ゲームロジック本体(盤面状態・FSM)
//     display_scan      : ダイナミック点灯(マルチプレクス)走査
//     minesweeper_top   : トップレベル(全体接続)
// ============================================================

// ============================================================
// seg7_decoder.v
//   74LS47 相当の BCD→7セグデコーダを拡張したもの。
//   0-8   : 数字表示（周囲の地雷数）
//   4'hA  : '-'  未開封セル
//   4'hB  : 'H'  ゲーム終了時に開示された地雷
//   それ以外の未使用コードは全消灯にしておく。
//
//   seg 出力は「アクティブLow」（0=点灯）のコモンアノード方式を想定。
//   コモンカソード基板の場合は呼び出し側で seg を反転させること。
//   セグメント並び : seg = {g,f,e,d,c,b,a}
// ============================================================
module seg7_decoder (
    input  wire [3:0] code,
    output reg  [6:0] seg   // {g,f,e,d,c,b,a}, active-low
);
    // 正論理（1=点灯）でパターンを定義してから最後に反転する
    reg [6:0] pat; // {g,f,e,d,c,b,a}

    always @(*) begin
        case (code)
            4'h0: pat = 7'b0111111; // 0
            4'h1: pat = 7'b0000110; // 1
            4'h2: pat = 7'b1011011; // 2
            4'h3: pat = 7'b1001111; // 3
            4'h4: pat = 7'b1100110; // 4
            4'h5: pat = 7'b1101101; // 5
            4'h6: pat = 7'b1111101; // 6
            4'h7: pat = 7'b0000111; // 7
            4'h8: pat = 7'b1111111; // 8 (周囲8マス全部地雷のケースもあり得る)
            4'hA: pat = 7'b1000000; // '-'  (gのみ点灯)
            4'hB: pat = 7'b1110110; // 'H'  (b,c,e,f,g点灯)
            default: pat = 7'b0000000; // 消灯
        endcase
        seg = ~pat; // active-low へ変換
    end
endmodule


// ============================================================
// rng_lcg.v
//   mswp.asm の地雷配置ロジックを再現する疑似乱数源。
//   asm:  lea ecx,[rcx+rcx*4+1]   ->  ecx = ecx*5 + 1  (LCG)
//         eax = ecx >> 26          ->  上位6bitを 0-63 の
//                                      マス番号として利用
//
//   ・フリーランカウンタ free_run を常時インクリメントしておき、
//     seed_load パルスが来た瞬間の値を初期シードとして採用する。
//     （電源投入/リセットのタイミングでばらつくので実用上十分）
//   ・以後は 1クロックごとに LCG を1ステップ進める。
// ============================================================
module rng_lcg (
    input  wire        clk,
    input  wire         rst,
    input  wire        seed_load,   // 1クロックだけ Highでシード取り込み
    input  wire        advance,     // 1クロックだけ Highで1ステップ進める
    output wire [5:0]  idx          // 現在のLCG値の上位6bit = 候補マス番号
);
    reg [31:0] free_run;
    reg [31:0] lcg_reg;

    // 常時フリーランするカウンタ（シード源）
    always @(posedge clk) begin
        if (rst) free_run <= 32'hACE1_2024;
        else     free_run <= free_run + 32'h1;
    end

    always @(posedge clk) begin
        if (rst) begin
            lcg_reg <= 32'h1;
        end else if (seed_load) begin
            // 全ビット0だとLCGが停留するので保険でORしておく
            lcg_reg <= free_run | 32'h1;
        end else if (advance) begin
            lcg_reg <= (lcg_reg << 2) + lcg_reg + 32'h1; // *5 + 1
        end
    end

    assign idx = lcg_reg[31:26];

endmodule


// ============================================================
// debounce.v
//   物理ボタン入力のチャタリング除去＋1クロック幅パルス生成。
//   DEBOUNCE_CYCLES 分だけ安定していたら確定させる方式。
// ============================================================
module debounce #(
    parameter DEBOUNCE_CYCLES = 200000 // 100MHz時で約2ms
) (
    input  wire clk,
    input  wire rst,
    input  wire btn_raw,
    output reg  pulse // 押下確定の瞬間だけ1クロックHigh
);
    localparam CW = $clog2(DEBOUNCE_CYCLES + 1);

    reg sync0, sync1;
    reg stable;
    reg [CW-1:0] cnt;
    reg stable_d;

    // 2段シンクロナイザ（メタステーブル対策）
    always @(posedge clk) begin
        if (rst) begin
            sync0 <= 1'b0;
            sync1 <= 1'b0;
        end else begin
            sync0 <= btn_raw;
            sync1 <= sync0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            cnt      <= 0;
            stable   <= 1'b0;
            stable_d <= 1'b0;
            pulse    <= 1'b0;
        end else begin
            if (sync1 == stable) begin
                cnt <= 0;
            end else begin
                cnt <= cnt + 1'b1;
                if (cnt >= DEBOUNCE_CYCLES) begin
                    stable <= sync1;
                    cnt    <= 0;
                end
            end
            stable_d <= stable;
            pulse    <= stable & ~stable_d; // 立ち上がりで1パルス
        end
    end
endmodule


// ============================================================
// minesweeper_core.v
//   mswp.asm のゲームロジックを Verilog で再現したコア。
//     - 8x8 = 64マス、地雷10個（asm: bl=10）
//     - index = row*8 + col                （asm: al = row<<3 + col）
//     - 既に開いたマスは再オープン不可         （asm: opened[]==1 チェック）
//     - 地雷を開くと即ゲームオーバー           （asm: bt r14,rax → jc gameend）
//     - 非地雷を全部開くと勝利 (54マス開示)    （asm: cmp r13d,54）
//     - フラッドフィル（連鎖オープン）は無し。asm も1マスずつのみ。
//
//   本コアはフラグ立て機能を持たない（asmにも無いため）。
// ============================================================
module minesweeper_core #(
    parameter MINE_COUNT = 10   // asm: mov bl,10
) (
    input  wire        clk,
    input  wire        rst,          // 電源投入リセット
    input  wire        new_game,     // 1クロックパルスで新規ゲーム開始
    input  wire        open_pulse,   // 1クロックパルスでセルを開く
    input  wire [2:0]  sel_row,
    input  wire [2:0]  sel_col,

    output reg  [63:0] mine_bitmap,  // 1=地雷
    output reg  [63:0] opened_bmp,   // 1=開封済み
    output reg         game_over,    // 勝敗確定でHigh（=asmのgameflag）
    output reg         win_flag,     // game_over時、勝ちなら1
    output wire [5:0]  scan_addr_dummy // 未使用（互換用に0固定）
);
    assign scan_addr_dummy = 6'd0;

    // ---------------- 状態機械 ----------------
    localparam S_SEED  = 3'd0,
               S_PLACE  = 3'd1,
               S_PLAY   = 3'd2,
               S_END    = 3'd3;

    reg [2:0] state;
    reg [3:0] mines_placed; // 0-10
    reg [6:0] opened_count; // 0-64 (勝利判定は54)

    // ---------------- 乱数生成 ----------------
    wire [5:0] rng_idx;
    reg        rng_seed_load, rng_advance;

    rng_lcg u_rng (
        .clk       (clk),
        .rst       (rst),
        .seed_load (rng_seed_load),
        .advance   (rng_advance),
        .idx       (rng_idx)
    );

    // ---------------- 隣接地雷数カウント（組合せ） ----------------
    // asm: count_near と同じ 3x3（中心除く）走査
    function [3:0] count_neighbors;
        input [2:0]  row, col;
        input [63:0] mines;
        integer dr, dc;
        integer nr, nc;
        reg [3:0] cnt;
        begin
            cnt = 0;
            for (dr = -1; dr <= 1; dr = dr + 1) begin
                for (dc = -1; dc <= 1; dc = dc + 1) begin
                    if (!(dr == 0 && dc == 0)) begin
                        nr = row + dr;
                        nc = col + dc;
                        if (nr >= 0 && nr <= 7 && nc >= 0 && nc <= 7) begin
                            if (mines[nr*8 + nc])
                                cnt = cnt + 1'b1;
                        end
                    end
                end
            end
            count_neighbors = cnt;
        end
    endfunction

    // 選択中セルの周囲地雷数（open_pulse処理には数値自体は不要だが
    // 表示側モジュールが同じ関数を使えるよう function 自体は export 相当）
    wire [5:0] open_idx = {sel_row, sel_col};

    // ---------------- メインFSM ----------------
    always @(posedge clk) begin
        if (rst) begin
            state         <= S_SEED;
            mine_bitmap   <= 64'd0;
            opened_bmp    <= 64'd0;
            mines_placed  <= 4'd0;
            opened_count  <= 7'd0;
            game_over     <= 1'b0;
            win_flag      <= 1'b0;
            rng_seed_load <= 1'b0;
            rng_advance   <= 1'b0;
        end else begin
            rng_seed_load <= 1'b0;
            rng_advance   <= 1'b0;

            case (state)
                // シード取り込み（1クロックだけ）してから配置開始
                S_SEED: begin
                    mine_bitmap   <= 64'd0;
                    opened_bmp    <= 64'd0;
                    mines_placed  <= 4'd0;
                    opened_count  <= 7'd0;
                    game_over     <= 1'b0;
                    win_flag      <= 1'b0;
                    rng_seed_load <= 1'b1;
                    state         <= S_PLACE;
                end

                // asm .place_loop の再現：重複したら捨てて再抽選
                S_PLACE: begin
                    rng_advance <= 1'b1; // 毎サイクル LCG を1歩進める
                    if (mines_placed == MINE_COUNT) begin
                        state <= S_PLAY;
                    end else if (!mine_bitmap[rng_idx]) begin
                        mine_bitmap[rng_idx] <= 1'b1;
                        mines_placed         <= mines_placed + 1'b1;
                    end
                    // 既に地雷ありなら何もせず次サイクルの新idxで再挑戦
                end

                // asm main_loop / .done 部分の再現
                S_PLAY: begin
                    if (open_pulse) begin
                        if (opened_bmp[open_idx]) begin
                            // asm: cmp opened,1; je main_loop -> 無視
                        end else if (mine_bitmap[open_idx]) begin
                            // asm: bt r14,rax; jc .gameend -> 敗北
                            game_over <= 1'b1;
                            win_flag  <= 1'b0;
                            state     <= S_END;
                        end else begin
                            // asm: opened[idx]=1; inc r13d
                            opened_bmp[open_idx] <= 1'b1;
                            if (opened_count + 1'b1 == (64 - MINE_COUNT)) begin
                                // asm: cmp r13d,54; je 相当（勝利）
                                game_over    <= 1'b1;
                                win_flag     <= 1'b1;
                                state        <= S_END;
                                opened_count <= opened_count + 1'b1;
                            end else begin
                                opened_count <= opened_count + 1'b1;
                            end
                        end
                    end
                end

                // ゲーム終了：new_game待ち
                S_END: begin
                    // 表示は game_over=1 のまま維持
                end

                default: state <= S_SEED;
            endcase

            if (new_game) begin
                state <= S_SEED;
            end
        end
    end

endmodule


// ============================================================
// display_scan.v
//   8x8=64個の7セグメントを、共有の BCD/HEX→7seg デコーダ1個で
//   ダイナミック点灯（マルチプレクス）する走査回路。
//
//   scan_row[2:0], scan_col[2:0] は外部の 3-to-8 デコーダ
//   （74138等）2個に接続し、64個の桁のうち1桁だけを選択して
//   コモン端子をアクティブにする想定。segは7本を全桁で共有配線する。
//
//   表示コード（4bit）の意味:
//     0-8   : 開封済みセルの周囲地雷数
//     4'hA  : '-'  未開封セル
//     4'hB  : 'H'  ゲーム終了時の地雷セル
// ============================================================
module display_scan #(
    parameter REFRESH_DIV = 2000 // 1桁あたりの点灯クロック分周比
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [63:0] mine_bitmap,
    input  wire [63:0] opened_bmp,
    input  wire        game_over,

    output reg  [2:0]  scan_row,   // 現在点灯中の行 (0-7)
    output reg  [2:0]  scan_col,   // 現在点灯中の列 (0-7)
    output wire [3:0]  disp_code,  // seg7_decoder への入力コード
    output wire        digit_en    // 現在桁の点灯許可（常時1でも可）
);
    localparam DIVW = $clog2(REFRESH_DIV);
    reg [DIVW-1:0] div_cnt;
    reg [5:0]      scan_addr;

    always @(posedge clk) begin
        if (rst) begin
            div_cnt   <= 0;
            scan_addr <= 0;
        end else if (div_cnt == REFRESH_DIV - 1) begin
            div_cnt   <= 0;
            scan_addr <= scan_addr + 1'b1; // 0->63->0 ... 全桁を巡回
        end else begin
            div_cnt <= div_cnt + 1'b1;
        end
    end

    always @(*) begin
        scan_row = scan_addr[5:3];
        scan_col = scan_addr[2:0];
    end

    // asm count_near と同一ロジックの隣接地雷数カウント（組合せ回路）
    function [3:0] count_neighbors;
        input [2:0]  row, col;
        input [63:0] mines;
        integer dr, dc;
        integer nr, nc;
        reg [3:0] cnt;
        begin
            cnt = 0;
            for (dr = -1; dr <= 1; dr = dr + 1) begin
                for (dc = -1; dc <= 1; dc = dc + 1) begin
                    if (!(dr == 0 && dc == 0)) begin
                        nr = row + dr;
                        nc = col + dc;
                        if (nr >= 0 && nr <= 7 && nc >= 0 && nc <= 7) begin
                            if (mines[nr*8 + nc])
                                cnt = cnt + 1'b1;
                        end
                    end
                end
            end
            count_neighbors = cnt;
        end
    endfunction

    wire       cur_opened = opened_bmp[scan_addr];
    wire       cur_mine   = mine_bitmap[scan_addr];
    wire [3:0] cur_count  = count_neighbors(scan_row, scan_col, mine_bitmap);

    assign disp_code = cur_opened            ? cur_count :
                        (game_over & cur_mine) ? 4'hB :   // H
                                                  4'hA;    // -

    assign digit_en = 1'b1; // 常時点灯（消灯制御が必要な場合は別途組合せ）

endmodule


// ============================================================
// minesweeper_top.v
//   FPGAボード想定のトップモジュール。
//   ・sys_clk    : ボード基準クロック（例: 100MHz）
//   ・btn_rst    : 全体リセット（新規ゲーム開始も兼ねる場合は new_game に接続可）
//   ・btn_new    : 新規ゲームボタン
//   ・btn_open   : 選択セルを開くボタン
//   ・sw_row/col : 開きたいセルの行/列選択スイッチ (asmの入力2桁に相当)
//   ・seg[6:0]   : 7セグ共有バス（active-low）
//   ・scan_row/col : 外部3-to-8デコーダへの桁選択出力
//   ・led_win/led_lose : 勝敗表示LED
// ============================================================
module minesweeper_top (
    input  wire       sys_clk,
    input  wire       btn_rst,
    input  wire       btn_new,
    input  wire       btn_open,
    input  wire [2:0] sw_row,
    input  wire [2:0] sw_col,

    output wire [6:0] seg,        // {g,f,e,d,c,b,a}, active-low
    output wire [2:0] scan_row,
    output wire [2:0] scan_col,
    output wire       led_win,
    output wire       led_lose
);
    // ---------------- リセット・ボタン処理 ----------------
    wire rst = btn_rst;

    wire new_game_pulse;
    wire open_pulse;

    debounce #(.DEBOUNCE_CYCLES(200000)) u_deb_new (
        .clk(sys_clk), .rst(rst), .btn_raw(btn_new), .pulse(new_game_pulse)
    );

    debounce #(.DEBOUNCE_CYCLES(200000)) u_deb_open (
        .clk(sys_clk), .rst(rst), .btn_raw(btn_open), .pulse(open_pulse)
    );

    // ---------------- ゲームロジック本体 ----------------
    wire [63:0] mine_bitmap;
    wire [63:0] opened_bmp;
    wire        game_over;
    wire        win_flag;

    minesweeper_core #(.MINE_COUNT(10)) u_core (
        .clk         (sys_clk),
        .rst         (rst),
        .new_game    (new_game_pulse),
        .open_pulse  (open_pulse),
        .sel_row     (sw_row),
        .sel_col     (sw_col),
        .mine_bitmap (mine_bitmap),
        .opened_bmp  (opened_bmp),
        .game_over   (game_over),
        .win_flag    (win_flag),
        .scan_addr_dummy ()
    );

    assign led_win  = game_over &  win_flag;
    assign led_lose = game_over & ~win_flag;

    // ---------------- 表示（ダイナミック点灯） ----------------
    wire [3:0] disp_code;
    wire       digit_en;

    display_scan #(.REFRESH_DIV(2000)) u_disp (
        .clk         (sys_clk),
        .rst         (rst),
        .mine_bitmap (mine_bitmap),
        .opened_bmp  (opened_bmp),
        .game_over   (game_over),
        .scan_row    (scan_row),
        .scan_col    (scan_col),
        .disp_code   (disp_code),
        .digit_en    (digit_en)
    );

    // 7セグデコーダは全64桁で共有（マルチプレクス方式なので1個で足りる）
    seg7_decoder u_seg (
        .code (disp_code),
        .seg  (seg)
    );

endmodule

