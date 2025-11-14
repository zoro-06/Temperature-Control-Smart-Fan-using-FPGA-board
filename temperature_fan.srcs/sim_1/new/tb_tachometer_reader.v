`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2025 11:58:37 AM
// Design Name: 
// Module Name: tb_tachometer_reader
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_tachometer_reader;

    //======================================================================
    // TESTBENCH PARAMETERS
    //======================================================================
    parameter CLK_FREQ = 100_000_000;        // 100 MHz
    parameter UPDATE_RATE = 10;              // 10 Hz (100ms window)
    parameter PULSES_PER_REV = 2;
    parameter DEBOUNCE_TIME_US = 1;          // 1us debounce

    // Derived constants
    localparam integer CLK_PERIOD = 1000000000 / CLK_FREQ;  // 10 ns for 100MHz

    //======================================================================
    // SIGNALS
    //======================================================================
    reg         clk;
    reg         rst_n;
    reg         tach_in;
    wire        update_tick;
    wire [15:0] rpm_out;

    // Test bookkeeping
    integer     test_number;
    integer     expected_rpm;
    integer     error_count;
    integer     test_pass_count;
    integer     i;

    // Background pulse control
    reg start_bg;
    integer bg_rpm;
    integer bg_duration_ms;

    // Timing measurement
    real tick_time_1;
    real tick_time_2;
    real tick_period;

    //======================================================================
    // INSTANTIATE DUT
    //======================================================================
    tachometer_reader #(
        .CLK_FREQ(CLK_FREQ),
        .UPDATE_RATE(UPDATE_RATE),
        .PULSES_PER_REV(PULSES_PER_REV),
        .DEBOUNCE_TIME_US(DEBOUNCE_TIME_US)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tach_in(tach_in),
        .update_tick(update_tick),
        .rpm_out(rpm_out)
    );

    //======================================================================
    // CLOCK GENERATION (100 MHz)
    //======================================================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //======================================================================
    // BACKGROUND PULSE GENERATOR PROCESS
    // This allows starting background pulses without relying on fork..join_none
    //======================================================================
    initial begin
        start_bg = 0;
        forever begin
            @(posedge start_bg);
            // when start_bg is set we'll generate pulses at bg_rpm for bg_duration_ms
            generate_tach_pulses(bg_rpm, bg_duration_ms);
            start_bg = 0; // auto-clear to indicate done
        end
    end

    //======================================================================
    // TASK: generate_tach_pulses
    // Produces realistic tach pulses for a specified RPM and duration (ms)
    // Uses real-valued timing (XSim supports real delays)
    //======================================================================
    task automatic generate_tach_pulses;
        input integer target_rpm;
        input integer duration_ms;
        real pulse_period_ns;
        real pulse_high_time_ns;
        real num_pulses_real;
        integer num_pulses;
        integer j;
    begin
        if (target_rpm == 0) begin
            // No pulses for zero RPM
            tach_in = 1'b0;
            #(duration_ms * 1_000_000);  // wait duration_ms (ms -> ns)
        end else begin
            // period per tach pulse (ns): 60s / (RPM * pulses_per_rev) -> ns
            pulse_period_ns = (60.0 * 1_000_000_000.0) / (target_rpm * PULSES_PER_REV);
            pulse_high_time_ns = pulse_period_ns * 0.40; // 40% duty
            num_pulses_real = (duration_ms * 1_000_000.0) / pulse_period_ns;
            num_pulses = $rtoi(num_pulses_real + 0.5);

            $display("[%0t] TB: Generating %0d pulses for %0d RPM (period=%.1f ns, high=%.1f ns)",
                     $realtime, num_pulses, target_rpm, pulse_period_ns, pulse_high_time_ns);

            for (j = 0; j < num_pulses; j = j + 1) begin
                tach_in = 1'b1;
                #(pulse_high_time_ns);
                tach_in = 1'b0;
                #(pulse_period_ns - pulse_high_time_ns);
            end
        end
    end
    endtask

    //======================================================================
    // TASK: generate_glitch (short spike)
    //======================================================================
    task automatic generate_glitch;
        input integer glitch_width_ns;
    begin
        tach_in = 1'b1;
        #(glitch_width_ns);
        tach_in = 1'b0;
        #(glitch_width_ns);
    end
    endtask

    //======================================================================
    // TASK: verify_rpm
    // Waits for next update_tick and compares reported rpm with expected
    //======================================================================
    task automatic verify_rpm;
        input integer expected;
        input integer tolerance;
        integer actual;
        integer diff;
    begin
        // Wait for an update tick (one measurement window)
        @(posedge update_tick);
        @(posedge clk); // sample one cycle later to let output settle
        actual = rpm_out;
        diff = (actual > expected) ? (actual - expected) : (expected - actual);

        if (diff <= tolerance) begin
            $display("[%0t] PASS: Expected=%0d RPM, Measured=%0d RPM, Error=%0d RPM",
                     $realtime, expected, actual, diff);
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("[%0t] FAIL: Expected=%0d RPM, Measured=%0d RPM, Error=%0d RPM (tol=%0d)",
                     $realtime, expected, actual, diff, tolerance);
            error_count = error_count + 1;
        end
    end
    endtask

    //======================================================================
    // TASK: apply_reset
    //======================================================================
    task automatic apply_reset;
    begin
        rst_n = 1'b0;
        tach_in = 1'b0;
        #(CLK_PERIOD * 10);
        rst_n = 1'b1;
        #(CLK_PERIOD * 5);
        $display("[%0t] TB: Reset applied", $realtime);
    end
    endtask

    //======================================================================
    // MAIN TEST SEQUENCE
    //======================================================================
    initial begin
        // init
        test_number = 0;
        error_count = 0;
        test_pass_count = 0;
        tach_in = 1'b0;
        start_bg = 0;

        $display("\n=== TACHOMETER READER TESTBENCH (Vivado/XSim) ===");
        $display("Clock: %0d Hz, Update Rate: %0d Hz", CLK_FREQ, UPDATE_RATE);
        $display("=================================================\n");

        // TEST 1: Reset
        test_number = 1;
        $display("TEST %0d: Reset behavior", test_number);
        apply_reset();
        #(CLK_PERIOD * 20);
        if (rpm_out == 16'd0) begin
            $display("  PASS: rpm_out initialized to 0");
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  FAIL: rpm_out not 0 after reset (rpm_out=%0d)", rpm_out);
            error_count = error_count + 1;
        end

        // TEST 2: Zero speed detection (no pulses)
        test_number = 2;
        $display("\nTEST %0d: Zero speed detection", test_number);
        tach_in = 1'b0;
        verify_rpm(0, 0);

        // TEST 3: 600 RPM
        test_number = 3;
        expected_rpm = 600;
        $display("\nTEST %0d: %0d RPM", test_number, expected_rpm);
        fork
            generate_tach_pulses(expected_rpm, 100);
            verify_rpm(expected_rpm, 5);
        join

        // TEST 4: 1200 RPM
        test_number = 4;
        expected_rpm = 1200;
        $display("\nTEST %0d: %0d RPM", test_number, expected_rpm);
        fork
            generate_tach_pulses(expected_rpm, 100);
            verify_rpm(expected_rpm, 5);
        join

        // TEST 5: 2400 RPM
        test_number = 5;
        expected_rpm = 2400;
        $display("\nTEST %0d: %0d RPM", test_number, expected_rpm);
        fork
            generate_tach_pulses(expected_rpm, 100);
            verify_rpm(expected_rpm, 10);
        join

        // TEST 6: 3600 RPM
        test_number = 6;
        expected_rpm = 3600;
        $display("\nTEST %0d: %0d RPM", test_number, expected_rpm);
        fork
            generate_tach_pulses(expected_rpm, 100);
            verify_rpm(expected_rpm, 15);
        join

        // TEST 7: Debounce - short glitches should be ignored
        test_number = 7;
        $display("\nTEST %0d: Debounce (glitch rejection)", test_number);
        tach_in = 1'b0;
        #(CLK_PERIOD * 1000);
        $display("  Generating short glitches (500 ns)...");
        for (i = 0; i < 10; i = i + 1) begin
            generate_glitch(500);
            #(CLK_PERIOD * 200);
        end
        verify_rpm(0,0);

        // TEST 8: Update tick timing (start background pulses and measure tick interval)
        test_number = 8;
        $display("\nTEST %0d: Update tick timing", test_number);
        // start background generator at 1200 RPM for 300 ms
        bg_rpm = 1200;
        bg_duration_ms = 300;
        start_bg = 1;
        // wait for first tick and then next
        @(posedge update_tick);
        tick_time_1 = $realtime;
        @(posedge update_tick);
        tick_time_2 = $realtime;
        tick_period = tick_time_2 - tick_time_1;
        $display("  Measured update period = %.1f ms", tick_period/1_000_000.0);
        if ((tick_period >= 99_000_000.0) && (tick_period <= 101_000_000.0)) begin
            $display("  PASS: update tick period ok");
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("  FAIL: update tick period out of tolerance");
            error_count = error_count + 1;
        end
        // ensure background finished before proceeding
        #(400_000_000);

        // TEST 9: Rapid speed changes
        test_number = 9;
        $display("\nTEST %0d: rapid speed changes", test_number);
        $display("  1200 RPM -> 2400 RPM");
        fork
            generate_tach_pulses(1200, 100);
            verify_rpm(1200, 10);
        join
        fork
            generate_tach_pulses(2400, 100);
            verify_rpm(2400, 10);
        join

        // TEST 10: Saturation (very high RPM) - will saturate to 65535 if exceeds
        test_number = 10;
        expected_rpm = 10000;
        $display("\nTEST %0d: saturation test (%0d RPM)", test_number, expected_rpm);
        fork
            generate_tach_pulses(expected_rpm, 100);
            verify_rpm(expected_rpm, 50);
        join

        // TEST 11: Stability - consecutive measurements
        test_number = 11;
        expected_rpm = 1800;
        $display("\nTEST %0d: consecutive stability (%0d RPM)", test_number, expected_rpm);
        fork
            generate_tach_pulses(expected_rpm, 500);
        join_none // use join_none here is not allowed in some flows; replace by synchronous calls below

        // Instead of join_none, sequentially call verify multiple times
        for (i = 0; i < 5; i = i + 1) begin
            verify_rpm(expected_rpm, 10);
        end

        // Final summary
        $display("\n=== TEST SUMMARY ===");
        $display("Total tests executed: %0d", test_pass_count + error_count);
        $display("Passed: %0d", test_pass_count);
        $display("Failed: %0d", error_count);
        if (error_count == 0) $display("ALL TESTS PASSED");
        else                 $display("SOME TESTS FAILED");

        #1000;
        $finish;
    end

    //======================================================================
    // WATCHDOG TIMEOUT
    //======================================================================
    initial begin
        #2000000000; // 2 seconds of simulation time
        $display("ERROR: Simulation timeout!");
        $finish;
    end

    //======================================================================
    // WAVEFORM DUMP (VCD)
    //======================================================================
    initial begin
        $dumpfile("tachometer_reader.vcd");
        $dumpvars(0, tb_tachometer_reader);
    end

    //======================================================================
    // MONITOR: print updates when update_tick pulses
    //======================================================================
    always @(posedge clk) begin
        if (update_tick) begin
            $display("[%0t] UPDATE_TICK: rpm_out=%0d", $realtime, rpm_out);
        end
    end

endmodule
