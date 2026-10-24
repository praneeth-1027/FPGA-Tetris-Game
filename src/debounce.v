// ============================================================
// debounce.v
// Debounces a noisy mechanical push-button input and produces
// a single clean 1-cycle pulse each time the button is pressed.
//
// Method: sample the raw input through a shift register; once
// it's been stable at '1' for DEBOUNCE_CYCLES consecutive
// samples, treat it as a confirmed press and emit one pulse.
// The button must return to a confirmed '0' before another
// press can be registered (prevents repeat-fire while held).
// ============================================================
module debounce #(
    parameter DEBOUNCE_CYCLES = 16 // consecutive stable samples required
)(
    input  wire clk,
    input  wire reset,
    input  wire btn_raw,     // raw, noisy button input (active high)
    output reg  btn_pulse    // 1-cycle pulse on confirmed press
);

    reg [$clog2(DEBOUNCE_CYCLES+1)-1:0] stable_count;
    reg confirmed_state; // debounced steady-state value
    reg prev_confirmed;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            stable_count    <= 0;
            confirmed_state <= 1'b0;
            prev_confirmed  <= 1'b0;
            btn_pulse       <= 1'b0;
        end else begin
            btn_pulse <= 1'b0; // default low; pulses only on confirmed rising edge

            if (btn_raw == confirmed_state) begin
                // input matches current confirmed state -- reset counter
                stable_count <= 0;
            end else begin
                // input differs from confirmed state -- count stability
                if (stable_count == DEBOUNCE_CYCLES - 1) begin
                    confirmed_state <= btn_raw;
                    stable_count    <= 0;
                end else begin
                    stable_count <= stable_count + 1;
                end
            end

            prev_confirmed <= confirmed_state;
            if (confirmed_state && !prev_confirmed)
                btn_pulse <= 1'b1; // rising edge of confirmed state
        end
    end

endmodule
