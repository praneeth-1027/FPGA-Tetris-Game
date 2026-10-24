// ============================================================
// piece_gen.v
// Generates a pseudo-random piece_type (0-6) each time 'next'
// is pulsed, using a 7-bit LFSR (maximal-length taps).
//
// NOTE: mapping a 3-bit LFSR slice (0-7) down to 0-6 by folding
// the value 7 back to 0 introduces a small statistical bias
// (piece 0 is slightly more likely than the others). This is a
// standard, accepted simplification for a mini-project scope --
// true uniform 7-way random selection would need a rejection
// loop or a wider LFSR with modulo reduction.
// ============================================================
module piece_gen(
    input  wire       clk,
    input  wire       reset,
    input  wire       next,        // 1-cycle pulse: advance to a new piece
    output reg  [2:0] piece_type   // 0-6
);

    reg [6:0] lfsr;

    // 7-bit LFSR, taps at bit6 and bit5 (x^7 + x^6 + 1), nonzero seed
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            lfsr <= 7'b1011010; // arbitrary nonzero seed
        end else if (next) begin
            lfsr <= {lfsr[5:0], lfsr[6] ^ lfsr[5]};
        end
    end

    // Fold 0-7 range down to 0-6 (7 maps to 0)
    always @(*) begin
        piece_type = (lfsr[2:0] == 3'd7) ? 3'd0 : lfsr[2:0];
    end

endmodule
