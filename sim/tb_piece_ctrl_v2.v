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
module tb_piece_ctrl_v2;
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

  task press_down; begin @(posedge clk); btn_down=1; @(posedge clk); btn_down=0; end endtask
  task drop_current;
    integer k; begin
      k=0;
      while(uut.state==0 && k<25) begin press_down; k=k+1; end
      #3000;
    end
  endtask

  integer i, c;
  initial begin
    #22 reset=0; #50;

    $display("TEST1 queue after init: n1=%b n2=%b n3=%b", n1,n2,n3);
    if (n1!==16'bx && n2!==16'bx && n3!==16'bx && n1!=n2 && n2!=n3)
      $display("  PASS: 3 distinct valid queue entries");
    else $display("  FAIL: queue not properly warmed up / duplicated");

    // TEST2: real line clear via occupancy-derived full_rows
    // manually fill row15 completely (10 cells) using the board_memory
    // write port via hierarchical poke through we/wr_* for realism,
    // by forcing cells directly (simulation-only, same technique used before)
    for (c=0;c<10;c=c+1) uut.bmem.cells[15*10+c]=3'd1;
    // occ must reflect this for full_rows to see it -- poke occ too
    for (c=0;c<10;c=c+1) uut.bmem.occ[15*10+c]=1'b1;
    #20;
    $display("TEST2 pre-check: mem_full_rows[15]=%b", uut.mem_full_rows[15]);

    drop_current; // any real drop triggers LOCK->LINE_CHK->CLEAR
    $display("TEST2 after drop: score(BCD)=%h lines=%0d (expect score=0100 lines=1)", score, lines_cleared);
    if (score==16'h0100 && lines_cleared==8'd1)
      $display("  PASS: real line clear + BCD score increment correct");
    else $display("  FAIL");

    // TEST3: high_score tracks & preserves across restart
    force uut.score = 16'h0450;
    #20; release uut.score; #20;
    $display("TEST3 score=%h high_score=%h", score, high_score);

    // Fill columns 0-8 only (col9 left EMPTY) so neither row is
    // complete -- avoids triggering an auto-clear, while still
    // covering the spawn area (any piece spawns around cols 2-7)
    for (i=0;i<9;i=i+1) begin
      uut.bmem.cells[0*10+i]=3'd1; uut.bmem.occ[0*10+i]=1'b1;
      uut.bmem.cells[1*10+i]=3'd1; uut.bmem.occ[1*10+i]=1'b1;
    end
    #50;
    drop_current;
    $display("TEST4 after filling top + drop: state=%0d game_over=%b", uut.state, game_over);
    if (game_over) $display("  PASS: real game-over fired");
    else $display("  FAIL: game_over did not fire");

    press_down; #500;
    $display("TEST5 after restart: state=%0d game_over=%b score=%h high_score=%h",
               uut.state, game_over, score, high_score);
    if (!game_over && score==16'h0000 && high_score==16'h0450)
      $display("  PASS: restart correct, high_score preserved");
    else $display("  FAIL");

    $finish;
  end
  initial begin #50_000_000; $display("WATCHDOG"); $finish; end
endmodule