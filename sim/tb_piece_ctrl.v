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
module tb_piece_ctrl;
  reg clk=0, reset=1, clk_game=0;
  reg btn_left=0, btn_right=0, btn_rotate=0, btn_down=0;
  reg spawn=0; reg [2:0] spawn_type=0;
  reg [199:0] occ_flat = 200'b0;
  wire signed [4:0] piece_col; wire [4:0] piece_row;
  wire [1:0] rotation; wire [2:0] piece_type;
  wire [15:0] shape_bitmap; wire [2:0] piece_color;
  wire piece_lock; wire spawn_blocked;

  always #5 clk=~clk;

  piece_ctrl uut(.clk(clk), .reset(reset), .clk_game(clk_game),
    .btn_left(btn_left), .btn_right(btn_right), .btn_rotate(btn_rotate), .btn_down(btn_down),
    .spawn(spawn), .spawn_type(spawn_type), .occ_flat(occ_flat),
    .piece_col(piece_col), .piece_row(piece_row), .rotation(rotation), .piece_type(piece_type),
    .shape_bitmap(shape_bitmap), .piece_color(piece_color),
    .piece_lock(piece_lock), .spawn_blocked(spawn_blocked));

  task press_spawn; begin @(posedge clk); spawn=1; @(posedge clk); spawn=0; end endtask
  task press_left;  begin @(posedge clk); btn_left=1; @(posedge clk); btn_left=0; end endtask
  task press_right; begin @(posedge clk); btn_right=1; @(posedge clk); btn_right=0; end endtask
  task press_rotate;begin @(posedge clk); btn_rotate=1; @(posedge clk); btn_rotate=0; end endtask
  task game_tick_pulse; begin clk_game=1; #20; clk_game=0; #20; end endtask

  integer i, lock_count;
  initial begin
    #22 reset=0;

    // TEST1: spawn O-piece
    spawn_type=3'd1; press_spawn; #10;
    $display("TEST1 Spawn: type=%0d col=%0d row=%0d (expect type=1 col=3 row=0)", piece_type,piece_col,piece_row);

    // TEST2: left-to-wall
    for(i=0;i<10;i=i+1) press_left; #10;
    $display("TEST2 Left-to-wall: col=%0d (expect -1)", piece_col);

    // TEST3: right-to-wall
    for(i=0;i<10;i=i+1) press_right; #10;
    $display("TEST3 Right-to-wall: col=%0d (expect 7)", piece_col);

    // TEST4: rotate T-piece
    spawn_type=3'd2; press_spawn; #10;
    $display("TEST4a T spawned: rot=%0d bmp=%b", rotation, shape_bitmap);
    press_rotate; #10;
    $display("TEST4b after rotate: rot=%0d bmp=%b (expect rot=1, different)", rotation, shape_bitmap);

    // TEST5: drop O-piece via game_tick until lock
    spawn_type=3'd1; press_spawn; #10;
    lock_count=0;
    for(i=0;i<25;i=i+1) begin
      game_tick_pulse;
      if(piece_lock) lock_count=lock_count+1;
    end
    $display("TEST5 Final row=%0d lock_count=%0d (expect row=17)", piece_row, lock_count);

    // TEST6: collision against locked cells - place a block at row10,col4/5
    spawn_type=3'd1; press_spawn; #10;
    occ_flat[(10*10+4)] = 1'b1;
    occ_flat[(10*10+5)] = 1'b1;
    #10;
    for(i=0;i<12;i=i+1) begin
      @(posedge clk); btn_down=1; @(posedge clk); btn_down=0; #10;
      $display("  down press %0d: row=%0d lock=%b", i, piece_row, piece_lock);
    end

    $display("All tests complete.");
    $finish;
  end
endmodule