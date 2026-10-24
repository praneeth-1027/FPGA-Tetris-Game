`timescale 1ns/1ps
module tb_capture_frame;
  reg clk_in = 0;
  reg btn_reset = 1;
  reg btn_left_raw=0, btn_right_raw=0, btn_rotate_raw=0, btn_down_raw=0;
  wire hsync, vsync;
  wire [3:0] vga_red, vga_green, vga_blue;

  always #5 clk_in = ~clk_in; // 100MHz board clock

  tetris_top uut(
    .clk_in(clk_in), .btn_reset(btn_reset),
    .btn_left_raw(btn_left_raw), .btn_right_raw(btn_right_raw),
    .btn_rotate_raw(btn_rotate_raw), .btn_down_raw(btn_down_raw),
    .hsync(hsync), .vsync(vsync),
    .vga_red(vga_red), .vga_green(vga_green), .vga_blue(vga_blue)
  );

  integer fd;
  integer pixel_count;
  reg capturing;
  reg [7:0] r8, g8, b8;
  integer i, c;

  initial begin
    capturing = 0;
    pixel_count = 0;

    #200 btn_reset = 0;
    #100;

    // ---- Populate the board with a visually interesting test
    // pattern so the captured frame actually shows something,
    // using the same hierarchical-force technique as the
    // line-clear testbench (simulation-only debug access). ----

    // Bottom two rows: a colorful stack of locked blocks
    for (c = 0; c < 10; c = c + 1) begin
      uut.bctrl.bmem.cells[19*10 + c] = (c % 7) + 1;
      uut.bctrl.bmem.cells[18*10 + c] = ((c+3) % 7) + 1;
    end
    // A partial row higher up
    for (c = 0; c < 6; c = c + 1)
      uut.bctrl.bmem.cells[15*10 + c] = ((c+1) % 7) + 1;

    #50;

    // ---- Capture exactly one full 640x480 active frame ----
    fd = $fopen("/home/claude/frame.ppm", "w");
    $fwrite(fd, "P3\n640 480\n255\n");

    // Wait for a clean frame boundary, then start capturing
    @(negedge uut.video_on); // end of an active frame
    @(posedge uut.video_on); // start of the next one
    capturing = 1;

    while (pixel_count < 640*480) begin
      @(posedge uut.clk25);
      if (uut.video_on) begin
        r8 = {vga_red, vga_red};   // 4-bit -> 8-bit (nibble duplication)
        g8 = {vga_green, vga_green};
        b8 = {vga_blue, vga_blue};
        $fwrite(fd, "%0d %0d %0d\n", r8, g8, b8);
        pixel_count = pixel_count + 1;
      end
    end

    $fclose(fd);
    $display("Captured %0d pixels to frame.ppm", pixel_count);
    $finish;
  end

  initial begin
    #100_000_000;
    $display("WATCHDOG: capture taking too long, aborting");
    $finish;
  end
endmodule
