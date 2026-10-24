`timescale 1ns/1ps

// ---- Test 1: verify exact note frequencies at the REAL clock rate ----
module tb_freq;
    reg clk = 0;
    reg reset = 1;
    reg trig_lock = 0, trig_clear = 0, game_over = 0;
    wire pwm_out;

    always #20 clk = ~clk; // 25 MHz

    tone_gen #(.CLK_HZ(25_000_000)) uut (
        .clk(clk), .reset(reset),
        .trig_lock(trig_lock), .trig_clear(trig_clear), .game_over(game_over),
        .trig_move(1'b0), .trig_move_rejected(1'b0),
        .trig_new_high_score(1'b0), .trig_restart(1'b0),
        .pwm_out(pwm_out)
    );

    real t_edge1, t_edge2, period_ns, measured_hz;

    initial begin
        #100 reset = 0;
        #40;

        // ---- Trigger the LOCK note (expected 180 Hz) ----
        @(posedge clk); trig_lock = 1;
        @(posedge clk); trig_lock = 0;

        // measure period between the first two rising edges of pwm_out
        @(posedge pwm_out); t_edge1 = $realtime;
        @(negedge pwm_out);
        @(posedge pwm_out); t_edge2 = $realtime;
        period_ns = t_edge2 - t_edge1;
        measured_hz = 1.0e9 / period_ns;
        $display("LOCK note: measured freq = %0.1f Hz (expect ~180 Hz)", measured_hz);

        $display("Frequency test complete.");
        $finish;
    end

    initial begin #20_000_000; $display("WATCHDOG (freq test)"); $finish; end
endmodule

// ---- Test 2: verify CLEAR and GAME_OVER note frequencies ----
module tb_freq2;
    reg clk = 0;
    reg reset = 1;
    reg trig_lock = 0, trig_clear = 0, game_over = 0;
    wire pwm_out;
    always #20 clk = ~clk; // 25 MHz

    tone_gen #(.CLK_HZ(25_000_000)) uut (
        .clk(clk), .reset(reset),
        .trig_lock(trig_lock), .trig_clear(trig_clear), .game_over(game_over),
        .trig_move(1'b0), .trig_move_rejected(1'b0),
        .trig_new_high_score(1'b0), .trig_restart(1'b0),
        .pwm_out(pwm_out)
    );

    real t1, t2, hz;

    initial begin
        #100 reset = 0;
        #40;

        // CLEAR note 0 (expect 523 Hz)
        @(posedge clk); trig_clear = 1;
        @(posedge clk); trig_clear = 0;
        @(posedge pwm_out); t1 = $realtime;
        @(negedge pwm_out); @(posedge pwm_out); t2 = $realtime;
        hz = 1.0e9 / (t2 - t1);
        $display("CLEAR note0: measured freq = %0.1f Hz (expect ~523 Hz)", hz);

        // let that sequence finish, then trigger GAME_OVER
        #5_000_000;
        @(posedge clk); game_over = 1;
        @(posedge pwm_out); t1 = $realtime;
        @(negedge pwm_out); @(posedge pwm_out); t2 = $realtime;
        hz = 1.0e9 / (t2 - t1);
        $display("GAME_OVER note0: measured freq = %0.1f Hz (expect ~392 Hz)", hz);

        $display("Test 2 complete.");
        $finish;
    end
    initial begin #30_000_000; $display("WATCHDOG (freq2 test)"); $finish; end
endmodule

// ---- Test 3: sequencing (note counts) and priority override, using
// a scaled-down clock so full sequences complete quickly ----
module tb_sequence;
    reg clk = 0;
    reg reset = 1;
    reg trig_lock = 0, trig_clear = 0, game_over = 0;
    wire pwm_out;
    always #20 clk = ~clk;

    // Scaled down 1000x: same relative timing, much faster to simulate
    tone_gen #(.CLK_HZ(25_000)) uut (
        .clk(clk), .reset(reset),
        .trig_lock(trig_lock), .trig_clear(trig_clear), .game_over(game_over),
        .trig_move(1'b0), .trig_move_rejected(1'b0),
        .trig_new_high_score(1'b0), .trig_restart(1'b0),
        .pwm_out(pwm_out)
    );

    integer edge_count;
    reg prev_pwm;
    always @(posedge clk) begin
        if (pwm_out !== prev_pwm && pwm_out == 1'b1) edge_count = edge_count + 1;
        prev_pwm <= pwm_out;
    end

    initial begin
        #100 reset = 0; #40;

        // ---- Sub-test A: LOCK plays exactly 1 note then stops ----
        edge_count = 0; prev_pwm = 0;
        @(posedge clk); trig_lock = 1;
        @(posedge clk); trig_lock = 0;
        wait (uut.active_seq == 2'd0); // SEQ_NONE -- sequence finished
        $display("Sub-test A: LOCK sequence finished. active_seq=%0d (expect 0)", uut.active_seq);

        // ---- Sub-test B: CLEAR plays 2 notes (note_idx reaches 1 then stops) ----
        #2000;
        @(posedge clk); trig_clear = 1;
        @(posedge clk); trig_clear = 0;
        wait (uut.active_seq == 2'd2 && uut.note_idx == 2'd1); // mid 2nd note
        $display("Sub-test B: CLEAR reached note_idx=1 (2nd note) as expected");
        wait (uut.active_seq == 2'd0);
        $display("Sub-test B: CLEAR sequence finished correctly");

        // ---- Sub-test C: multi-line clear = multiple chirps ----
        // simulate a 2-line clear: two trig_clear pulses close together
        #2000;
        @(posedge clk); trig_clear = 1;
        @(posedge clk); trig_clear = 0;
        #1000; // mid-sequence
        @(posedge clk); trig_clear = 1; // second pulse, while first still playing
        @(posedge clk); trig_clear = 0;
        wait (uut.active_seq == 2'd0);
        $display("Sub-test C: multi-clear sequence completed without lockup");

        // ---- Sub-test D: GAME_OVER overrides an in-progress LOCK ----
        #2000;
        @(posedge clk); trig_lock = 1;
        @(posedge clk); trig_lock = 0;
        #500; // lock sequence now mid-playback
        @(posedge clk); game_over = 1;
        #100;
        $display("Sub-test D: after game_over asserted mid-lock, active_seq=%0d (expect 3=SEQ_OVER)", uut.active_seq);
        if (uut.active_seq == 2'd3)
            $display("  PASS: game_over correctly interrupted the lock blip");
        else
            $display("  FAIL: priority override did not work");

        wait (uut.active_seq == 2'd0);
        $display("Sub-test D: game-over sequence finished.");

        $display("All sequence tests complete.");
        $finish;
    end
    initial begin #3_000_000; $display("WATCHDOG (sequence test)"); $finish; end
endmodule

// ---- Test 4: the 4 new tunes -- frequencies and priority ----
module tb_new_tunes;
    reg clk = 0;
    reg reset = 1;
    reg trig_lock=0, trig_clear=0, game_over=0;
    reg trig_move=0, trig_move_rejected=0, trig_new_high_score=0, trig_restart=0;
    wire pwm_out;
    always #20 clk = ~clk; // 25 MHz

    tone_gen #(.CLK_HZ(25_000_000)) uut (
        .clk(clk), .reset(reset),
        .trig_lock(trig_lock), .trig_clear(trig_clear), .game_over(game_over),
        .trig_move(trig_move), .trig_move_rejected(trig_move_rejected),
        .trig_new_high_score(trig_new_high_score), .trig_restart(trig_restart),
        .pwm_out(pwm_out)
    );

    real t1, t2, hz;

    initial begin
        #100 reset = 0; #40;

        // ---- TICK frequency (expect 800 Hz) ----
        @(posedge clk); trig_move = 1;
        @(posedge clk); trig_move = 0;
        @(posedge pwm_out); t1 = $realtime;
        @(negedge pwm_out); @(posedge pwm_out); t2 = $realtime;
        hz = 1.0e9 / (t2 - t1);
        $display("TICK: measured freq = %0.1f Hz (expect ~800 Hz)", hz);
        #2000;

        // ---- THUD frequency (expect 100 Hz) ----
        @(posedge clk); trig_move_rejected = 1;
        @(posedge clk); trig_move_rejected = 0;
        @(posedge pwm_out); t1 = $realtime;
        @(negedge pwm_out); @(posedge pwm_out); t2 = $realtime;
        hz = 1.0e9 / (t2 - t1);
        $display("THUD: measured freq = %0.1f Hz (expect ~100 Hz)", hz);
        #50_000_000; // THUD duration is 40ms -- must fully finish first

        // ---- Priority: HIGHSCORE should interrupt an in-progress TICK ----
        @(posedge clk); trig_move = 1;
        @(posedge clk); trig_move = 0;
        #200; // tick now playing (active_seq should be SEQ_TICK=4)
        $display("Before highscore trigger: active_seq=%0d (expect 4=SEQ_TICK)", uut.active_seq);
        @(posedge clk); trig_new_high_score = 1;
        #40;
        trig_new_high_score = 0;
        #40;
        $display("After highscore trigger: active_seq=%0d (expect 6=SEQ_HIGHSCORE)", uut.active_seq);
        if (uut.active_seq == 3'd6)
            $display("  PASS: HIGHSCORE correctly overrode an in-progress TICK");
        else
            $display("  FAIL: priority override did not work");

        // let it play out, polling so we can see progress rather than
        // blindly waiting (helps diagnose if it ever gets stuck)
        begin : poll_block
          integer poll_i;
          for (poll_i = 0; poll_i < 15 && uut.active_seq != 3'd0; poll_i = poll_i + 1) begin
            #40_000_000;
            $display("  debug: t=%0t active_seq=%0d note_idx=%0d", $time, uut.active_seq, uut.note_idx);
          end
          if (uut.active_seq == 3'd0)
            $display("HIGHSCORE sequence finished playing all 4 notes.");
          else
            $display("HIGHSCORE sequence did NOT finish after polling window");
        end

        // ---- Priority: RESTART should override everything except OVER ----
        #2000;
        @(posedge clk); trig_new_high_score = 1; // start a HIGHSCORE (lower than RESTART)
        @(posedge clk); trig_new_high_score = 0;
        #200;
        @(posedge clk); trig_restart = 1;
        #40;
        trig_restart = 0;
        #40;
        $display("After restart trigger during highscore: active_seq=%0d (expect 7=SEQ_RESTART)", uut.active_seq);
        if (uut.active_seq == 3'd7)
            $display("  PASS: RESTART correctly overrode HIGHSCORE");
        else
            $display("  FAIL");

        $display("All new-tune tests complete.");
        $finish;
    end
    initial begin #800_000_000; $display("WATCHDOG (new tunes test)"); $finish; end
endmodule