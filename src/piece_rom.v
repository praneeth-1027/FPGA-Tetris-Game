// ============================================================
// piece_rom.v
// Stores the 7 standard tetrominoes (I, O, T, S, Z, J, L) as
// 4x4 bitmaps, one for each of 4 rotation states (0-3).
// Each shape is returned as a 16-bit value; bit (row*4+col) = 1
// means that cell is occupied by the piece.
//
// Bit layout (row0 = top, col0 = left), MSB first:
//   bit15 bit14 bit13 bit12   <- row 0
//   bit11 bit10 bit9  bit8    <- row 1
//   bit7  bit6  bit5  bit4    <- row 2
//   bit3  bit2  bit1  bit0    <- row 3
//
// piece_type: 0=I 1=O 2=T 3=S 4=Z 5=J 6=L
// rotation:   0,1,2,3 (90 deg steps, clockwise)
// ============================================================
module piece_rom(
    input  wire [2:0]  piece_type,
    input  wire [1:0]  rotation,
    output reg  [15:0] shape_bitmap,
    output reg  [2:0]  piece_color   // color index for board_memory (1-7)
);

    always @(*) begin
        piece_color = piece_type + 3'd1; // color 1-7, matches vga_driver LUT

        case (piece_type)
            // ---------------- I piece ----------------
            3'd0: begin
                case (rotation)
                    2'd0: shape_bitmap = 16'b0000_1111_0000_0000; // horizontal, row1
                    2'd1: shape_bitmap = 16'b0010_0010_0010_0010; // vertical, col2
                    2'd2: shape_bitmap = 16'b0000_0000_1111_0000; // horizontal, row2
                    2'd3: shape_bitmap = 16'b0100_0100_0100_0100; // vertical, col1
                    default: shape_bitmap = 16'b0;
                endcase
            end

            // ---------------- O piece (no rotation change) ----------------
            3'd1: begin
                shape_bitmap = 16'b0000_0110_0110_0000; // 2x2 block, centered
            end

            // ---------------- T piece ----------------
            3'd2: begin
                case (rotation)
                    2'd0: shape_bitmap = 16'b0000_0100_1110_0000; // point up... actually T pointing down top row
                    2'd1: shape_bitmap = 16'b0000_0100_0110_0100; // point left
                    2'd2: shape_bitmap = 16'b0000_0000_1110_0100; // point up
                    2'd3: shape_bitmap = 16'b0000_0100_1100_0100; // point right
                    default: shape_bitmap = 16'b0;
                endcase
            end

            // ---------------- S piece ----------------
            3'd3: begin
                case (rotation)
                    2'd0: shape_bitmap = 16'b0000_0110_1100_0000;
                    2'd1: shape_bitmap = 16'b0000_0100_0110_0010;
                    2'd2: shape_bitmap = 16'b0000_0000_0110_1100;
                    2'd3: shape_bitmap = 16'b0000_1000_1100_0100;
                    default: shape_bitmap = 16'b0;
                endcase
            end

            // ---------------- Z piece ----------------
            3'd4: begin
                case (rotation)
                    2'd0: shape_bitmap = 16'b0000_1100_0110_0000;
                    2'd1: shape_bitmap = 16'b0000_0010_0110_0100;
                    2'd2: shape_bitmap = 16'b0000_0000_1100_0110;
                    2'd3: shape_bitmap = 16'b0000_0100_1100_1000;
                    default: shape_bitmap = 16'b0;
                endcase
            end

            // ---------------- J piece ----------------
            3'd5: begin
                case (rotation)
                    2'd0: shape_bitmap = 16'b1000_1110_0000_0000;
                    2'd1: shape_bitmap = 16'b0110_0100_0100_0000;
                    2'd2: shape_bitmap = 16'b0000_1110_0010_0000;
                    2'd3: shape_bitmap = 16'b0100_0100_1100_0000;
                    default: shape_bitmap = 16'b0;
                endcase
            end

            // ---------------- L piece ----------------
            3'd6: begin
                case (rotation)
                    2'd0: shape_bitmap = 16'b0010_1110_0000_0000;
                    2'd1: shape_bitmap = 16'b0100_0100_0110_0000;
                    2'd2: shape_bitmap = 16'b0000_1110_1000_0000;
                    2'd3: shape_bitmap = 16'b1100_0100_0100_0000;
                    default: shape_bitmap = 16'b0;
                endcase
            end

            default: shape_bitmap = 16'b0;
        endcase
    end

endmodule
