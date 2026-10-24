// ============================================================
// vga_controller.v
// Generates VGA timing signals for 640x480 @ 60Hz
// Pixel clock required: 25 MHz
// ============================================================
module vga_controller(
    input  wire        clk25,       // 25 MHz pixel clock
    input  wire        reset,       // active-high reset

    output wire        hsync,       // horizontal sync (active low)
    output wire        vsync,       // vertical sync (active low)
    output wire        video_on,    // high when pixel_x/pixel_y are in visible area
    output wire [9:0]  pixel_x,     // current pixel column (0-639 when video_on)
    output wire [9:0]  pixel_y      // current pixel row    (0-479 when video_on)
);

    // ---- Horizontal timing (in pixels) ----
    localparam H_DISPLAY   = 640;
    localparam H_FRONT     = 16;
    localparam H_SYNC      = 96;
    localparam H_BACK      = 48;
    localparam H_TOTAL     = H_DISPLAY + H_FRONT + H_SYNC + H_BACK; // 800

    // ---- Vertical timing (in lines) ----
    localparam V_DISPLAY   = 480;
    localparam V_FRONT     = 10;
    localparam V_SYNC      = 2;
    localparam V_BACK      = 33;
    localparam V_TOTAL     = V_DISPLAY + V_FRONT + V_SYNC + V_BACK; // 525

    reg [9:0] h_count;
    reg [9:0] v_count;

    // ---- Horizontal counter ----
    always @(posedge clk25 or posedge reset) begin
        if (reset)
            h_count <= 10'd0;
        else if (h_count == H_TOTAL - 1)
            h_count <= 10'd0;
        else
            h_count <= h_count + 10'd1;
    end

    // ---- Vertical counter (increments once per horizontal line) ----
    always @(posedge clk25 or posedge reset) begin
        if (reset)
            v_count <= 10'd0;
        else if (h_count == H_TOTAL - 1) begin
            if (v_count == V_TOTAL - 1)
                v_count <= 10'd0;
            else
                v_count <= v_count + 10'd1;
        end
    end

    // ---- Sync pulses (active low) ----
    assign hsync = ~((h_count >= H_DISPLAY + H_FRONT) &&
                      (h_count <  H_DISPLAY + H_FRONT + H_SYNC));

    assign vsync = ~((v_count >= V_DISPLAY + V_FRONT) &&
                      (v_count <  V_DISPLAY + V_FRONT + V_SYNC));

    // ---- Visible area flag ----
    assign video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);

    // ---- Pixel coordinates (valid only when video_on = 1) ----
    assign pixel_x = h_count;
    assign pixel_y = v_count;

endmodule
