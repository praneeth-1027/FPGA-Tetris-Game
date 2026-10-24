// Tetris event sequencer with midpoint PWM audio for PmodAMP2.
// Supported clock: 25 MHz; AMPLITUDE must be in 0..127.
module tone_gen #(
    parameter CLK_HZ = 25_000_000,
    parameter [7:0] AMPLITUDE = 8'd16
)(
    input  wire clk,
    input  wire reset,

    input  wire trig_lock,       // 1-cycle pulse: piece just locked
    input  wire trig_clear,      // 1-cycle pulse: one line was cleared
                                   // (pulse this once per line -- see
                                   // integration note in tetris_top.v)
    input  wire game_over,        // level signal (stays high)

    input  wire trig_move,          // 1-cycle: left/right/rotate succeeded
    input  wire trig_move_rejected, // 1-cycle: left/right/rotate blocked
    input  wire trig_new_high_score,// 1-cycle: score just beat the old high
    input  wire trig_restart,       // 1-cycle: a new game just started

    output reg  pwm_out = 1'b0
);

    // ---- Note frequency -> divisor lookup ----
    // divisor = CLK_HZ / (2 * freq_hz); toggling tone_level every
    // 'divisor' cycles produces a square wave at freq_hz.
    function [19:0] freq_div;
        input [15:0] freq_hz;
        begin
            // Constant divisions synthesize as a mux, not a runtime divider.
            case (freq_hz)
                100: freq_div = CLK_HZ / 200;
                180: freq_div = CLK_HZ / 360;
                262: freq_div = CLK_HZ / 524;
                330: freq_div = CLK_HZ / 660;
                392: freq_div = CLK_HZ / 784;
                523: freq_div = CLK_HZ / 1046;
                659: freq_div = CLK_HZ / 1318;
                784: freq_div = CLK_HZ / 1568;
                800: freq_div = CLK_HZ / 1600;
                1047: freq_div = CLK_HZ / 2094;
                default: freq_div = 20'd1;
            endcase
        end
    endfunction

    // ---- Note duration -> cycle count lookup ----
    function [23:0] dur_cycles;
        input [15:0] ms;
        begin
            dur_cycles = (CLK_HZ / 1000) * ms;
        end
    endfunction

    // ---- Sequence definitions ----
    // Each sequence is up to 3 notes: {freq_hz, duration_ms}.
    // A freq_hz of 0 means "silence" for that note's duration
    // (used to shorten a sequence to fewer than 3 notes).
    localparam SEQ_NONE      = 3'd0;
    localparam SEQ_LOCK      = 3'd1;
    localparam SEQ_CLEAR     = 3'd2;
    localparam SEQ_OVER      = 3'd3;
    localparam SEQ_TICK      = 3'd4;
    localparam SEQ_THUD      = 3'd5;
    localparam SEQ_HIGHSCORE = 3'd6;
    localparam SEQ_RESTART   = 3'd7;

    // Priority, highest to lowest: OVER > RESTART > HIGHSCORE >
    // CLEAR > LOCK > THUD > TICK. Encoded as a number so a single
    // comparison can decide "does the new trigger outrank whatever
    // is currently playing" instead of a long if/else chain repeated
    // per trigger.
    function [2:0] seq_priority;
        input [2:0] s;
        begin
            case (s)
                SEQ_OVER:      seq_priority = 3'd7;
                SEQ_RESTART:   seq_priority = 3'd6;
                SEQ_HIGHSCORE: seq_priority = 3'd5;
                SEQ_CLEAR:     seq_priority = 3'd4;
                SEQ_LOCK:      seq_priority = 3'd3;
                SEQ_THUD:      seq_priority = 3'd2;
                SEQ_TICK:      seq_priority = 3'd1;
                default:       seq_priority = 3'd0; // SEQ_NONE
            endcase
        end
    endfunction

    reg tone_level = 1'b0;
    reg [2:0] active_seq = 3'd0;
    // 3 bits, not 2 -- a sequence can have up to 4 notes (indices
    // 0-3), so advancing PAST the last note must be able to reach
    // index 4 to correctly fall through to the default/seq_done
    // case. With only 2 bits, 3+1 wraps back to 0 instead of
    // reaching 4, which made the 4-note HIGHSCORE tune loop forever
    // instead of ever finishing -- caught by simulation, not
    // obvious from reading the code.
    reg [2:0] note_idx = 3'd0;         // 0,1,2,3 within the current sequence
    reg [23:0] dur_counter = 24'd0;
    reg [19:0] toggle_counter = 20'd0;
    reg        prev_game_over = 1'b0;

    // Current note's frequency and duration, selected by
    // (active_seq, note_idx). freq=0 (NOTE_SILENT) means no tone.
    reg [15:0] cur_freq_hz;
    reg [15:0] cur_dur_ms;
    reg        seq_done; // true once note_idx has played the last note

    always @(*) begin
        cur_freq_hz = 16'd0;
        cur_dur_ms  = 16'd0;
        seq_done    = 1'b0;
        case (active_seq)
            SEQ_LOCK: begin
                case (note_idx)
                    2'd0: begin cur_freq_hz = 16'd180; cur_dur_ms = 16'd70; end
                    default: seq_done = 1'b1;
                endcase
            end
            SEQ_CLEAR: begin
                case (note_idx)
                    2'd0: begin cur_freq_hz = 16'd523; cur_dur_ms = 16'd70; end // C5
                    2'd1: begin cur_freq_hz = 16'd659; cur_dur_ms = 16'd90; end // E5
                    default: seq_done = 1'b1;
                endcase
            end
            SEQ_OVER: begin
                case (note_idx)
                    2'd0: begin cur_freq_hz = 16'd392; cur_dur_ms = 16'd150; end // G4
                    2'd1: begin cur_freq_hz = 16'd330; cur_dur_ms = 16'd150; end // E4
                    2'd2: begin cur_freq_hz = 16'd262; cur_dur_ms = 16'd300; end // C4
                    default: seq_done = 1'b1;
                endcase
            end
            SEQ_TICK: begin
                // very short, high -- deliberately unobtrusive since
                // this can fire on nearly every button press
                case (note_idx)
                    2'd0: begin cur_freq_hz = 16'd800; cur_dur_ms = 16'd20; end
                    default: seq_done = 1'b1;
                endcase
            end
            SEQ_THUD: begin
                // short, low -- a "no" buzz for a blocked move
                case (note_idx)
                    2'd0: begin cur_freq_hz = 16'd100; cur_dur_ms = 16'd40; end
                    default: seq_done = 1'b1;
                endcase
            end
            SEQ_HIGHSCORE: begin
                // 4-note rising arpeggio -- deliberately bigger than
                // the 2-note CLEAR chirp, for a "big moment" feel
                case (note_idx)
                    2'd0: begin cur_freq_hz = 16'd523; cur_dur_ms = 16'd70;  end // C5
                    2'd1: begin cur_freq_hz = 16'd659; cur_dur_ms = 16'd70;  end // E5
                    2'd2: begin cur_freq_hz = 16'd784; cur_dur_ms = 16'd70;  end // G5
                    2'd3: begin cur_freq_hz = 16'd1047;cur_dur_ms = 16'd150; end // C6
                    default: seq_done = 1'b1;
                endcase
            end
            SEQ_RESTART: begin
                // short 2-note "ready!" up-chirp
                case (note_idx)
                    2'd0: begin cur_freq_hz = 16'd392; cur_dur_ms = 16'd90; end // G4
                    2'd1: begin cur_freq_hz = 16'd523; cur_dur_ms = 16'd90; end // C5
                    default: seq_done = 1'b1;
                endcase
            end
            default: seq_done = 1'b1;
        endcase
    end

    wire [19:0] cur_divisor = (cur_freq_hz == 0) ? 20'd1 : freq_div(cur_freq_hz);
    wire [23:0] cur_duration = dur_cycles(cur_dur_ms);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            active_seq      <= SEQ_NONE;
            note_idx         <= 2'd0;
            dur_counter      <= 24'd0;
            toggle_counter   <= 20'd0;
            tone_level          <= 1'b0;
            prev_game_over   <= 1'b0;
        end else begin
            prev_game_over <= game_over;

            // ---- Trigger priority: a new trigger only cuts in if its
            // tune outranks whatever is currently playing (strictly
            // higher priority), otherwise it's dropped. This single
            // table-driven check replaces repeating the same
            // "only if nothing more important is active" condition
            // by hand for every individual trigger. ----
            if (game_over && !prev_game_over &&
                seq_priority(SEQ_OVER) > seq_priority(active_seq)) begin
                active_seq <= SEQ_OVER;
                note_idx <= 2'd0; dur_counter <= 24'd0; toggle_counter <= 20'd0; tone_level <= 1'b0;
            end else if (trig_restart &&
                seq_priority(SEQ_RESTART) > seq_priority(active_seq)) begin
                active_seq <= SEQ_RESTART;
                note_idx <= 2'd0; dur_counter <= 24'd0; toggle_counter <= 20'd0; tone_level <= 1'b0;
            end else if (trig_new_high_score &&
                seq_priority(SEQ_HIGHSCORE) > seq_priority(active_seq)) begin
                active_seq <= SEQ_HIGHSCORE;
                note_idx <= 2'd0; dur_counter <= 24'd0; toggle_counter <= 20'd0; tone_level <= 1'b0;
            end else if (trig_clear &&
                seq_priority(SEQ_CLEAR) > seq_priority(active_seq)) begin
                active_seq <= SEQ_CLEAR;
                note_idx <= 2'd0; dur_counter <= 24'd0; toggle_counter <= 20'd0; tone_level <= 1'b0;
            end else if (trig_lock &&
                seq_priority(SEQ_LOCK) > seq_priority(active_seq)) begin
                active_seq <= SEQ_LOCK;
                note_idx <= 2'd0; dur_counter <= 24'd0; toggle_counter <= 20'd0; tone_level <= 1'b0;
            end else if (trig_move_rejected &&
                seq_priority(SEQ_THUD) > seq_priority(active_seq)) begin
                active_seq <= SEQ_THUD;
                note_idx <= 2'd0; dur_counter <= 24'd0; toggle_counter <= 20'd0; tone_level <= 1'b0;
            end else if (trig_move &&
                seq_priority(SEQ_TICK) > seq_priority(active_seq)) begin
                active_seq <= SEQ_TICK;
                note_idx <= 2'd0; dur_counter <= 24'd0; toggle_counter <= 20'd0; tone_level <= 1'b0;
            end else if (active_seq != SEQ_NONE) begin
                // ---- Advance playback of whatever is active ----
                if (seq_done) begin
                    active_seq <= SEQ_NONE;
                    tone_level    <= 1'b0;
                end else if (dur_counter >= cur_duration - 1'b1) begin
                    // this note finished; move to the next one
                    dur_counter    <= 24'd0;
                    toggle_counter <= 20'd0;
                    note_idx       <= note_idx + 3'd1;
                    tone_level <= 1'b0;
                end else begin
                    dur_counter <= dur_counter + 24'd1;
                    if (cur_freq_hz == 0) begin
                        tone_level <= 1'b0; // silent note
                    end else if (toggle_counter >= cur_divisor - 1'b1) begin
                        toggle_counter <= 20'd0;
                        tone_level        <= ~tone_level;
                    end else begin
                        toggle_counter <= toggle_counter + 20'd1;
                    end
                end
            end
        end
    end

// PWM DAC: 25 MHz / 256 = 97.65625 kHz.
    // Silence is a constant 50% duty carrier. Sound varies duty around
    // midpoint, exactly as in the supplied amp_sound reference.
    wire [7:0] audio_sample =
        (active_seq == SEQ_NONE || seq_done || cur_freq_hz == 0) ? 8'd128 :
        tone_level ? (8'd128 + AMPLITUDE) : (8'd128 - AMPLITUDE);
    reg [7:0] pwm_count = 8'd0;
    reg [7:0] pwm_duty = 8'd128;
    wire [7:0] next_pwm_count = pwm_count + 8'd1;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pwm_count <= 8'd0;
            pwm_duty <= 8'd128;
            pwm_out <= 1'b0;
        end else begin
            pwm_count <= next_pwm_count;
            if (pwm_count == 8'd255) begin
                pwm_duty <= audio_sample;
                pwm_out <= (audio_sample != 8'd0);
            end else begin
                pwm_out <= (next_pwm_count < pwm_duty);
            end
        end
    end
endmodule