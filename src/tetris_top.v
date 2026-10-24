// ============================================================
// tetris_top.v
// Top-level module for the FPGA Tetris game. Wires together:
//   - clk_divider   : derives clk25 (VGA) and clk_game (fall rate)
//                     from the board's oscillator
//   - debounce (x4) : cleans up raw push-button inputs
//   - board_ctrl    : all game logic (piece movement, locking,
//                     line-clear, scoring) -- internally owns
//                     board_memory, piece_ctrl, and piece_gen
//   - vga_controller: generates VGA timing (hsync/vsync/pixel coords)
//   - vga_driver    : converts pixel coords + board state into RGB
//
// Board pin names below (clk_in, btn_*, hsync, vsync, vga_red/
// green/blue) are typical for a Basys 3 / Nexys A7 style board;
// adjust to match your actual constraints (.xdc) file pin names.
// ============================================================
module tetris_top(
    input  wire clk_in,        // board oscillator (e.g. 100 MHz)
    input  wire btn_reset,     // active-high reset button
    input  wire btn_left_raw,
    input  wire btn_right_raw,
    input  wire btn_rotate_raw,
    input  wire btn_down_raw,

    output wire hsync,
    output wire vsync,
    output wire [3:0] vga_red,
    output wire [3:0] vga_green,
    output wire [3:0] vga_blue,

    output wire [6:0] seg,      // seven-segment segments (active-low)
    output wire [3:0] an,       // seven-segment digit select (active-low)

    output wire amp_gain,
    output wire amp_enable,
    output wire audio_pwm,      // to PmodAMP2's AIN pin (any free Pmod port)

    input  wire ble_rxd         // from PmodBLE's TXD pin (pin 3) -- the
                                 // phone app's button presses arrive here
                                 // as single ASCII bytes over BLE UART
);

    // AMP2 pin 2 HIGH selects 6 dB; pin 4 HIGH enables amplifier.
    assign amp_gain = 1'b1;
    assign amp_enable = !btn_reset;

    // ---- Clocking ----
    wire clk25;
    wire clk_game;

    clk_divider #(
        .CLK_IN_FREQ(100_000_000),
        .GAME_TICK_HZ(2)  // piece falls twice per second; tune for difficulty
    ) clkdiv (
        .clk_in(clk_in),
        .reset(btn_reset),
        .clk25(clk25),
        .clk_game(clk_game)
    );

    // ---- Button debouncing ----
    // NOTE: debounce/board_ctrl logic runs on clk25 here for
    // simplicity (one clock domain for all game logic + display).
    // clk_in itself (100MHz) could be used instead for snappier
    // response; either works since debounce cycle count is
    // independent of clock frequency choice.
    wire btn_left_phys, btn_right_phys, btn_rotate_phys, btn_down_phys;

    debounce db_left   (.clk(clk25), .reset(btn_reset), .btn_raw(btn_left_raw),   .btn_pulse(btn_left_phys));
    debounce db_right  (.clk(clk25), .reset(btn_reset), .btn_raw(btn_right_raw),  .btn_pulse(btn_right_phys));
    debounce db_rotate (.clk(clk25), .reset(btn_reset), .btn_raw(btn_rotate_raw), .btn_pulse(btn_rotate_phys));
    debounce db_down   (.clk(clk25), .reset(btn_reset), .btn_raw(btn_down_raw),   .btn_pulse(btn_down_phys));

    // ---- Phone-via-BLE control (PmodBLE, transparent UART) ----
    // No debouncing needed here: UART-decoded commands are already
    // clean single-cycle digital pulses, not noisy mechanical
    // contacts. The decoder's pulses are simply OR'd with the
    // physical buttons' debounced pulses below, so either input
    // source can control the game at any time.
    wire [7:0] ble_data;
    wire       ble_data_valid;
    wire       btn_left_ble, btn_right_ble, btn_rotate_ble, btn_down_ble;

    uart_rx #(
        .CLK_HZ(25_000_000),
        .BAUD(115_200)  // PmodBLE's default transparent-UART baud rate
    ) ble_uart (
        .clk(clk25),
        .reset(btn_reset),
        .rx(ble_rxd),
        .data(ble_data),
        .data_valid(ble_data_valid)
    );

    ble_cmd_decoder ble_dec (
        .clk(clk25),
        .reset(btn_reset),
        .data(ble_data),
        .data_valid(ble_data_valid),
        .btn_left(btn_left_ble),
        .btn_right(btn_right_ble),
        .btn_rotate(btn_rotate_ble),
        .btn_down(btn_down_ble)
    );

    wire btn_left   = btn_left_phys   | btn_left_ble;
    wire btn_right  = btn_right_phys  | btn_right_ble;
    wire btn_rotate = btn_rotate_phys | btn_rotate_ble;
    wire btn_down   = btn_down_phys   | btn_down_ble;

    // ---- Game logic ----
    wire [3:0] rd_col;
    wire [4:0] rd_row;
    wire [2:0] rd_color;

    wire signed [4:0] piece_col;
    wire [4:0]        piece_row;
    wire [15:0]       shape_bitmap;
    wire [2:0]        piece_color;

    wire [15:0] score;
    wire [15:0] high_score;
    wire [7:0]  lines_cleared;
    wire        game_over;

    wire        sfx_lock;
    wire        sfx_line_clear;
    wire        sfx_move;
    wire        sfx_move_rejected;
    wire        sfx_new_high_score;
    wire        sfx_restart;

    wire [15:0] next1_shape_bitmap;
    wire [2:0]  next1_piece_color;
    wire [15:0] next2_shape_bitmap;
    wire [2:0]  next2_piece_color;
    wire [15:0] next3_shape_bitmap;
    wire [2:0]  next3_piece_color;

    board_ctrl bctrl (
        .clk(clk25),
        .reset(btn_reset),
        .clk_game(clk_game),
        .btn_left(btn_left),
        .btn_right(btn_right),
        .btn_rotate(btn_rotate),
        .btn_down(btn_down),
        .rd_col(rd_col),
        .rd_row(rd_row),
        .rd_color(rd_color),
        .piece_col(piece_col),
        .piece_row(piece_row),
        .shape_bitmap(shape_bitmap),
        .piece_color(piece_color),
        .next1_shape_bitmap(next1_shape_bitmap),
        .next1_piece_color(next1_piece_color),
        .next2_shape_bitmap(next2_shape_bitmap),
        .next2_piece_color(next2_piece_color),
        .next3_shape_bitmap(next3_shape_bitmap),
        .next3_piece_color(next3_piece_color),
        .score(score),
        .high_score(high_score),
        .lines_cleared(lines_cleared),
        .game_over(game_over),
        .sfx_lock(sfx_lock),
        .sfx_line_clear(sfx_line_clear),
        .sfx_move(sfx_move),
        .sfx_move_rejected(sfx_move_rejected),
        .sfx_new_high_score(sfx_new_high_score),
        .sfx_restart(sfx_restart)
    );

    // ---- Seven-segment score display ----
    seven_seg_driver ssd (
        .clk(clk25),
        .reset(btn_reset),
        .score(score),
        .seg(seg),
        .an(an)
    );

    // ---- VGA output ----
    wire video_on;
    wire [9:0] pixel_x, pixel_y;

    vga_controller vgactl (
        .clk25(clk25),
        .reset(btn_reset),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    vga_driver vdrv (
        .clk25(clk25),
        .video_on(video_on),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .rd_col(rd_col),
        .rd_row(rd_row),
        .cell_color(rd_color),
        .piece_col(piece_col),
        .piece_row(piece_row),
        .shape_bitmap(shape_bitmap),
        .piece_color(piece_color),
        .next1_shape_bitmap(next1_shape_bitmap),
        .next1_piece_color(next1_piece_color),
        .next2_shape_bitmap(next2_shape_bitmap),
        .next2_piece_color(next2_piece_color),
        .next3_shape_bitmap(next3_shape_bitmap),
        .next3_piece_color(next3_piece_color),
        .score(score),
        .high_score(high_score),
        .game_over(game_over),
        .red(vga_red),
        .green(vga_green),
        .blue(vga_blue)
    );

    // ---- Sound effects ----
    tone_gen #(
        .CLK_HZ(25_000_000)  // driven from clk25, same clock as everything else
    ) sfx (
        .clk(clk25),
        .reset(btn_reset),
        .trig_lock(sfx_lock),
        .trig_clear(sfx_line_clear),
        .game_over(game_over),
        .trig_move(sfx_move),
        .trig_move_rejected(sfx_move_rejected),
        .trig_new_high_score(sfx_new_high_score),
        .trig_restart(sfx_restart),
        .pwm_out(audio_pwm)
    );

endmodule