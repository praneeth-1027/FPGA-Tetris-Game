// ============================================================
// tb_piece_rom.v
// For every piece_type (0-6) and rotation (0-3), checks that
// the returned 16-bit bitmap has EXACTLY 4 bits set (a valid
// tetromino must always occupy exactly 4 cells).
// ============================================================
`timescale 1ns/1ps

module tb_piece_rom;

    reg [2:0] piece_type;
    reg [1:0] rotation;
    wire [15:0] shape_bitmap;
    wire [2:0] piece_color;

    piece_rom uut (
        .piece_type(piece_type),
        .rotation(rotation),
        .shape_bitmap(shape_bitmap),
        .piece_color(piece_color)
    );

    integer p, r, bit_i;
    integer count;
    integer errors = 0;

    initial begin
        for (p = 0; p < 7; p = p + 1) begin
            for (r = 0; r < 4; r = r + 1) begin
                piece_type = p[2:0];
                rotation   = r[1:0];
                #10;

                count = 0;
                for (bit_i = 0; bit_i < 16; bit_i = bit_i + 1)
                    if (shape_bitmap[bit_i]) count = count + 1;

                if (count != 4) begin
                    $display("ERROR: piece_type=%0d rotation=%0d has %0d bits set (expected 4), bitmap=%b",
                              p, r, count, shape_bitmap);
                    errors = errors + 1;
                end else begin
                    $display("OK: piece_type=%0d rotation=%0d bitmap=%b color=%0d",
                              p, r, shape_bitmap, piece_color);
                end
            end
        end

        if (errors == 0)
            $display("ALL PASS: every piece/rotation has exactly 4 blocks.");
        else
            $display("FAIL: %0d invalid shapes found.", errors);

        $finish;
    end

endmodule
