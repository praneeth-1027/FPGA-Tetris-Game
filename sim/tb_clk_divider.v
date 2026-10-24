// ============================================================
// tb_clk_divider.v
// Verifies clk25 toggles at correct rate relative to clk_in.
// Uses a small GAME_TICK_HZ divisor override for fast simulation.
// ============================================================
`timescale 1ns/1ps

module tb_clk_divider;

    reg clk_in = 0;
    reg reset  = 1;
    wire clk25, clk_game;

    // 100 MHz input clock -> period = 10 ns
    always #5 clk_in = ~clk_in;

    // Override GAME_TICK_HZ to something fast for simulation purposes
    clk_divider #(
        .CLK_IN_FREQ(100_000_000),
        .GAME_TICK_HZ(1000)   // fast tick just for sim visibility
    ) uut (
        .clk_in(clk_in),
        .reset(reset),
        .clk25(clk25),
        .clk_game(clk_game)
    );

    integer edge_count = 0;
    real t_prev = 0;

    always @(posedge clk25) begin
        if (edge_count > 0)
            $display("clk25 posedge at t=%0t  (period=%0t ns)", $time, $time - t_prev);
        t_prev = $time;
        edge_count = edge_count + 1;
    end

    initial begin
        #20 reset = 0;
        #2000;  // run long enough to see several clk25 edges
        $display("---- clk_game check ----");
        #500000; // run further to see a clk_game edge
        $finish;
    end

    always @(posedge clk_game) begin
        $display("clk_game posedge at t=%0t", $time);
    end

endmodule
