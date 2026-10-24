// ============================================================
// clk_divider.v
// Generates:
//   1) clk25   - 25 MHz pixel clock for VGA (from 100 MHz input)
//   2) clk_game - slow clock for game logic (piece fall rate)
//
// Assumes board input clock = 100 MHz (change CLK_IN_FREQ if
// your board uses a different oscillator, e.g. 50 MHz).
// ============================================================
module clk_divider #(
    parameter CLK_IN_FREQ   = 100_000_000, // input clock frequency (Hz)
    parameter GAME_TICK_HZ  = 2            // piece fall rate (Hz) - adjust for difficulty
)(
    input  wire clk_in,     // board clock (e.g. 100 MHz)
    input  wire reset,      // active-high reset

    output reg  clk25,      // ~25 MHz pixel clock
    output reg  clk_game    // slow game-tick clock (1 clock pulse per fall step)
);

    // ---- clk25 generation: divide by 4 (100MHz / 4 = 25MHz) ----
    // Adjust divisor if CLK_IN_FREQ is not 100MHz
    localparam PIXEL_DIV = CLK_IN_FREQ / 25_000_000 / 2; // toggle divisor
    reg [$clog2(PIXEL_DIV)-1:0] pixel_count;

    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            pixel_count <= 0;
            clk25       <= 0;
        end else if (pixel_count == PIXEL_DIV - 1) begin
            pixel_count <= 0;
            clk25       <= ~clk25;
        end else begin
            pixel_count <= pixel_count + 1;
        end
    end

    // ---- clk_game generation: divide down to GAME_TICK_HZ ----
    localparam GAME_DIV = CLK_IN_FREQ / GAME_TICK_HZ / 2; // toggle divisor
    reg [$clog2(GAME_DIV)-1:0] game_count;

    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            game_count <= 0;
            clk_game   <= 0;
        end else if (game_count == GAME_DIV - 1) begin
            game_count <= 0;
            clk_game   <= ~clk_game;
        end else begin
            game_count <= game_count + 1;
        end
    end

endmodule
