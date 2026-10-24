// ============================================================
// ble_cmd_decoder.v
// Maps single ASCII command bytes (received over PmodBLE's
// transparent UART) to 1-cycle button pulses, in exactly the
// same shape the existing debounced physical buttons already
// produce -- so these can be OR'd straight into the same
// btn_left/right/rotate/down signals board_ctrl expects.
//
// Command bytes (case-insensitive):
//   'L' / 'l' -> left
//   'R' / 'r' -> right
//   'U' / 'u' -> rotate ("up" spins the piece, matches the
//                Up-arrow convention most Tetris phone
//                controller layouts use)
//   'D' / 'd' -> down (soft drop)
//
// Any other byte is ignored.
// ============================================================
module ble_cmd_decoder(
    input  wire       clk,
    input  wire       reset,

    input  wire [7:0] data,
    input  wire       data_valid,  // 1-cycle pulse: 'data' just arrived

    output reg        btn_left,
    output reg        btn_right,
    output reg        btn_rotate,
    output reg        btn_down
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            btn_left   <= 1'b0;
            btn_right  <= 1'b0;
            btn_rotate <= 1'b0;
            btn_down   <= 1'b0;
        end else begin
            // default low each cycle; only the matching output
            // pulses high for exactly the cycle data_valid fires
            btn_left   <= 1'b0;
            btn_right  <= 1'b0;
            btn_rotate <= 1'b0;
            btn_down   <= 1'b0;

            if (data_valid) begin
                case (data)
                    8'h4C, 8'h6C: btn_left   <= 1'b1; // 'L' / 'l'
                    8'h52, 8'h72: btn_right  <= 1'b1; // 'R' / 'r'
                    8'h55, 8'h75: btn_rotate <= 1'b1; // 'U' / 'u'
                    8'h44, 8'h64: btn_down   <= 1'b1; // 'D' / 'd'
                    default: ; // unrecognized byte, ignored
                endcase
            end
        end
    end

endmodule