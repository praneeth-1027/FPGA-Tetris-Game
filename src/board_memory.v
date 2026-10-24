// ============================================================
// board_memory.v  (LUT-optimised)
// Stores the Tetris playfield (10 cols x 20 rows).
//
//   cells[]   : 3-bit colour per cell (0 = empty). Read by the VGA
//               driver (rd_*) and by the line-clear copy loop (sh_*).
//   occ       : 1 bit per cell, "is this cell filled?". Collision logic
//               only needs this, so it reads a 200-bit bus instead of
//               the old 600-bit colour bus (3x less routing/muxing).
//   full_rows : combinational "row is completely filled" flags, so the
//               game FSM no longer has to scan rows one by one.
//
// Clearing: reset (async) and soft_clear (synchronous) BOTH clear the
// board. In the earlier version soft_clear was OR-ed into an
// asynchronous-reset branch, which simulates but is not valid
// synthesizable Verilog (Vivado/Yosys reject or mis-implement it).
// ============================================================
module board_memory(
    input  wire        clk,
    input  wire        reset,        // async, clears everything
    input  wire        soft_clear,   // sync 1-cycle pulse: new game

    // single write port (used by board_ctrl)
    input  wire        we,
    input  wire [3:0]  wr_col,       // 0-9
    input  wire [4:0]  wr_row,       // 0-19
    input  wire [2:0]  wr_color,

    // read port 1: VGA renderer (combinational)
    input  wire [3:0]  rd_col,
    input  wire [4:0]  rd_row,
    output wire [2:0]  rd_color,

    // read port 2: line-clear row copy (combinational)
    input  wire [3:0]  sh_col,
    input  wire [4:0]  sh_row,
    output wire [2:0]  sh_color,

    // occupancy: bit (row*10 + col) is 1 if that cell is filled
    output wire [199:0] occ_flat,
    // bit r is 1 if row r is completely filled
    output wire [19:0]  full_rows
);

    localparam COLS = 10;
    localparam ROWS = 20;

    reg [2:0]   cells [0:(ROWS*COLS)-1];
    reg [199:0] occ;

    integer i;
    wire [7:0] wr_idx = wr_row * COLS + wr_col;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < ROWS*COLS; i = i + 1)
                cells[i] <= 3'b000;
            occ <= 200'b0;
        end else if (soft_clear) begin
            for (i = 0; i < ROWS*COLS; i = i + 1)
                cells[i] <= 3'b000;
            occ <= 200'b0;
        end else if (we) begin
            cells[wr_idx] <= wr_color;
            occ[wr_idx]   <= (wr_color != 3'b000);
        end
    end

    assign rd_color = cells[rd_row*COLS + rd_col];
    assign sh_color = cells[sh_row*COLS + sh_col];
    assign occ_flat = occ;

    genvar gr;
    generate
        for (gr = 0; gr < ROWS; gr = gr + 1) begin : row_full
            assign full_rows[gr] = &occ[gr*COLS +: COLS];
        end
    endgenerate

endmodule