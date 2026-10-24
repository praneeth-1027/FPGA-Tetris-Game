`timescale 1ns/1ps

// ============================================================
// USE CASE 1: Piece movement, rotation, boundary rejection,
//             and landing/lock detection.
// DUT: piece_ctrl.v
//
// Suggested waveform signals:
//   spawn, spawn_type, btn_left, btn_rotate, btn_down,
//   piece_col, piece_row, rotation, moved, move_rejected,
//   piece_lock, spawn_blocked, shape_bitmap
// ============================================================
module tb_uc1_piece_control;

    reg clk = 1'b0;
    reg reset = 1'b0;
    reg clk_game = 1'b0;

    reg btn_left = 1'b0;
    reg btn_right = 1'b0;
    reg btn_rotate = 1'b0;
    reg btn_down = 1'b0;

    reg spawn = 1'b0;
    reg [2:0] spawn_type = 3'd0;
    reg [199:0] occ_flat = 200'b0;

    wire signed [4:0] piece_col;
    wire [4:0] piece_row;
    wire [1:0] rotation;
    wire [2:0] piece_type;
    wire [15:0] shape_bitmap;
    wire [2:0] piece_color;
    wire piece_lock;
    wire spawn_blocked;
    wire moved;
    wire move_rejected;

    piece_ctrl dut (
        .clk(clk),
        .reset(reset),
        .clk_game(clk_game),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_rotate(btn_rotate),
        .btn_down(btn_down),
        .spawn(spawn),
        .spawn_type(spawn_type),
        .occ_flat(occ_flat),
        .piece_col(piece_col),
        .piece_row(piece_row),
        .rotation(rotation),
        .piece_type(piece_type),
        .shape_bitmap(shape_bitmap),
        .piece_color(piece_color),
        .piece_lock(piece_lock),
        .spawn_blocked(spawn_blocked),
        .moved(moved),
        .move_rejected(move_rejected)
    );

    // 100 MHz FPGA clock
    always #5 clk = ~clk;

    task pulse_left;
    begin
        @(negedge clk); btn_left = 1'b1;
        @(negedge clk); btn_left = 1'b0;
        repeat (1) @(negedge clk);
    end
    endtask

    task pulse_rotate;
    begin
        @(negedge clk); btn_rotate = 1'b1;
        @(negedge clk); btn_rotate = 1'b0;
        repeat (1) @(negedge clk);
    end
    endtask

    task pulse_down;
    begin
        @(negedge clk); btn_down = 1'b1;
        @(negedge clk); btn_down = 1'b0;
        repeat (1) @(negedge clk);
    end
    endtask

    initial begin
        // Reset
        reset = 1'b1;
        repeat (3) @(posedge clk);
        reset = 1'b0;
        repeat (2) @(posedge clk);

        // ----------------------------------------------------
        // 1) Spawn a T piece (piece_type = 2)
        // ----------------------------------------------------
        @(negedge clk);
        spawn_type = 3'd2;
        spawn = 1'b1;
        @(negedge clk);
        spawn = 1'b0;

        // Allow the post-spawn collision check to complete
        repeat (3) @(posedge clk);

        // ----------------------------------------------------
        // 2) Successful left movement and rotation
        // ----------------------------------------------------
        pulse_left;
        pulse_rotate;

        // ----------------------------------------------------
        // 3) Keep moving left until the wall blocks movement.
        //    The final attempt should assert move_rejected.
        // ----------------------------------------------------
        repeat (6) pulse_left;

        // ----------------------------------------------------
        // 4) Accelerate the test by placing the piece close to
        //    the floor. This is TESTBENCH-ONLY state setup so the
        //    lock event can be observed without many drop cycles.
        // ----------------------------------------------------
        @(negedge clk);
        dut.piece_row = 5'd16;

        // A down request now collides with the floor and produces
        // a one-cycle piece_lock pulse.
        pulse_down;

        repeat (5) @(posedge clk);

        $display("UC1 FINAL: col=%0d row=%0d rot=%0d moved=%b rejected=%b lock=%b",
                 piece_col, piece_row, rotation, moved, move_rejected, piece_lock);
        $finish;
    end

endmodule
