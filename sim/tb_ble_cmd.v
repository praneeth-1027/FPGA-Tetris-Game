`timescale 1ns/1ps
module tb_ble_cmd;
    reg clk = 0;
    reg reset = 1;
    reg rx = 1;

    localparam BAUD = 115_200;
    localparam BIT_NS = 1_000_000_000 / BAUD;

    always #20 clk = ~clk; // 25 MHz

    wire [7:0] data;
    wire data_valid;
    wire btn_left, btn_right, btn_rotate, btn_down;

    uart_rx #(.CLK_HZ(25_000_000), .BAUD(BAUD)) rx_uut (
        .clk(clk), .reset(reset), .rx(rx), .data(data), .data_valid(data_valid)
    );

    ble_cmd_decoder dec_uut (
        .clk(clk), .reset(reset), .data(data), .data_valid(data_valid),
        .btn_left(btn_left), .btn_right(btn_right),
        .btn_rotate(btn_rotate), .btn_down(btn_down)
    );

    task automatic send_byte(input [7:0] b);
        integer i;
        begin
            rx = 1'b0; #(BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin
                rx = b[i];
                #(BIT_NS);
            end
            rx = 1'b1; #(BIT_NS);
        end
    endtask

    integer left_count, right_count, rotate_count, down_count;
    always @(posedge clk) begin
        if (btn_left)   left_count   = left_count + 1;
        if (btn_right)  right_count  = right_count + 1;
        if (btn_rotate) rotate_count = rotate_count + 1;
        if (btn_down)   down_count   = down_count + 1;
    end

    initial begin
        left_count=0; right_count=0; rotate_count=0; down_count=0;
        #100 reset = 0;
        #100;

        $display("Sending L, R, U, D, l, r, u, d, and one junk byte...");
        send_byte(8'h4C); #2000; // 'L'
        send_byte(8'h52); #2000; // 'R'
        send_byte(8'h55); #2000; // 'U'
        send_byte(8'h44); #2000; // 'D'
        send_byte(8'h6C); #2000; // 'l'
        send_byte(8'h72); #2000; // 'r'
        send_byte(8'h75); #2000; // 'u'
        send_byte(8'h64); #2000; // 'd'
        send_byte(8'h58); #2000; // 'X' -- should be ignored

        $display("left_count=%0d right_count=%0d rotate_count=%0d down_count=%0d (expect 2,2,2,2)",
                   left_count, right_count, rotate_count, down_count);

        if (left_count==2 && right_count==2 && rotate_count==2 && down_count==2)
            $display("PASS: all commands (upper+lower case) correctly decoded, junk byte ignored");
        else
            $display("FAIL");

        $finish;
    end
    initial begin #1_500_000; $display("WATCHDOG"); $finish; end
endmodule