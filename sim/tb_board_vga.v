// ============================================================
// tb_board_vga.v
// Integration test: writes a few test cells into board_memory,
// then sweeps pixel_x/pixel_y across the playfield region and
// checks that vga_driver outputs sensible colors (non-black on
// filled cells, white on border, dark blue outside).
// ============================================================
`timescale 1ns/1ps

module tb_board_vga;

    reg clk25 = 0;
    always #20 clk25 = ~clk25; // 25 MHz

    reg reset = 1;

    // board_memory write port
    reg we = 0;
    reg [3:0] wr_col = 0;
    reg [4:0] wr_row = 0;
    reg [2:0] wr_color = 0;

    // board_memory <-> vga_driver
    wire [3:0] rd_col;
    wire [4:0] rd_row;
    wire [2:0] cell_color;

    // vga_driver inputs
    reg video_on = 1;
    reg [9:0] pixel_x = 0;
    reg [9:0] pixel_y = 0;
    wire [3:0] red, green, blue;

    // Piece overlay tied off (no falling piece) so this testbench
    // continues to exercise board-only rendering as before.
    reg signed [4:0] piece_col = 5'sd0;
    reg [4:0]        piece_row = 5'd0;
    reg [15:0]       shape_bitmap = 16'b0; // no bits set -> never overlays
    reg [2:0]        piece_color = 3'd0;

    board_memory bmem (
        .clk(clk25),
        .reset(reset),
        .we(we),
        .wr_col(wr_col),
        .wr_row(wr_row),
        .wr_color(wr_color),
        .rd_col(rd_col),
        .rd_row(rd_row),
        .rd_color(cell_color)
    );

    vga_driver vdrv (
        .clk25(clk25),
        .video_on(video_on),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .rd_col(rd_col),
        .rd_row(rd_row),
        .cell_color(cell_color),
        .piece_col(piece_col),
        .piece_row(piece_row),
        .shape_bitmap(shape_bitmap),
        .piece_color(piece_color),
        .red(red),
        .green(green),
        .blue(blue)
    );

    integer i;

    initial begin
        #50 reset = 0;
        #50;

        // Write a few test cells: bottom row filled with different colors
        we = 1;
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk25);
            wr_col = i;
            wr_row = 19;         // bottom row
            wr_color = (i % 7) + 1; // cycle through colors 1-7
        end
        @(posedge clk25);
        we = 0;

        #100;

        // ---- Check 1: pixel inside a filled cell (col=0,row=19) ----
        // OFFSET_X=240, OFFSET_Y=80, CELL_SIZE=16
        // row 19 -> rel_y = 19*16=304..319 -> pixel_y = 384..399, use 390 (avoid grid line)
        // col 0  -> rel_x = 0..15 -> pixel_x = 240..255, use 248
        pixel_x = 248;
        pixel_y = 390;
        #100;
        $display("Filled cell (col0,row19): RGB = %h %h %h (expect non-black, color1=I-piece cyan 0FF)", red, green, blue);

        // ---- Check 2: pixel in empty cell (col=0,row=0) ----
        pixel_x = 248;
        pixel_y = 88; // rel_y=8, row=0
        #100;
        $display("Empty cell (col0,row0): RGB = %h %h %h (expect black 000)", red, green, blue);

        // ---- Check 3: pixel on border ----
        pixel_x = 239; // just left of OFFSET_X=240
        pixel_y = 200;
        #100;
        $display("Border pixel: RGB = %h %h %h (expect white FFF)", red, green, blue);

        // ---- Check 4: pixel outside board & border (background) ----
        pixel_x = 10;
        pixel_y = 10;
        #100;
        $display("Background pixel: RGB = %h %h %h (expect dark blue 11A)", red, green, blue);

        // ---- Check 5: video_on = 0 should force black ----
        video_on = 0;
        pixel_x = 248;
        pixel_y = 390;
        #100;
        $display("video_on=0: RGB = %h %h %h (expect black 000)", red, green, blue);

        $display("Test complete.");
        $finish;
    end

endmodule