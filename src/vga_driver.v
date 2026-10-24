// ============================================================
// vga_driver.v
// Converts current pixel_x/pixel_y (from vga_controller) into
// a board_memory cell lookup, and outputs RGB color for that
// pixel. Draws:
//   - playfield background, locked cells, grid, border
//   - the currently falling piece (overlay)
//   - a 3-piece "next up" preview column
//   - score and high-score digit displays
//   - a game-over popup overlay (final score + high score)
//
// Playfield: 10 cols x 20 rows, CELL_SIZE pixels per cell,
// centered within a 640x480 screen. Side panel (previews,
// score, high score) sits to the right of the board.
// ============================================================
module vga_driver(
    input  wire        clk25,
    input  wire        video_on,
    input  wire [9:0]  pixel_x,
    input  wire [9:0]  pixel_y,

    // Interface to board_memory (combinational read) -- locked cells
    output reg  [3:0]  rd_col,
    output reg  [4:0]  rd_row,
    input  wire [2:0]  cell_color,

    // Falling piece overlay (drawn on top of the locked board)
    input  wire signed [4:0] piece_col,
    input  wire [4:0]        piece_row,
    input  wire [15:0]       shape_bitmap,
    input  wire [2:0]        piece_color,

    // 3-piece "next up" preview queue (index 1 = spawns soonest)
    input  wire [15:0]       next1_shape_bitmap,
    input  wire [2:0]        next1_piece_color,
    input  wire [15:0]       next2_shape_bitmap,
    input  wire [2:0]        next2_piece_color,
    input  wire [15:0]       next3_shape_bitmap,
    input  wire [2:0]        next3_piece_color,

    // Score / high score
    input  wire [15:0]       score,
    input  wire [15:0]       high_score,

    // Game-over popup
    input  wire               game_over,

    output reg  [3:0]  red,
    output reg  [3:0]  green,
    output reg  [3:0]  blue
);

    localparam COLS       = 10;
    localparam ROWS       = 20;
    localparam CELL_SIZE  = 16;                       // pixels per cell
    localparam BOARD_W    = COLS * CELL_SIZE;         // 160
    localparam BOARD_H    = ROWS * CELL_SIZE;         // 320
    localparam OFFSET_X   = (640 - BOARD_W) / 2;      // 240
    localparam OFFSET_Y   = (480 - BOARD_H) / 2;      // 80

    wire signed [10:0] rel_x = pixel_x - OFFSET_X;
    wire signed [10:0] rel_y = pixel_y - OFFSET_Y;

    wire in_board = (rel_x >= 0) && (rel_x < BOARD_W) &&
                    (rel_y >= 0) && (rel_y < BOARD_H);

    wire [3:0] col_index = rel_x / CELL_SIZE;
    wire [4:0] row_index = rel_y / CELL_SIZE;

    wire on_grid_line = in_board &&
                         (((rel_x % CELL_SIZE) == 0) ||
                          ((rel_y % CELL_SIZE) == 0));

    wire on_border = (pixel_x >= OFFSET_X - 2 && pixel_x < OFFSET_X + BOARD_W + 2 &&
                       pixel_y >= OFFSET_Y - 2 && pixel_y < OFFSET_Y + BOARD_H + 2) &&
                      !in_board;

    // ---- Color lookup table: 3-bit color index -> RGB444 ----
    function [11:0] color_lut;
        input [2:0] idx;
        begin
            case (idx)
                3'b000: color_lut = 12'h000; // empty - black
                3'b001: color_lut = 12'h0FF; // cyan   - I piece
                3'b010: color_lut = 12'hFF0; // yellow - O piece
                3'b011: color_lut = 12'h80F; // purple - T piece
                3'b100: color_lut = 12'h0F0; // green  - S piece
                3'b101: color_lut = 12'hF00; // red    - Z piece
                3'b110: color_lut = 12'h00F; // blue   - J piece
                3'b111: color_lut = 12'hFA0; // orange - L piece
                default: color_lut = 12'h000;
            endcase
        end
    endfunction

    // =========================================================
    // Falling piece overlay
    // =========================================================
    wire signed [5:0] piece_local_col = $signed({1'b0,col_index}) - piece_col;
    wire signed [5:0] piece_local_row = $signed({1'b0,row_index}) - $signed({1'b0,piece_row});

    wire piece_cell_in_range = in_board &&
                                (piece_local_col >= 0) && (piece_local_col < 4) &&
                                (piece_local_row >= 0) && (piece_local_row < 4);

    wire piece_cell_set = piece_cell_in_range &&
                           shape_bitmap[15 - (piece_local_row*4 + piece_local_col)];

    // =========================================================
    // Reusable helper: is this pixel (given box-relative coords)
    // part of a set bit in a 4x4 shape bitmap, for a given cell
    // size? Used for all 3 preview boxes (different sizes).
    // =========================================================
    function preview_pixel_set;
        input signed [10:0] rx, ry;
        input [15:0] bitmap;
        input integer csize;
        reg [2:0] pc, pr;
        begin
            preview_pixel_set = 1'b0;
            if (rx >= 0 && rx < csize*4 && ry >= 0 && ry < csize*4) begin
                pc = rx / csize;
                pr = ry / csize;
                preview_pixel_set = bitmap[15 - (pr*4 + pc)];
            end
        end
    endfunction

    function preview_grid_line;
        input signed [10:0] rx, ry;
        input integer csize;
        begin
            preview_grid_line = (rx >= 0 && rx < csize*4 && ry >= 0 && ry < csize*4) &&
                                 (((rx % csize) == 0) || ((ry % csize) == 0));
        end
    endfunction

    // ---- Preview box 1 (next piece, largest/most prominent) ----
    localparam P1_CELL = 16;
    localparam P1_SIZE = P1_CELL * 4;                       // 64 px
    localparam P1_X    = OFFSET_X + BOARD_W + 30;
    localparam P1_Y    = OFFSET_Y;

    wire signed [10:0] p1_rx = pixel_x - P1_X;
    wire signed [10:0] p1_ry = pixel_y - P1_Y;
    wire in_p1 = (p1_rx >= 0) && (p1_rx < P1_SIZE) && (p1_ry >= 0) && (p1_ry < P1_SIZE);
    wire on_p1_border = (pixel_x >= P1_X-2 && pixel_x < P1_X+P1_SIZE+2 &&
                          pixel_y >= P1_Y-2 && pixel_y < P1_Y+P1_SIZE+2) && !in_p1;

    // ---- Preview box 2 (second-next, smaller) ----
    // NOTE: cell sizes MUST be powers of 2. preview_pixel_set/
    // preview_grid_line divide and take the modulus of pixel
    // coordinates by this value; for a power of 2 that is just a
    // wire shift / bit-mask (0 LUTs), but for any other divisor
    // (10 was used originally) Yosys must build an actual divider,
    // which costs on the order of 2000 LUTs PER division -- and
    // there are 4 such divisions/moduli per preview box here. This
    // single change (10 -> 8) removes the majority of this file's
    // LUT usage. Confirmed by isolated synthesis: divide-by-8 costs
    // 0 LUTs, divide-by-10 costs 2084 LUTs, on a 10-bit operand.
    localparam P2_CELL = 8;
    localparam P2_SIZE = P2_CELL * 4;                       // 32 px
    localparam P2_X    = P1_X + (P1_SIZE - P2_SIZE) / 2;    // centered under box1
    localparam P2_Y    = P1_Y + P1_SIZE + 14;

    wire signed [10:0] p2_rx = pixel_x - P2_X;
    wire signed [10:0] p2_ry = pixel_y - P2_Y;
    wire in_p2 = (p2_rx >= 0) && (p2_rx < P2_SIZE) && (p2_ry >= 0) && (p2_ry < P2_SIZE);
    wire on_p2_border = (pixel_x >= P2_X-2 && pixel_x < P2_X+P2_SIZE+2 &&
                          pixel_y >= P2_Y-2 && pixel_y < P2_Y+P2_SIZE+2) && !in_p2;

    // ---- Preview box 3 (third-next, same small size as box2) ----
    localparam P3_CELL = 8;  // must stay a power of 2 -- see P2_CELL's comment
    localparam P3_SIZE = P3_CELL * 4;                       // 32 px
    localparam P3_X    = P2_X;
    localparam P3_Y    = P2_Y + P2_SIZE + 12;

    wire signed [10:0] p3_rx = pixel_x - P3_X;
    wire signed [10:0] p3_ry = pixel_y - P3_Y;
    wire in_p3 = (p3_rx >= 0) && (p3_rx < P3_SIZE) && (p3_ry >= 0) && (p3_ry < P3_SIZE);
    wire on_p3_border = (pixel_x >= P3_X-2 && pixel_x < P3_X+P3_SIZE+2 &&
                          pixel_y >= P3_Y-2 && pixel_y < P3_Y+P3_SIZE+2) && !in_p3;

    // =========================================================
    // Reusable digit-display helpers (used for score, high
    // score, and the game-over popup)
    // =========================================================
    localparam DIGIT_SCALE = 4;
    localparam DIGIT_W     = 3 * DIGIT_SCALE;  // 12 px
    localparam DIGIT_H     = 5 * DIGIT_SCALE;  // 20 px
    localparam DIGIT_GAP   = 4;
    localparam D0_START = 0;
    localparam D0_END   = D0_START + DIGIT_W;
    localparam D1_START = D0_END + DIGIT_GAP;
    localparam D1_END   = D1_START + DIGIT_W;
    localparam D2_START = D1_END + DIGIT_GAP;
    localparam D2_END   = D2_START + DIGIT_W;
    localparam D3_START = D2_END + DIGIT_GAP;
    localparam D3_END   = D3_START + DIGIT_W;
    localparam DIGITS_BOX_W = D3_END; // 60 px, width of a 4-digit group

    // NOTE: score / high_score arrive from board_ctrl ALREADY in BCD
    // (board_ctrl adds 100 per cleared line directly in BCD -- see
    // bcd_add100 there), so no binary-to-BCD converter is needed here
    // at all. The old double-dabble function (14 iterations x 4
    // comparators, instantiated twice) has been removed; this alone
    // accounts for a large share of this module's LUT reduction.

    function [14:0] digit_font;
        input [3:0] d;
        begin
            case (d)
                4'd0: digit_font = 15'b111_101_101_101_111;
                4'd1: digit_font = 15'b010_110_010_010_111;
                4'd2: digit_font = 15'b111_001_111_100_111;
                4'd3: digit_font = 15'b111_001_111_001_111;
                4'd4: digit_font = 15'b101_101_111_001_001;
                4'd5: digit_font = 15'b111_100_111_001_111;
                4'd6: digit_font = 15'b111_100_111_101_111;
                4'd7: digit_font = 15'b111_001_001_001_001;
                4'd8: digit_font = 15'b111_101_111_101_111;
                4'd9: digit_font = 15'b111_101_111_001_111;
                default: digit_font = 15'b000_000_000_000_000;
            endcase
        end
    endfunction

    // Is (rx,ry) -- relative to a digit-group box's top-left --
    // part of a lit segment, given that group's 16-bit BCD value?
    function digits_pixel_set;
        input signed [10:0] rx, ry;
        input [15:0] bcd;
        reg [3:0] local_col, local_row, digit_value;
        reg [14:0] font;
        begin
            digits_pixel_set = 1'b0;
            if (rx >= 0 && rx < DIGITS_BOX_W && ry >= 0 && ry < DIGIT_H) begin
                digit_value = 4'd0;
                local_col   = 4'd0;
                if (rx < D0_END) begin
                    digit_value = bcd[15:12];
                    local_col   = rx / DIGIT_SCALE;
                end else if (rx >= D1_START && rx < D1_END) begin
                    digit_value = bcd[11:8];
                    local_col   = (rx - D1_START) / DIGIT_SCALE;
                end else if (rx >= D2_START && rx < D2_END) begin
                    digit_value = bcd[7:4];
                    local_col   = (rx - D2_START) / DIGIT_SCALE;
                end else if (rx >= D3_START && rx < D3_END) begin
                    digit_value = bcd[3:0];
                    local_col   = (rx - D3_START) / DIGIT_SCALE;
                end else begin
                    digits_pixel_set = 1'b0;
                end
                local_row = ry / DIGIT_SCALE;
                font = digit_font(digit_value);
                if ((rx < D0_END) || (rx >= D1_START && rx < D1_END) ||
                    (rx >= D2_START && rx < D2_END) || (rx >= D3_START && rx < D3_END))
                    digits_pixel_set = font[14 - (local_row*3 + local_col)];
            end
        end
    endfunction

    wire [15:0] score_bcd      = score;      // already BCD from board_ctrl
    wire [15:0] high_score_bcd = high_score; // already BCD from board_ctrl

    // ---- Score box (below preview 3) ----
    localparam SCORE_X = P2_X + (P2_SIZE - DIGITS_BOX_W) / 2;
    localparam SCORE_Y = P3_Y + P3_SIZE + 20;
    wire signed [10:0] score_rx = pixel_x - SCORE_X;
    wire signed [10:0] score_ry = pixel_y - SCORE_Y;
    wire in_score_box = (score_rx >= 0) && (score_rx < DIGITS_BOX_W) &&
                         (score_ry >= 0) && (score_ry < DIGIT_H);
    wire on_score_border = (pixel_x >= SCORE_X-2 && pixel_x < SCORE_X+DIGITS_BOX_W+2 &&
                             pixel_y >= SCORE_Y-2 && pixel_y < SCORE_Y+DIGIT_H+2) && !in_score_box;
    wire score_pixel_set = digits_pixel_set(score_rx, score_ry, score_bcd);

    // ---- High score box (below score box) ----
    localparam HISCORE_X = SCORE_X;
    localparam HISCORE_Y = SCORE_Y + DIGIT_H + 16;
    wire signed [10:0] hiscore_rx = pixel_x - HISCORE_X;
    wire signed [10:0] hiscore_ry = pixel_y - HISCORE_Y;
    wire in_hiscore_box = (hiscore_rx >= 0) && (hiscore_rx < DIGITS_BOX_W) &&
                           (hiscore_ry >= 0) && (hiscore_ry < DIGIT_H);
    wire on_hiscore_border = (pixel_x >= HISCORE_X-2 && pixel_x < HISCORE_X+DIGITS_BOX_W+2 &&
                               pixel_y >= HISCORE_Y-2 && pixel_y < HISCORE_Y+DIGIT_H+2) && !in_hiscore_box;
    wire hiscore_pixel_set = digits_pixel_set(hiscore_rx, hiscore_ry, high_score_bcd);

    // =========================================================
    // Game-over popup: a bordered box roughly centered on screen,
    // showing the final score and the high score as two separate
    // digit groups. (No text labels -- that would need a full
    // alphabet font, out of scope here; the two rows are visually
    // distinguished by digit color instead: white for the final
    // score, gold for the high score.)
    // =========================================================
    localparam POPUP_W = 180;
    localparam POPUP_H = 110;
    localparam POPUP_X = (640 - POPUP_W) / 2;
    localparam POPUP_Y = (480 - POPUP_H) / 2;

    wire signed [10:0] popup_rx = pixel_x - POPUP_X;
    wire signed [10:0] popup_ry = pixel_y - POPUP_Y;
    wire in_popup = game_over && (popup_rx >= 0) && (popup_rx < POPUP_W) &&
                                  (popup_ry >= 0) && (popup_ry < POPUP_H);
    wire on_popup_border = game_over &&
                            (pixel_x >= POPUP_X-3 && pixel_x < POPUP_X+POPUP_W+3 &&
                             pixel_y >= POPUP_Y-3 && pixel_y < POPUP_Y+POPUP_H+3) && !in_popup;

    // Two digit rows inside the popup: final score (upper), high
    // score (lower), each centered horizontally within the popup.
    localparam POPUP_ROW1_Y = 25;  // relative to popup top
    localparam POPUP_ROW2_Y = 65;
    localparam POPUP_DIGITS_X = (POPUP_W - DIGITS_BOX_W) / 2; // relative to popup left

    wire signed [10:0] popup_score_rx = popup_rx - POPUP_DIGITS_X;
    wire signed [10:0] popup_score_ry = popup_ry - POPUP_ROW1_Y;
    wire popup_score_set = in_popup && digits_pixel_set(popup_score_rx, popup_score_ry, score_bcd);

    wire signed [10:0] popup_hi_rx = popup_rx - POPUP_DIGITS_X;
    wire signed [10:0] popup_hi_ry = popup_ry - POPUP_ROW2_Y;
    wire popup_hi_set = in_popup && digits_pixel_set(popup_hi_rx, popup_hi_ry, high_score_bcd);

    // ---- Drive board_memory read address combinationally ----
    always @(*) begin
        rd_col = col_index;
        rd_row = row_index;
    end

    // =========================================================
    // Main pixel-color priority chain
    // =========================================================
    always @(posedge clk25) begin
        if (!video_on) begin
            {red, green, blue} <= 12'h000;

        // Game-over popup takes absolute priority over everything
        // else on screen while active.
        end else if (on_popup_border) begin
            {red, green, blue} <= 12'hF00; // red border -- unmistakably "game over"
        end else if (in_popup) begin
            if (popup_score_set)
                {red, green, blue} <= 12'hFFF; // white: final score
            else if (popup_hi_set)
                {red, green, blue} <= 12'hFF0; // gold/yellow: high score
            else
                {red, green, blue} <= 12'h200; // dark red popup background

        end else if (on_border) begin
            {red, green, blue} <= 12'hFFF;
        end else if (in_board) begin
            if (piece_cell_set)
                {red, green, blue} <= color_lut(piece_color);
            else if (on_grid_line)
                {red, green, blue} <= 12'h222;
            else
                {red, green, blue} <= color_lut(cell_color);

        end else if (on_p1_border) begin
            {red, green, blue} <= 12'hFFF;
        end else if (in_p1) begin
            if (preview_pixel_set(p1_rx, p1_ry, next1_shape_bitmap, P1_CELL))
                {red, green, blue} <= color_lut(next1_piece_color);
            else if (preview_grid_line(p1_rx, p1_ry, P1_CELL))
                {red, green, blue} <= 12'h222;
            else
                {red, green, blue} <= 12'h000;

        end else if (on_p2_border) begin
            {red, green, blue} <= 12'hFFF;
        end else if (in_p2) begin
            if (preview_pixel_set(p2_rx, p2_ry, next2_shape_bitmap, P2_CELL))
                {red, green, blue} <= color_lut(next2_piece_color);
            else if (preview_grid_line(p2_rx, p2_ry, P2_CELL))
                {red, green, blue} <= 12'h222;
            else
                {red, green, blue} <= 12'h000;

        end else if (on_p3_border) begin
            {red, green, blue} <= 12'hFFF;
        end else if (in_p3) begin
            if (preview_pixel_set(p3_rx, p3_ry, next3_shape_bitmap, P3_CELL))
                {red, green, blue} <= color_lut(next3_piece_color);
            else if (preview_grid_line(p3_rx, p3_ry, P3_CELL))
                {red, green, blue} <= 12'h222;
            else
                {red, green, blue} <= 12'h000;

        end else if (on_score_border) begin
            {red, green, blue} <= 12'hFFF;
        end else if (in_score_box) begin
            {red, green, blue} <= score_pixel_set ? 12'h0F0 : 12'h000;

        end else if (on_hiscore_border) begin
            {red, green, blue} <= 12'hFFF;
        end else if (in_hiscore_box) begin
            {red, green, blue} <= hiscore_pixel_set ? 12'hFF0 : 12'h000; // gold digits

        end else begin
            {red, green, blue} <= 12'h11A;
        end
    end

endmodule