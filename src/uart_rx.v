// ============================================================
// uart_rx.v
// Standard UART receiver: 8 data bits, no parity, 1 stop bit
// (8N1) -- matches PmodBLE's default transparent-UART settings
// (115200 baud out of the box). Samples the middle of each bit
// period for noise immunity, same technique as a real UART.
// ============================================================
module uart_rx #(
    parameter CLK_HZ  = 25_000_000,
    parameter BAUD    = 115_200
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       rx,          // serial line in, idles HIGH

    output reg  [7:0] data,        // received byte, valid for 1 cycle
    output reg        data_valid   // 1-cycle pulse when 'data' is ready
);

    // Cycles per bit period. 25MHz/115200 = 217.01 -- the ~0.005%
    // rounding error is far inside UART's usual ~2-3% tolerance.
    localparam integer BIT_PERIOD = CLK_HZ / BAUD;
    localparam integer HALF_BIT   = BIT_PERIOD / 2;

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [12:0] cycle_count;   // counts cycles within the current bit
    reg [3:0]  bit_idx;       // which data bit (0-7) we're sampling
    reg [7:0]  shift_reg;

    // 2-stage synchronizer: rx comes from an external async pin
    reg rx_sync0, rx_sync1;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= rx;
            rx_sync1 <= rx_sync0;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= S_IDLE;
            cycle_count <= 13'd0;
            bit_idx     <= 4'd0;
            shift_reg   <= 8'd0;
            data        <= 8'd0;
            data_valid  <= 1'b0;
        end else begin
            data_valid <= 1'b0; // default low, pulses only when set below

            case (state)
                // Idle line is high; a start bit is the line going low.
                S_IDLE: begin
                    if (!rx_sync1) begin
                        state       <= S_START;
                        cycle_count <= 13'd0;
                    end
                end

                // Wait to the MIDDLE of the start bit, then confirm
                // it's still low (reject glitches).
                S_START: begin
                    if (cycle_count == HALF_BIT - 1) begin
                        if (!rx_sync1) begin
                            state       <= S_DATA;
                            cycle_count <= 13'd0;
                            bit_idx     <= 4'd0;
                        end else begin
                            state <= S_IDLE; // was a glitch, not a real start bit
                        end
                    end else begin
                        cycle_count <= cycle_count + 13'd1;
                    end
                end

                // Sample each of the 8 data bits at the middle of its
                // own bit period (one full BIT_PERIOD after the last
                // sample point, i.e. the start bit's middle).
                S_DATA: begin
                    if (cycle_count == BIT_PERIOD - 1) begin
                        cycle_count       <= 13'd0;
                        shift_reg[bit_idx] <= rx_sync1; // LSB first (standard UART)
                        if (bit_idx == 4'd7)
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 4'd1;
                    end else begin
                        cycle_count <= cycle_count + 13'd1;
                    end
                end

                // Sample the stop bit's middle, then the byte is done.
                S_STOP: begin
                    if (cycle_count == BIT_PERIOD - 1) begin
                        data       <= shift_reg;
                        data_valid <= 1'b1;
                        state      <= S_IDLE;
                    end else begin
                        cycle_count <= cycle_count + 13'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule