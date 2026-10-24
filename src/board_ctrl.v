// ============================================================
// board_ctrl.v  (LUT-optimised)
// Top-level game FSM: piece lock -> line check -> line clear ->
// spawn, plus scoring, high score, 3-piece preview queue and game
// over / restart.
//
// Changes vs the earlier version (all behaviour-preserving):
//  * score / high_score are stored in BCD (4 decimal digits), so no
//    binary->BCD converters are needed in vga_driver / seven_seg_driver.
//    (Each cleared row adds 100 => one BCD digit increment.)
//  * "row is full" comes straight from board_memory (20 AND gates)
//    instead of scanning rows one per cycle through a 200:1 mux.
//  * S_LOCK walks the 16 shape bits (idx 0..15) rather than searching
//    for the next set bit with 16 comparators.
//  * game-over detection reuses piece_ctrl's collision checker
//    (spawn_blocked) instead of a second 16-lookup checker here.
//  * board_memory exposes a 200-bit occupancy bus (1 bit/cell) instead
//    of a 600-bit colour bus.
// ============================================================
module board_ctrl(
    input  wire clk,
    input  wire reset,
    input  wire clk_game,

    input  wire btn_left,
    input  wire btn_right,
    input  wire btn_rotate,
    input  wire btn_down,

    // board read port for the VGA renderer
    input  wire [3:0]  rd_col,
    input  wire [4:0]  rd_row,
    output wire [2:0]  rd_color,

    output wire signed [4:0] piece_col,
    output wire [4:0]        piece_row,
    output wire [15:0]       shape_bitmap,
    output wire [2:0]        piece_color,

    // 3-piece preview queue (index 1 spawns first)
    output wire [15:0]       next1_shape_bitmap,
    output wire [2:0]        next1_piece_color,
    output wire [15:0]       next2_shape_bitmap,
    output wire [2:0]        next2_piece_color,
    output wire [15:0]       next3_shape_bitmap,
    output wire [2:0]        next3_piece_color,

    output reg  [15:0] score,        // BCD: 0x0000 .. 0x9999
    output reg  [15:0] high_score,   // BCD
    output reg  [7:0]  lines_cleared,
    output reg         game_over,

    // ---- Sound-effect triggers (for tone_gen) ----
    output wire         sfx_lock,       // 1-cycle pulse: a piece just locked
    output reg          sfx_line_clear, // 1-cycle pulse: ONE line was removed
                                         // (fires once per row -- a multi-row
                                         // clear naturally produces multiple
                                         // pulses in quick succession)
    output wire         sfx_move,          // 1-cycle: left/right/rotate succeeded
    output wire         sfx_move_rejected, // 1-cycle: left/right/rotate blocked
    output wire         sfx_new_high_score,// 1-cycle: score just beat the old high
    output reg          sfx_restart        // 1-cycle: a new game just started
);

    // sfx_lock forwards piece_ctrl's own lock pulse, gated by FSM
    // state. WHY the gate is needed: btn_* inputs are wired straight
    // into piece_ctrl ungated by board_ctrl's state (true in this
    // design since its original version -- piece_ctrl has no
    // awareness of board_ctrl's FSM). In the rare case where a
    // button is still asserted for a cycle or two after the FSM has
    // already left S_FALLING to process the lock, piece_ctrl can
    // re-assert piece_lock again since it is still sitting at the
    // same (now-irrelevant) blocked position. That stray repeat
    // pulse doesn't affect gameplay (board_ctrl has already moved
    // on and ignores it), but it WOULD cause an extra, spurious
    // "blip" sound -- so sfx_lock only forwards the pulse while
    // still actually in S_FALLING.
    assign sfx_lock = pc_piece_lock && (state == S_FALLING);

    localparam COLS = 10;
    localparam ROWS = 20;

    // ---- FSM states (numeric values used by testbenches) ----
    localparam S_FALLING   = 3'd0;
    localparam S_LOCK      = 3'd1;
    localparam S_LINE_CHK  = 3'd2;
    localparam S_CLEAR     = 3'd3;
    localparam S_SPAWN     = 3'd4;
    localparam S_GAME_OVER = 3'd5;
    localparam S_INIT      = 3'd6;

    reg [2:0] state;
    reg [2:0] init_count;
    reg       is_restart;   // power-on init vs restart-after-game-over

    // ---- board memory ----
    reg        bm_we;
    reg  [3:0] bm_wr_col;
    reg  [4:0] bm_wr_row;
    reg  [2:0] bm_wr_color;
    reg        bm_soft_clear;
    wire [3:0] sh_col;
    wire [4:0] sh_row;
    wire [2:0] sh_color;
    wire [199:0] occ_flat;
    wire [19:0]  mem_full_rows;

    board_memory bmem (
        .clk(clk), .reset(reset), .soft_clear(bm_soft_clear),
        .we(bm_we), .wr_col(bm_wr_col), .wr_row(bm_wr_row), .wr_color(bm_wr_color),
        .rd_col(rd_col), .rd_row(rd_row), .rd_color(rd_color),
        .sh_col(sh_col), .sh_row(sh_row), .sh_color(sh_color),
        .occ_flat(occ_flat), .full_rows(mem_full_rows)
    );

    // ---- random piece generator ----
    reg        pg_next;
    wire [2:0] pg_piece_type;
    piece_gen pgen (.clk(clk), .reset(reset), .next(pg_next), .piece_type(pg_piece_type));

    // ---- 3-deep preview queue ----
    reg [2:0] queue0, queue1, queue2;
    reg       refill_wait, refill_pending;

    piece_rom preview_rom1 (.piece_type(queue0), .rotation(2'd0),
        .shape_bitmap(next1_shape_bitmap), .piece_color(next1_piece_color));
    piece_rom preview_rom2 (.piece_type(queue1), .rotation(2'd0),
        .shape_bitmap(next2_shape_bitmap), .piece_color(next2_piece_color));
    piece_rom preview_rom3 (.piece_type(queue2), .rotation(2'd0),
        .shape_bitmap(next3_shape_bitmap), .piece_color(next3_piece_color));

    // ---- falling piece ----
    reg        pc_spawn;
    reg  [2:0] pc_spawn_type;
    wire       pc_piece_lock;
    wire       spawn_blocked;
    wire [2:0] pc_piece_type;
    wire [1:0] pc_rotation;
    wire       pc_moved, pc_move_rejected;

    piece_ctrl pctrl (
        .clk(clk), .reset(reset), .clk_game(clk_game),
        .btn_left(btn_left), .btn_right(btn_right),
        .btn_rotate(btn_rotate), .btn_down(btn_down),
        .spawn(pc_spawn), .spawn_type(pc_spawn_type),
        .occ_flat(occ_flat),
        .piece_col(piece_col), .piece_row(piece_row),
        .rotation(pc_rotation), .piece_type(pc_piece_type),
        .shape_bitmap(shape_bitmap), .piece_color(piece_color),
        .piece_lock(pc_piece_lock), .spawn_blocked(spawn_blocked),
        .moved(pc_moved), .move_rejected(pc_move_rejected)
    );

    // Same state-gating reasoning as sfx_lock: only forward these
    // while actually in S_FALLING, so a stray button signal that
    // reaches piece_ctrl after board_ctrl has already moved on can't
    // produce a spurious tick/thud.
    assign sfx_move          = pc_moved         && (state == S_FALLING);
    assign sfx_move_rejected = pc_move_rejected && (state == S_FALLING);

    // Fires for exactly the one cycle score first overtakes the old
    // high_score (see the high_score update logic below -- this is
    // the same comparison, just also exposed as an event pulse).
    assign sfx_new_high_score = (score > high_score);

    // ---- BCD helper: +100 (one hundreds-digit increment, saturating) ----
    function [15:0] bcd_add100;
        input [15:0] v;
        begin
            if (v[11:8] != 4'd9)
                bcd_add100 = {v[15:12], v[11:8] + 4'd1, v[7:0]};
            else if (v[15:12] != 4'd9)
                bcd_add100 = {v[15:12] + 4'd1, 4'd0, v[7:0]};
            else
                bcd_add100 = 16'h9999;
        end
    endfunction

    // ---- line-clear bookkeeping ----
    reg [19:0] full_rows;          // rows still waiting to be removed
    reg        chk_wait;
    reg        clearing_in_progress;
    reg [4:0]  clear_target;
    reg [4:0]  shift_src_row;
    reg [3:0]  shift_col;
    reg [3:0]  lock_idx;

    // source cell for the row copy: the row above the one being written
    assign sh_row = shift_src_row - 5'd1;
    assign sh_col = shift_col;

    wire any_full_remaining = |full_rows;
    reg  [4:0] clear_target_found;   // topmost (lowest index) full row
    integer k;
    always @(*) begin
        clear_target_found = 5'd0;
        for (k = ROWS-1; k >= 0; k = k - 1)
            if (full_rows[k]) clear_target_found = k[4:0];
    end

    // =========================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_INIT;   init_count <= 3'd0;  is_restart <= 1'b0;
            bm_we <= 1'b0;     bm_soft_clear <= 1'b0;
            bm_wr_col <= 4'd0; bm_wr_row <= 5'd0;   bm_wr_color <= 3'd0;
            pc_spawn <= 1'b0;  pc_spawn_type <= 3'd0;
            pg_next <= 1'b0;
            score <= 16'h0000; high_score <= 16'h0000;
            lines_cleared <= 8'd0; game_over <= 1'b0; sfx_line_clear <= 1'b0; sfx_restart <= 1'b0;
            queue0 <= 3'd0; queue1 <= 3'd0; queue2 <= 3'd0;
            refill_wait <= 1'b0; refill_pending <= 1'b0;
            full_rows <= 20'd0; chk_wait <= 1'b0;
            clearing_in_progress <= 1'b0;
            clear_target <= 5'd0; shift_src_row <= 5'd0; shift_col <= 4'd0;
            lock_idx <= 4'd0;
        end else begin
            bm_we <= 1'b0;  bm_soft_clear <= 1'b0;
            pc_spawn <= 1'b0;  pg_next <= 1'b0;
            sfx_line_clear <= 1'b0;
            sfx_restart    <= 1'b0;

            // session high score (BCD values compare like binary)
            if (score > high_score)
                high_score <= score;

            // queue refill: capture piece_gen 2 cycles after pg_next pulses
            // (LFSR updates one cycle, its combinational output shows it
            // the cycle after -- verified in simulation)
            if (refill_wait) begin
                refill_wait <= 1'b0;  refill_pending <= 1'b1;
            end else if (refill_pending) begin
                queue2 <= pg_piece_type;  refill_pending <= 1'b0;
            end

            case (state)
                // ---- warm up the 3-piece queue after reset / restart ----
                S_INIT: begin
                    case (init_count)
                        3'd0: begin queue0 <= pg_piece_type; pg_next <= 1'b1; init_count <= 3'd1; end
                        3'd1: init_count <= 3'd2;
                        3'd2: begin queue1 <= pg_piece_type; pg_next <= 1'b1; init_count <= 3'd3; end
                        3'd3: init_count <= 3'd4;
                        3'd4: begin
                            queue2 <= pg_piece_type;
                            init_count <= 3'd5;
                            state <= is_restart ? S_SPAWN : S_FALLING;
                        end
                        default: state <= S_FALLING;
                    endcase
                end

                S_FALLING: begin
                    if (pc_piece_lock) begin
                        lock_idx <= 4'd0;
                        state    <= S_LOCK;
                    end else if (spawn_blocked) begin
                        game_over <= 1'b1;
                        state     <= S_GAME_OVER;
                    end
                end

                // ---- write the landed piece into the board, one shape bit per cycle ----
                S_LOCK: begin
                    if (shape_bitmap[15 - lock_idx]) begin
                        bm_we       <= 1'b1;
                        // NOTE: piece_col is signed and must NOT be
                        // sliced to [3:0] before adding -- an earlier
                        // version of this design had exactly this bug
                        // (found and fixed for the O-piece at the left
                        // wall). Zero-extend the 2-bit local-column
                        // index to 3 bits BEFORE the signed cast --
                        // $signed() directly on a 2-bit value would
                        // misread 2/3 (binary 10/11) as negative,
                        // since bit[1] would become the sign bit.
                        bm_wr_col   <= piece_col + $signed({1'b0, lock_idx[1:0]});
                        bm_wr_row   <= piece_row + {3'b000, lock_idx[3:2]};
                        bm_wr_color <= piece_color;
                    end
                    if (lock_idx == 4'd15) begin
                        chk_wait <= 1'b0;
                        state    <= S_LINE_CHK;
                    end else
                        lock_idx <= lock_idx + 4'd1;
                end

                // ---- latch which rows are full (1 wait cycle: last write lands) ----
                S_LINE_CHK: begin
                    if (!chk_wait)
                        chk_wait <= 1'b1;
                    else begin
                        full_rows <= mem_full_rows;
                        chk_wait  <= 1'b0;
                        state     <= S_CLEAR;
                    end
                end

                // ---- remove full rows: copy every row above down by one ----
                S_CLEAR: begin
                    if (!any_full_remaining) begin
                        state <= S_SPAWN;
                    end else if (!clearing_in_progress) begin
                        clear_target  <= clear_target_found;
                        shift_src_row <= clear_target_found;
                        shift_col     <= 4'd0;
                        clearing_in_progress <= 1'b1;
                    end else begin
                        bm_we       <= 1'b1;
                        bm_wr_col   <= shift_col;
                        bm_wr_row   <= shift_src_row;
                        bm_wr_color <= (shift_src_row == 5'd0) ? 3'b000 : sh_color;

                        if (shift_col == COLS-1) begin
                            shift_col <= 4'd0;
                            if (shift_src_row == 5'd0) begin
                                full_rows[clear_target] <= 1'b0;
                                lines_cleared <= lines_cleared + 8'd1;
                                sfx_line_clear <= 1'b1;
                                score         <= bcd_add100(score);
                                clearing_in_progress <= 1'b0;
                            end else
                                shift_src_row <= shift_src_row - 5'd1;
                        end else
                            shift_col <= shift_col + 4'd1;
                    end
                end

                // ---- next piece comes from the queue ----
                S_SPAWN: begin
                    pc_spawn      <= 1'b1;
                    pc_spawn_type <= queue0;
                    queue0 <= queue1;
                    queue1 <= queue2;
                    pg_next <= 1'b1;
                    refill_wait <= 1'b1;
                    state <= S_FALLING;
                end

                // ---- any button restarts; high_score is kept ----
                S_GAME_OVER: begin
                    if (btn_left || btn_right || btn_rotate || btn_down) begin
                        bm_soft_clear <= 1'b1;
                        score         <= 16'h0000;
                        lines_cleared <= 8'd0;
                        game_over     <= 1'b0;
                        init_count    <= 3'd0;
                        is_restart    <= 1'b1;
                        sfx_restart   <= 1'b1;
                        state         <= S_INIT;
                    end
                end

                default: state <= S_FALLING;
            endcase
        end
    end

endmodule