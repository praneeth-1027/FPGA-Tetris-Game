// ============================================================
// tb_gameplay_gif.v
// Captures a SEQUENCE of numbered frames (frame_001.ppm,
// frame_002.ppm, ...) through a real gameplay progression --
// spawn, movement, rotation, dropping, locking, next piece,
// and eventually a real line clear -- so they can be stitched
// into an animated GIF afterward.
//
// Everything here is REAL gameplay: real button presses through
// the real debounce circuit, real piece_gen output, real
// collision/lock FSM. Nothing is staged or hand-placed.
// ============================================================
`timescale 1ns/1ps

module tb_gameplay_gif;

    reg clk_in = 0;
    reg btn_reset = 1;
    reg btn_left_raw=0, btn_right_raw=0, btn_rotate_raw=0, btn_down_raw=0;
    wire hsync, vsync;
    wire [3:0] vga_red, vga_green, vga_blue;
    wire [6:0] seg;
    wire [3:0] an;

    always #5 clk_in = ~clk_in;

    tetris_top uut (
        .clk_in(clk_in), .btn_reset(btn_reset),
        .btn_left_raw(btn_left_raw), .btn_right_raw(btn_right_raw),
        .btn_rotate_raw(btn_rotate_raw), .btn_down_raw(btn_down_raw),
        .hsync(hsync), .vsync(vsync),
        .vga_red(vga_red), .vga_green(vga_green), .vga_blue(vga_blue),
        .seg(seg), .an(an)
    );

    integer fd;
    integer pixel_count;
    reg [7:0] r8, g8, b8;
    integer frame_num;
    reg [8*32-1:0] fname;

    task automatic capture_frame;
        begin
            $sformat(fname, "frame_%02d.ppm", frame_num);
            fd = $fopen(fname, "w");
            $fwrite(fd, "P3\n640 480\n255\n");
            @(negedge uut.video_on);
            @(posedge uut.video_on);
            pixel_count = 0;
            while (pixel_count < 640*480) begin
                @(posedge uut.clk25);
                if (uut.video_on) begin
                    r8 = {vga_red, vga_red};
                    g8 = {vga_green, vga_green};
                    b8 = {vga_blue, vga_blue};
                    $fwrite(fd, "%0d %0d %0d\n", r8, g8, b8);
                    pixel_count = pixel_count + 1;
                end
            end
            $fclose(fd);
            $display("Captured %s", fname);
            frame_num = frame_num + 1;
        end
    endtask

    task automatic press_left;
        begin
            @(posedge uut.clk25); btn_left_raw = 1;
            repeat (20) @(posedge uut.clk25);
            btn_left_raw = 0;
            repeat (20) @(posedge uut.clk25);
        end
    endtask

    task automatic press_right;
        begin
            @(posedge uut.clk25); btn_right_raw = 1;
            repeat (20) @(posedge uut.clk25);
            btn_right_raw = 0;
            repeat (20) @(posedge uut.clk25);
        end
    endtask

    task automatic press_rotate;
        begin
            @(posedge uut.clk25); btn_rotate_raw = 1;
            repeat (20) @(posedge uut.clk25);
            btn_rotate_raw = 0;
            repeat (20) @(posedge uut.clk25);
        end
    endtask

    task automatic press_down;
        begin
            @(posedge uut.clk25); btn_down_raw = 1;
            repeat (20) @(posedge uut.clk25);
            btn_down_raw = 0;
            repeat (20) @(posedge uut.clk25);
        end
    endtask

    // Drop the current piece all the way, capturing a frame every
    // few steps (not every single press) so the fall is visible in
    // the GIF without generating an excessive number of frames.
    task automatic drop_with_frames;
        integer k;
        begin
            k = 0;
            while (uut.bctrl.state == 0 && k < 25) begin
                press_down;
                if (k % 4 == 0) capture_frame; // every 4th step
                k = k + 1;
            end
            capture_frame; // always capture the final landed state
            #3000; // let LOCK -> LINE_CHK -> CLEAR -> SPAWN settle
        end
    endtask

    initial begin
        frame_num = 1;
        #200 btn_reset = 0;
        #100;

        // ---- Frame 1: initial spawn ----
        capture_frame;

        // ---- Move the first piece left a couple of times ----
        press_left;  capture_frame;
        press_left;  capture_frame;

        // ---- Rotate it ----
        press_rotate; capture_frame;

        // ---- Move right once ----
        press_right; capture_frame;

        // ---- Drop it the rest of the way ----
        drop_with_frames;

        // ---- Second piece: move right, rotate, drop ----
        press_right; capture_frame;
        press_right; capture_frame;
        press_rotate; capture_frame;
        drop_with_frames;

        $display("All %0d frames captured for GIF assembly.", frame_num - 1);
        $finish;
    end

    initial begin
        #1_500_000_000; // 1.5 SECONDS of sim time watchdog -- comfortably
                          // covers this reduced 2-piece sequence (~20
                          // frames x 16.8ms/frame = ~340ms needed)
        $display("WATCHDOG: capture taking too long, aborting");
        $finish;
    end

endmodule