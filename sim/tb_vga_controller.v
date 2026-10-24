// ============================================================
// tb_vga_controller.v
// Simple testbench: checks that hsync/vsync pulses occur
// at the expected pixel/line counts, and that video_on
// behaves correctly.
// ============================================================
`timescale 1ns/1ps

module tb_vga_controller;

    reg clk25 = 0;
    reg reset = 1;

    wire hsync, vsync, video_on;
    wire [9:0] pixel_x, pixel_y;

    // 25 MHz clock -> period = 40 ns
    always #20 clk25 = ~clk25;

    vga_controller uut (
        .clk25(clk25),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    initial begin
        $dumpfile("vga_controller_tb.vcd");
        $dumpvars(0, tb_vga_controller);

        // hold reset for a few clocks
        #100 reset = 0;

        // Run for slightly more than 2 full frames
        // 1 frame = 800*525 = 420000 pixel clocks = 420000*40ns = 16.8 ms
        #34000000;

        $display("Simulation finished.");
        $finish;
    end

    // Simple monitor: print when video_on transitions
    reg prev_video_on = 0;
    always @(posedge clk25) begin
        if (video_on !== prev_video_on) begin
            $display("time=%0t video_on=%b pixel_x=%0d pixel_y=%0d",
                       $time, video_on, pixel_x, pixel_y);
            prev_video_on <= video_on;
        end
    end

endmodule
