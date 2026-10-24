// ============================================================
// seven_seg_driver.v
// Displays the score on a 4-digit multiplexed seven-segment
// display (common-anode style, active-low segments and
// active-low anode select -- matches Basys 3 / Nexys A7 style
// boards).
//
// 'score' arrives ALREADY in BCD (board_ctrl keeps it in BCD
// internally and saturates at 0x9999), so this module needs no
// binary-to-BCD conversion at all -- it used to carry its own
// double-dabble converter (14 iterations x 4 comparators); that
// is now redundant and has been removed.
// ============================================================
module seven_seg_driver(
    input  wire        clk,      // any reasonably fast clock (e.g. clk25)
    input  wire        reset,
    input  wire [15:0] score,    // BCD score value (one hex nibble per digit)

    output reg  [6:0]  seg,      // active-low segments a-g
    output reg  [3:0]  an        // active-low anode select (digit enable)
);

    wire [15:0] bcd = score;

    // ---- Digit refresh / multiplexing ----
    // Cycles through the 4 digits fast enough to avoid visible
    // flicker (>100Hz per digit is comfortably enough).
    reg [19:0] refresh_counter;
    always @(posedge clk or posedge reset) begin
        if (reset)
            refresh_counter <= 20'd0;
        else
            refresh_counter <= refresh_counter + 20'd1;
    end

    wire [1:0] digit_sel = refresh_counter[19:18];

    reg [3:0] digit_value;
    always @(*) begin
        case (digit_sel)
            2'b00: begin digit_value = bcd[3:0];   an = 4'b1110; end // ones
            2'b01: begin digit_value = bcd[7:4];   an = 4'b1101; end // tens
            2'b10: begin digit_value = bcd[11:8];  an = 4'b1011; end // hundreds
            2'b11: begin digit_value = bcd[15:12]; an = 4'b0111; end // thousands
            default: begin digit_value = 4'd0;     an = 4'b1111; end
        endcase
    end

    // ---- BCD digit (0-9) to seven-segment pattern (active-low, "abcdefg") ----
    always @(*) begin
        case (digit_value)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111; // blank
        endcase
    end

endmodule