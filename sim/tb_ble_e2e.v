`timescale 1ns/1ps
module tb_ble_e2e;
    reg clk_in = 0;
    reg btn_reset = 1;
    reg btn_left_raw=0, btn_right_raw=0, btn_rotate_raw=0, btn_down_raw=0;
    reg ble_rxd = 1; // idle high
    wire hsync, vsync;
    wire [3:0] vga_red, vga_green, vga_blue;
    wire [6:0] seg; wire [3:0] an; wire audio_pwm;

    always #5 clk_in = ~clk_in;

    tetris_top uut (
        .clk_in(clk_in), .btn_reset(btn_reset),
        .btn_left_raw(btn_left_raw), .btn_right_raw(btn_right_raw),
        .btn_rotate_raw(btn_rotate_raw), .btn_down_raw(btn_down_raw),
        .hsync(hsync), .vsync(vsync),
        .vga_red(vga_red), .vga_green(vga_green), .vga_blue(vga_blue),
        .seg(seg), .an(an), .audio_pwm(audio_pwm),
        .ble_rxd(ble_rxd)
    );

    localparam BAUD = 115_200;
    localparam BIT_NS = 1_000_000_000 / BAUD;

    task automatic ble_send(input [7:0] b);
        integer i;
        begin
            ble_rxd = 1'b0; #(BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin
                ble_rxd = b[i];
                #(BIT_NS);
            end
            ble_rxd = 1'b1; #(BIT_NS);
        end
    endtask

    initial begin
        #200 btn_reset = 0;
        #500; // let S_INIT's queue warmup finish before we start

        $display("Initial piece_col=%0d (expect 3, default spawn)", uut.piece_col);

        $display("Sending 'R' from the phone app over BLE...");
        ble_send(8'h52); // 'R' -> move right
        #5000; // let the UART byte + debounce-free button pulse propagate

        $display("After BLE 'R': piece_col=%0d (expect 4, moved right by phone command)", uut.piece_col);

        if (uut.piece_col == 4)
            $display("PASS: a real phone-app command, received over simulated BLE UART, moved the real piece");
        else
            $display("FAIL: piece did not move as expected");

        // Confirm physical buttons STILL work too (not disabled by adding BLE)
        $display("Pressing physical left button...");
        @(posedge uut.clk25); btn_left_raw = 1;
        repeat(20) @(posedge uut.clk25);
        btn_left_raw = 0;
        repeat(20) @(posedge uut.clk25);
        #100;
        $display("After physical left press: piece_col=%0d (expect 3, back down via physical button)", uut.piece_col);

        if (uut.piece_col == 3)
            $display("PASS: physical buttons still work alongside BLE control");
        else
            $display("FAIL: physical button path broken");

        $finish;
    end

    initial begin #2_000_000; $display("WATCHDOG"); $finish; end
endmodule