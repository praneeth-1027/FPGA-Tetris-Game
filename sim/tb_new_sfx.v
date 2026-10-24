`timescale 1ns/1ps
module tb_new_sfx;
  reg clk=0, reset=1, clk_game=0;
  reg btn_left=0, btn_right=0, btn_rotate=0, btn_down=0;
  wire [3:0] rd_col; wire [4:0] rd_row; wire [2:0] rd_color;
  reg [3:0] probe_col; reg [4:0] probe_row;
  wire signed [4:0] piece_col; wire [4:0] piece_row;
  wire [15:0] shape_bitmap; wire [2:0] piece_color;
  wire [15:0] n1,n2,n3; wire [2:0] c1,c2,c3;
  wire [15:0] score, high_score; wire [7:0] lines_cleared; wire game_over;
  wire sfx_lock, sfx_line_clear, sfx_move, sfx_move_rejected, sfx_new_high_score, sfx_restart;

  always #5 clk=~clk;

  board_ctrl uut(.clk(clk), .reset(reset), .clk_game(clk_game),
    .btn_left(btn_left), .btn_right(btn_right), .btn_rotate(btn_rotate), .btn_down(btn_down),
    .rd_col(probe_col), .rd_row(probe_row), .rd_color(rd_color),
    .piece_col(piece_col), .piece_row(piece_row), .shape_bitmap(shape_bitmap), .piece_color(piece_color),
    .next1_shape_bitmap(n1), .next1_piece_color(c1),
    .next2_shape_bitmap(n2), .next2_piece_color(c2),
    .next3_shape_bitmap(n3), .next3_piece_color(c3),
    .score(score), .high_score(high_score), .lines_cleared(lines_cleared), .game_over(game_over),
    .sfx_lock(sfx_lock), .sfx_line_clear(sfx_line_clear),
    .sfx_move(sfx_move), .sfx_move_rejected(sfx_move_rejected),
    .sfx_new_high_score(sfx_new_high_score), .sfx_restart(sfx_restart));

  task press_left;  begin @(posedge clk); btn_left=1; @(posedge clk); btn_left=0; end endtask
  task press_down; begin @(posedge clk); btn_down=1; @(posedge clk); btn_down=0; end endtask
  task drop_current;
    integer k; begin
      k=0;
      while(uut.state==0 && k<25) begin press_down; k=k+1; end
      #3000;
    end
  endtask

  integer i, c, move_count, reject_count;
  always @(posedge clk) begin
    if (sfx_move) move_count = move_count + 1;
    if (sfx_move_rejected) reject_count = reject_count + 1;
  end

  initial begin
    #22 reset=0; #500;
    move_count=0; reject_count=0;

    // ---- TEST 1: move left a few times (room to move), then push
    // into the wall (should start rejecting) ----
    for (i=0;i<2;i=i+1) press_left;
    #10;
    $display("TEST1a after 2 free left moves: move_count=%0d reject_count=%0d (expect 2,0)",
               move_count, reject_count);

    for (i=0;i<10;i=i+1) press_left; // push into the wall
    #10;
    $display("TEST1b after pushing into wall: move_count=%0d reject_count>=1=%b",
               move_count, reject_count >= 1);
    if (reject_count >= 1)
      $display("  PASS: wall bump correctly produced sfx_move_rejected");
    else
      $display("  FAIL");

    // ---- TEST 2: force a high score crossing and check sfx_new_high_score ----
    force uut.score = 16'h0100;
    force uut.high_score = 16'h0050;
    #20;
    $display("TEST2: sfx_new_high_score=%b (expect 1, since score 0100 > high_score 0050)",
               sfx_new_high_score);
    release uut.score; release uut.high_score;
    #20;

    // ---- TEST 3: restart produces sfx_restart ----
    for (c=0;c<9;c=c+1) begin  // leave col9 empty -- avoid auto-clear
      uut.bmem.cells[0*10+c]=3'd1; uut.bmem.occ[0*10+c]=1'b1;
      uut.bmem.cells[1*10+c]=3'd1; uut.bmem.occ[1*10+c]=1'b1;
    end
    #50;
    drop_current;
    $display("TEST3a game_over=%b (expect 1)", game_over);

    @(posedge clk); btn_down=1;
    #1 $display("TEST3b at restart press: sfx_restart=%b (expect 1)", sfx_restart);
    @(posedge clk); btn_down=0;

    $display("All new sfx tests complete.");
    $finish;
  end
  initial begin #2_000_000; $display("WATCHDOG"); $finish; end
endmodule