`timescale 1ns/1ps

// ============================================================
// USE CASE 2: Complete one row, clear it, and update score.
// DUT: board_ctrl.v + board_memory.v + piece_ctrl.v +
//      piece_gen.v + piece_rom.v
//
// Scenario:
//   - Bottom row is pre-filled except columns 3..6.
//   - A horizontal I-piece is placed at row 18, column 3.
//   - Soft-drop is requested; the floor blocks the next step,
//     so the piece locks and completes row 19.
//   - board_ctrl detects the full row, clears it, shifts rows,
//     increments lines_cleared, and adds 100 to BCD score.
//
// Suggested waveform signals:
//   fsm_state, btn_down, piece_row, piece_col, pc_piece_lock_mon,
//   mem_full_rows_mon, bottom_row_occ, bm_we_mon,
//   sfx_line_clear, score, lines_cleared, high_score
// ============================================================
module tb_uc2_line_clear_score;

    reg clk = 1'b0;
    reg reset = 1'b0;
    reg clk_game = 1'b0;

    reg btn_left = 1'b0;
    reg btn_right = 1'b0;
    reg btn_rotate = 1'b0;
    reg btn_down = 1'b0;

    reg [3:0] rd_col = 4'd0;
    reg [4:0] rd_row = 5'd0;
    wire [2:0] rd_color;

    wire signed [4:0] piece_col;
    wire [4:0] piece_row;
    wire [15:0] shape_bitmap;
    wire [2:0] piece_color;

    wire [15:0] next1_shape_bitmap;
    wire [2:0] next1_piece_color;
    wire [15:0] next2_shape_bitmap;
    wire [2:0] next2_piece_color;
    wire [15:0] next3_shape_bitmap;
    wire [2:0] next3_piece_color;

    wire [15:0] score;
    wire [15:0] high_score;
    wire [7:0] lines_cleared;
    wire game_over;

    wire sfx_lock;
    wire sfx_line_clear;
    wire sfx_move;
    wire sfx_move_rejected;
    wire sfx_new_high_score;
    wire sfx_restart;

    board_ctrl dut (
        .clk(clk),
        .reset(reset),
        .clk_game(clk_game),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_rotate(btn_rotate),
        .btn_down(btn_down),
        .rd_col(rd_col),
        .rd_row(rd_row),
        .rd_color(rd_color),
        .piece_col(piece_col),
        .piece_row(piece_row),
        .shape_bitmap(shape_bitmap),
        .piece_color(piece_color),
        .next1_shape_bitmap(next1_shape_bitmap),
        .next1_piece_color(next1_piece_color),
        .next2_shape_bitmap(next2_shape_bitmap),
        .next2_piece_color(next2_piece_color),
        .next3_shape_bitmap(next3_shape_bitmap),
        .next3_piece_color(next3_piece_color),
        .score(score),
        .high_score(high_score),
        .lines_cleared(lines_cleared),
        .game_over(game_over),
        .sfx_lock(sfx_lock),
        .sfx_line_clear(sfx_line_clear),
        .sfx_move(sfx_move),
        .sfx_move_rejected(sfx_move_rejected),
        .sfx_new_high_score(sfx_new_high_score),
        .sfx_restart(sfx_restart)
    );

    // Easy-to-add waveform aliases for important internal signals.
    wire [2:0]  fsm_state         = dut.state;
    wire        pc_piece_lock_mon = dut.pc_piece_lock;
    wire [19:0] mem_full_rows_mon = dut.mem_full_rows;
    wire        bm_we_mon         = dut.bm_we;
    wire [9:0]  bottom_row_occ    = dut.bmem.occ[199:190];

    // 100 MHz clock
    always #5 clk = ~clk;

    integer c;
    integer timeout;

    initial begin
        // Reset all game logic and board memory.
        reset = 1'b1;
        repeat (4) @(posedge clk);
        reset = 1'b0;

        // Wait for board_ctrl queue initialization to reach S_FALLING (0).
        timeout = 0;
        while ((fsm_state != 3'd0) && (timeout < 50)) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        if (fsm_state != 3'd0) begin
            $display("ERROR: board_ctrl did not reach S_FALLING");
            $finish;
        end

        // ----------------------------------------------------
        // TESTBENCH-ONLY setup:
        // Fill bottom row (row 19) except columns 3,4,5,6.
        // These four empty cells exactly match a horizontal I-piece.
        // ----------------------------------------------------
        @(negedge clk);
        for (c = 0; c < 10; c = c + 1) begin
            if ((c < 3) || (c > 6)) begin
                dut.bmem.cells[190 + c] = 3'b101;
                dut.bmem.occ[190 + c]   = 1'b1;
            end
        end

        // Put the active piece in the exact finishing position.
        // I-piece, rotation 0 = horizontal cells on local row 1.
        dut.pctrl.piece_type = 3'd0;
        dut.pctrl.rotation   = 2'd0;
        dut.pctrl.piece_col  = 5'sd3;
        dut.pctrl.piece_row  = 5'd18;

        repeat (2) @(posedge clk);

        // Request one downward move. The candidate position crosses
        // the floor, so piece_ctrl raises piece_lock.
        @(negedge clk); btn_down = 1'b1;
        @(negedge clk); btn_down = 1'b0;

        // Wait until the line-clear operation has completed.
        timeout = 0;
        while ((lines_cleared != 8'd1) && (timeout < 1000)) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        repeat (10) @(posedge clk);

        if ((lines_cleared == 8'd1) && (score == 16'h0100))
            $display("PASS UC2: Row cleared. score=%h lines=%0d", score, lines_cleared);
        else
            $display("FAIL UC2: score=%h lines=%0d state=%0d", score, lines_cleared, fsm_state);

        $finish;
    end

endmodule
