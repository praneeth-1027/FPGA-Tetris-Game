`timescale 1ns/1ps
module tb_uart_rx;
    reg clk = 0;
    reg reset = 1;
    reg rx = 1; // idle high
    wire [7:0] data;
    wire data_valid;

    localparam CLK_HZ = 25_000_000;
    localparam BAUD = 115_200;
    localparam BIT_NS = 1_000_000_000 / BAUD; // ~8680.6 ns per bit

    always #20 clk = ~clk; // 25 MHz

    uart_rx #(.CLK_HZ(CLK_HZ), .BAUD(BAUD)) uut (
        .clk(clk), .reset(reset), .rx(rx),
        .data(data), .data_valid(data_valid)
    );

    // Sends one byte (LSB first), exactly like a real UART transmitter:
    // start bit (0), 8 data bits, stop bit (1).
    task automatic send_byte(input [7:0] b);
        integer i;
        begin
            rx = 1'b0; #(BIT_NS); // start bit
            for (i = 0; i < 8; i = i + 1) begin
                rx = b[i];
                #(BIT_NS);
            end
            rx = 1'b1; #(BIT_NS); // stop bit
        end
    endtask

    integer received_count;
    reg [7:0] last_byte;
    always @(posedge clk) begin
        if (data_valid) begin
            received_count = received_count + 1;
            last_byte = data;
            $display("t=%0t  received byte = 0x%02h ('%c')", $time, data, data);
        end
    end

    initial begin
        received_count = 0;
        #100 reset = 0;
        #100;

        // ---- Test 1: send 'L' (0x4C) ----
        send_byte(8'h4C);
        #2000;
        $display("TEST1: received_count=%0d last_byte=0x%02h (expect 1, 0x4c)", received_count, last_byte);

        // ---- Test 2: send a sequence of different bytes back to back ----
        received_count = 0;
        send_byte(8'h52); // 'R'
        send_byte(8'h55); // 'U'
        send_byte(8'h44); // 'D'
        #2000;
        $display("TEST2: received_count=%0d (expect 3)", received_count);

        // ---- Test 3: a short glitch on the line (shorter than a real
        // start bit) should NOT be mistaken for a start bit ----
        received_count = 0;
        rx = 1'b0; #100; rx = 1'b1; // glitch much shorter than one bit period
        #10000;
        $display("TEST3: received_count=%0d after a short glitch (expect 0, glitch correctly rejected)",
                   received_count);

        if (received_count == 0)
            $display("PASS: glitch rejection works");
        else
            $display("FAIL: glitch was misread as a start bit");

        $display("All uart_rx tests complete.");
        $finish;
    end

    initial begin #500_000; $display("WATCHDOG"); $finish; end
endmodule