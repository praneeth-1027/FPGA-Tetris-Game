`timescale 1ns/1ps

// ============================================================
// USE CASE 3: VGA timing verification for 640x480 @ 60 Hz.
// DUT: vga_controller.v
//
// Expected timing:
//   Horizontal total = 800 pixels
//   Visible           = 0..639
//   HSYNC low         = 656..751 (96 pixel clocks)
//
//   Vertical total    = 525 lines
//   Visible           = 0..479
//   VSYNC low         = 490..491 (2 lines)
//
// Suggested waveform signals:
//   h_count_mon, v_count_mon, pixel_x, pixel_y,
//   video_on, hsync, vsync
//
// For the report, take two waveform screenshots:
//   A) Around h_count 635..760 -> visible/front porch/HSYNC
//   B) Around v_count 488..493 -> VSYNC interval
// ============================================================
module tb_uc3_vga_timing;

    reg clk25 = 1'b0;
    reg reset = 1'b0;

    wire hsync;
    wire vsync;
    wire video_on;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;

    vga_controller dut (
        .clk25(clk25),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    // Internal aliases make timing counters easy to add to waveform.
    wire [9:0] h_count_mon = dut.h_count;
    wire [9:0] v_count_mon = dut.v_count;

    // 25 MHz pixel clock -> 40 ns period
    always #20 clk25 = ~clk25;

    integer hsync_low_count;
    integer lines_seen;

    initial begin
        hsync_low_count = 0;
        lines_seen = 0;

        reset = 1'b1;
        repeat (3) @(posedge clk25);
        reset = 1'b0;

        // Run naturally through the beginning of vertical sync.
        // Stop shortly after line 492 so VSYNC assertion/deassertion
        // is visible in the waveform.
        while (!((v_count_mon == 10'd493) && (h_count_mon == 10'd20))) begin
            @(posedge clk25);
        end

        $display("PASS UC3: Reached v_count=%0d h_count=%0d; VGA timing sequence observable.",
                 v_count_mon, h_count_mon);
        $finish;
    end

    // Optional console checks for horizontal timing on the first line.
    always @(posedge clk25) begin
        if (!reset && v_count_mon == 10'd0) begin
            if (!hsync)
                hsync_low_count = hsync_low_count + 1;

            if (h_count_mon == 10'd799) begin
                if (hsync_low_count == 96)
                    $display("PASS: HSYNC low width = 96 pixel clocks");
                else
                    $display("FAIL: HSYNC low width = %0d pixel clocks", hsync_low_count);
            end
        end
    end

endmodule
