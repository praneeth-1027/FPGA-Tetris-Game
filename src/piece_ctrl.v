// ============================================================
// piece_ctrl.v  (LUT-optimised)
// Tracks the falling piece (4x4 bounding-box top-left position,
// rotation, type). Handles auto-fall (game tick), left / right,
// rotate and soft-drop, with wall/floor AND locked-cell collision.
//
// WHY THIS VERSION IS MUCH SMALLER
//  Old: four independent collision checkers (down/left/right/rotate),
//       each doing 16 dynamic lookups into a 600-bit colour bus
//       (=> thousands of 200:1 multiplexers).
//  New: only ONE action is ever applied per clock (same priority as
//       before), so a single candidate position is selected first and
//       ONE checker evaluates it. The checker works a whole ROW at a
//       time: the piece's 4-bit row slice is shifted to its column
//       and ANDed with the 10-bit occupancy of that board row.
//       Walls are handled by extra guard bits beside the 10 columns,
//       so no separate wall logic is needed either.
//
// The same checker also detects a blocked spawn (game over): the
// cycle after 'spawn' it is pointed at the piece's current position.
// ============================================================
module piece_ctrl(
    input  wire        clk,
    input  wire        reset,
    input  wire        clk_game,      // slow game-tick (synchronised here)

    input  wire        btn_left,      // 1-cycle pulses (debounced)
    input  wire        btn_right,
    input  wire        btn_rotate,
    input  wire        btn_down,

    input  wire        spawn,         // 1-cycle: load a new piece
    input  wire [2:0]  spawn_type,

    input  wire [199:0] occ_flat,     // board occupancy, bit = row*10+col

    output reg  signed [4:0] piece_col,   // may be slightly negative
    output reg  [4:0]  piece_row,
    output reg  [1:0]  rotation,
    output reg  [2:0]  piece_type,
    output wire [15:0] shape_bitmap,
    output wire [2:0]  piece_color,

    output reg         piece_lock,    // 1-cycle: piece has landed
    output wire        spawn_blocked, // valid 1 cycle after spawn: no room

    output wire        moved,         // 1-cycle: left/right/rotate succeeded
    output wire        move_rejected  // 1-cycle: left/right/rotate was blocked
);

    localparam COLS = 10;
    localparam ROWS = 20;

    // ---- shape lookups: current and "if rotated" ----
    piece_rom rom_current (
        .piece_type(piece_type), .rotation(rotation),
        .shape_bitmap(shape_bitmap), .piece_color(piece_color)
    );

    wire [1:0]  next_rotation = rotation + 2'd1;
    wire [15:0] shape_bitmap_next_rot;
    wire [2:0]  unused_color_next;
    piece_rom rom_next_rot (
        .piece_type(piece_type), .rotation(next_rotation),
        .shape_bitmap(shape_bitmap_next_rot), .piece_color(unused_color_next)
    );

    // ---- game tick: 2-flop synchroniser + rising-edge detect ----
    reg clk_game_sync0, clk_game_sync1, clk_game_prev;
    wire game_tick = clk_game_sync1 & ~clk_game_prev;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_game_sync0 <= 1'b0;
            clk_game_sync1 <= 1'b0;
            clk_game_prev  <= 1'b0;
        end else begin
            clk_game_sync0 <= clk_game;
            clk_game_sync1 <= clk_game_sync0;
            clk_game_prev  <= clk_game_sync1;
        end
    end

    // ---- the single, row-wise collision checker ----
    // Returns 1 if the 4x4 shape placed with its top-left at (col,row)
    // leaves the board (left/right/bottom) or overlaps a filled cell.
    //
    // 'wide' is the piece row slice shifted into a 20-bit window in
    // which window bit (abs_col + 4) represents board column abs_col:
    //   bits [3:0]   -> columns -4..-1  (left of the board)  => wall
    //   bits [13:4]  -> columns  0..9   (the board itself)
    //   bits [19:14] -> columns 10..15  (right of the board) => wall
    function collide;
        input signed [5:0] col;
        input [4:0]        row;
        input [15:0]       bmp;
        input [199:0]      occ;
        integer r;
        reg [3:0]  nib;
        reg [19:0] wide;
        reg [4:0]  sh;
        reg [4:0]  ar;
        reg [9:0]  orow;
        begin
            collide = 1'b0;
            sh = col[4:0] + 5'd4;               // (col + 4) mod 32, always 0..31 here
            for (r = 0; r < 4; r = r + 1) begin
                // nib[c] = shape bit at (row r, local column c)
                nib  = {bmp[12-4*r], bmp[13-4*r], bmp[14-4*r], bmp[15-4*r]};
                wide = {16'b0, nib} << sh;
                ar   = row + r[4:0];
                if (nib != 4'b0) begin
                    if (wide[3:0] != 4'b0 || wide[19:14] != 6'b0)
                        collide = 1'b1;                       // side wall
                    if (ar >= ROWS)
                        collide = 1'b1;                       // floor
                    else if ((wide[13:4] & occ[ar*COLS +: COLS]) != 10'b0)
                        collide = 1'b1;                       // locked cell
                end
            end
        end
    endfunction

    // ---- pick the ONE action for this cycle (same priority as before) ----
    localparam A_CUR = 3'd0, A_DOWN = 3'd1, A_ROT = 3'd2, A_LEFT = 3'd3, A_RIGHT = 3'd4;

    reg spawn_chk;   // high the cycle after a spawn
    reg [2:0] act;
    always @(*) begin
        if      (spawn_chk)  act = A_CUR;     // check the freshly spawned piece
        else if (game_tick)  act = A_DOWN;
        else if (btn_rotate) act = A_ROT;
        else if (btn_left)   act = A_LEFT;
        else if (btn_right)  act = A_RIGHT;
        else if (btn_down)   act = A_DOWN;
        else                 act = A_CUR;
    end

    wire signed [5:0] col6  = $signed({piece_col[4], piece_col});
    wire signed [5:0] c_col = (act == A_LEFT)  ? col6 - 6'sd1 :
                              (act == A_RIGHT) ? col6 + 6'sd1 : col6;
    wire [4:0]  c_row = (act == A_DOWN) ? piece_row + 5'd1 : piece_row;
    wire [15:0] c_bmp = (act == A_ROT)  ? shape_bitmap_next_rot : shape_bitmap;

    wire collision = collide(c_col, c_row, c_bmp, occ_flat);

    assign spawn_blocked = spawn_chk & collision;

    // A deliberate left/right/rotate attempt that succeeded, or one
    // that was blocked by a wall or a locked cell. (A_DOWN/A_CUR are
    // excluded -- those have their own lock/spawn-check meaning, not
    // a "did the player's move work" one.)
    wire is_move_action = (act == A_LEFT) || (act == A_RIGHT) || (act == A_ROT);
    assign moved         = is_move_action && !spawn_chk && !collision;
    assign move_rejected = is_move_action && !spawn_chk &&  collision;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            piece_col  <= 5'sd3;
            piece_row  <= 5'd0;
            rotation   <= 2'd0;
            piece_type <= 3'd0;
            piece_lock <= 1'b0;
            spawn_chk  <= 1'b0;
        end else begin
            piece_lock <= 1'b0;
            spawn_chk  <= spawn;

            if (spawn) begin
                piece_col  <= 5'sd3;
                piece_row  <= 5'd0;
                rotation   <= 2'd0;
                piece_type <= spawn_type;
            end else if (!spawn_chk) begin
                case (act)
                    A_DOWN:  if (!collision) piece_row <= piece_row + 5'd1;
                             else            piece_lock <= 1'b1;
                    A_ROT:   if (!collision) rotation   <= next_rotation;
                    A_LEFT:  if (!collision) piece_col  <= piece_col - 5'sd1;
                    A_RIGHT: if (!collision) piece_col  <= piece_col + 5'sd1;
                    default: ;
                endcase
            end
        end
    end

endmodule