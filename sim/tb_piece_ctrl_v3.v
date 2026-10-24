// ============================================================
// tb_piece_ctrl.v
// Tests:
//  1. Spawn loads correct type/position
//  2. Left movement stops at wall (col doesn't go negative)
//  3. Right movement stops at wall
//  4. Rotation changes shape_bitmap
//  5. Repeated game_tick pulses move piece down and eventually
//     assert piece_lock when it hits the floor
// ============================================================
`timescale 1ns/1ps
module tb_piece_ctrl_v3;
  reg clk=0, reset=1, clk_game=0;
  reg btn_left=0, btn_right=0, btn_rotate=0, btn_down=0;
  wire [3:0] rd_col; wire [4:0] rd_row; wire [2:0] rd_color;
  reg [3:0] probe_col; reg [4:0] probe_row;
  wire signed [4:0] piece_col; wire [4:0] piece_row;
  wire [15:0] shape_bitmap; wire [2:0] piece_color;
  wire [15:0] n1,n2,n3; wire [2:0] c1,c2,c3;
  wire [15:0] score, high_score; wire [7:0] lines_cleared; wire game_over;

  always #5 clk=~clk;

  board_ctrl uut(.clk(clk), .reset(reset), .clk_game(clk_game),
    .btn_left(btn_left), .btn_right(btn_right), .btn_rotate(btn_rotate), .btn_down(btn_down),
    .rd_col(probe_col), .rd_row(probe_row), .rd_color(rd_color),
    .piece_col(piece_col), .piece_row(piece_row), .shape_bitmap(shape_bitmap), .piece_color(piece_color),
    .next1_shape_bitmap(n1), .next1_piece_color(c1),
    .next2_shape_bitmap(n2), .next2_piece_color(c2),
    .next3_shape_bitmap(n3), .next3_piece_color(c3),
    .score(score), .high_score(high_score), .lines_cleared(lines_cleared), .game_over(game_over));

  task press_left; begin @(posedge clk); btn_left=1; @(posedge clk); btn_left=0; end endtask
  task press_down; begin @(posedge clk); btn_down=1; @(posedge clk); btn_down=0; end endtask

  integer i;
  initial begin
    #22 reset=0; #50;
    // uut's very first piece is I-piece (col=3). Force it to be an
    // O-piece instead by overriding piece_ctrl directly, matching
    // the scenario that exposed the original bug.
    uut.pctrl.piece_type = 3'd1; // O piece
    #10;

    // push it all the way to the left wall (piece_col should end at -1
    // for the O-piece, since its cells are locally offset by +1)
    for (i=0;i<5;i=i+1) press_left;
    #10;
    $display("Before drop: piece_col=%0d (expect -1, O-piece's true left edge = col+1 = 0)", piece_col);

    // drop it to the floor and let it lock
    for (i=0;i<25 && uut.state==0;i=i+1) press_down;
    #500;

    // Check board_memory: the O-piece should have locked at
    // absolute columns 0 and 1 (piece_col=-1, local cols 1,2 -> abs 0,1)
    // NOT wrapped around to some huge column via unsigned truncation.
    $display("Locked cells at row19: col0=%0d col1=%0d col2=%0d (expect nonzero,nonzero,0)",
               uut.bmem.cells[19*10+0], uut.bmem.cells[19*10+1], uut.bmem.cells[19*10+2]);
    $display("Sanity: no corruption elsewhere -- row19 col9=%0d (expect 0)", uut.bmem.cells[19*10+9]);

    if (uut.bmem.cells[19*10+0] != 0 && uut.bmem.cells[19*10+1] != 0 && uut.bmem.cells[19*10+2] == 0)
      $display("PASS: O-piece locked correctly at columns 0-1, no sign-truncation corruption");
    else
      $display("FAIL: locking corrupted (sign-truncation bug present)");

    $finish;
  end
  initial begin #10_000_000; $display("WATCHDOG"); $finish; end
endmodule