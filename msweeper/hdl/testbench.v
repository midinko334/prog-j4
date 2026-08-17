`timescale 1ns/1ps
module tb_minesweeper;
    reg clk = 0;
    reg btn_rst = 1;
    reg btn_new = 0;
    reg btn_open = 0;
    reg [2:0] sw_row = 0;
    reg [2:0] sw_col = 0;
    wire [6:0] seg;
    wire [2:0] scan_row, scan_col;
    wire led_win, led_lose;

    minesweeper_top dut (
        .sys_clk (clk),
        .btn_rst (btn_rst),
        .btn_new (btn_new),
        .btn_open(btn_open),
        .sw_row  (sw_row),
        .sw_col  (sw_col),
        .seg     (seg),
        .scan_row(scan_row),
        .scan_col(scan_col),
        .led_win (led_win),
        .led_lose(led_lose)
    );

    always #5 clk = ~clk; // 100MHz相当

    integer i, r, c;
    reg [5:0] mine_idx;
    reg [5:0] safe_idx;
    reg found_safe;

    task press_open;
        begin
            btn_open = 1;
            repeat (250000) @(posedge clk); // debounce時間より長く保持
            btn_open = 0;
            repeat (250000) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb_minesweeper);

        // リセット
        repeat (5) @(posedge clk);
        btn_rst = 0;

        // 地雷配置が終わるまで待つ（S_PLACE完了は十分な時間待てば良い）
        repeat (5000) @(posedge clk);

        $display("mine_bitmap = %064b", dut.u_core.mine_bitmap);
        $display("mines_placed count check (popcount):");
        begin : popcount_blk
            integer k, pc;
            pc = 0;
            for (k = 0; k < 64; k = k + 1)
                if (dut.u_core.mine_bitmap[k]) pc = pc + 1;
            $display("  -> %0d (expect 10)", pc);
        end

        // 安全なマスと地雷マスを1つずつ探す
        found_safe = 0;
        for (i = 0; i < 64; i = i + 1) begin
            if (!dut.u_core.mine_bitmap[i] && !found_safe) begin
                safe_idx = i;
                found_safe = 1;
            end
        end
        for (i = 0; i < 64; i = i + 1) begin
            if (dut.u_core.mine_bitmap[i]) mine_idx = i;
        end
        $display("safe_idx=%0d mine_idx=%0d", safe_idx, mine_idx);

        // 安全なマスを開く
        sw_row = safe_idx[5:3];
        sw_col = safe_idx[2:0];
        press_open();
        $display("after opening safe cell: opened_bmp[safe_idx]=%b game_over=%b",
                  dut.u_core.opened_bmp[safe_idx], led_win|led_lose);

        // 同じマスをもう一度開こうとしても無視されることを確認
        press_open();
        $display("re-open same cell (should be ignored), opened_count=%0d",
                  dut.u_core.opened_count);

        // 地雷マスを開いてゲームオーバーになることを確認
        sw_row = mine_idx[5:3];
        sw_col = mine_idx[2:0];
        press_open();
        $display("after opening mine cell: led_win=%b led_lose=%b", led_win, led_lose);

        // 表示スキャンが1周する間、地雷位置のコードが 'H'(4'hB) になっているか確認
        begin : check_disp
            integer t;
            reg seen_h;
            seen_h = 0;
            for (t = 0; t < 200000; t = t + 1) begin
                @(posedge clk);
                if ({dut.u_disp.scan_row, dut.u_disp.scan_col} == mine_idx &&
                    dut.u_disp.disp_code == 4'hB)
                    seen_h = 1;
            end
            $display("mine cell shows 'H' code after game over: %b", seen_h);
        end

        $display("TEST DONE");
        $finish;
    end
endmodule
