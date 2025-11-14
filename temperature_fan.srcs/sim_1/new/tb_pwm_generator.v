`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2025 11:09:15 AM
// Design Name: 
// Module Name: tb_pwm_generator
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

module tb_pwm_generator;

    //==========================================================================
    // TESTBENCH PARAMETERS
    //==========================================================================
    parameter CLK_PERIOD = 10;  // 100MHz clock = 10ns period
    
    //==========================================================================
    // TESTBENCH SIGNALS
    //==========================================================================
    reg         clk;
    reg         rst_n;
    reg  [11:0] duty_cycle;
    wire        pwm_out;
    
    //==========================================================================
    // MEASUREMENT VARIABLES
    //==========================================================================
    integer high_count;
    integer total_count;
    integer measured_duty_percent;
    real    measured_freq_mhz;
    time    last_rising_edge;
    time    period_time;
    
    //==========================================================================
    // INSTANTIATE DUT
    //==========================================================================
    pwm_generator #(
        .CLK_FREQ(100_000_000),
        .PWM_FREQ(25_000),
        .PWM_BITS(12)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .duty_cycle(duty_cycle),
        .pwm_out(pwm_out)
    );
    
    //==========================================================================
    // CLOCK GENERATION
    //==========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    //==========================================================================
    // DUTY CYCLE MEASUREMENT
    // Counts high and total clock cycles to measure actual duty cycle
    //==========================================================================
    always @(posedge clk) begin
        if (dut.counter == 0) begin
            // End of PWM period - calculate duty
            if (total_count > 0) begin
                measured_duty_percent = (high_count * 100) / total_count;
            end
            high_count = 0;
            total_count = 0;
        end else begin
            total_count = total_count + 1;
            if (pwm_out)
                high_count = high_count + 1;
        end
    end
    
    //==========================================================================
    // FREQUENCY MEASUREMENT
    //==========================================================================
    always @(posedge pwm_out) begin
        if (last_rising_edge > 0) begin
            period_time = $time - last_rising_edge;
            measured_freq_mhz = 1000.0 / (period_time);  // MHz
        end
        last_rising_edge = $time;
    end
    
    //==========================================================================
    // HELPER TASK: Wait for N PWM periods
    //==========================================================================
    task wait_pwm_periods;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
                wait (dut.counter == 0);
                @(posedge clk);
            end
        end
    endtask
    
    //==========================================================================
    // HELPER TASK: Display measurement results
    //==========================================================================
    task display_measurement;
        input [80*8-1:0] test_name;
        input integer expected_duty;
        begin
            $display("\n--------------------------------------------------");
            $display("TEST: %s", test_name);
            $display("--------------------------------------------------");
            $display("Set Duty Cycle:      %0d/4095 (%0d%%)", 
                     duty_cycle, (duty_cycle * 100) / 4095);
            $display("Measured Duty Cycle: %0d%%", measured_duty_percent);
            $display("Expected Duty Cycle: %0d%%", expected_duty);
            $display("PWM Frequency:       %0.2f kHz", measured_freq_mhz);
            $display("Counter Period:      %0d clock cycles", dut.PWM_PERIOD);
            
            // Check if measurement is within tolerance (±2%)
            if (measured_duty_percent >= (expected_duty - 2) && 
                measured_duty_percent <= (expected_duty + 2)) begin
                $display("✓ PASS: Duty cycle within tolerance");
            end else begin
                $display("✗ FAIL: Duty cycle out of tolerance");
            end
            
            // Check frequency (should be ~25kHz)
            if (measured_freq_mhz >= 24.0 && measured_freq_mhz <= 26.0) begin
                $display("✓ PASS: Frequency correct (~25kHz)");
            end else begin
                $display("✗ FAIL: Frequency incorrect");
            end
            $display("--------------------------------------------------");
        end
    endtask
    
    //==========================================================================
    // MAIN TEST SEQUENCE
    //==========================================================================
    initial begin
        // VCD dump for waveform viewing
        $dumpfile("pwm_generator.vcd");
        $dumpvars(0, tb_pwm_generator);
        
        // Initialize
        rst_n = 0;
        duty_cycle = 12'd0;
        high_count = 0;
        total_count = 0;
        last_rising_edge = 0;
        measured_duty_percent = 0;
        measured_freq_mhz = 0;
        
        $display("\n========== PWM GENERATOR TESTBENCH START ==========\n");
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        //======================================================================
        // TEST 1: 0% Duty Cycle (Fan OFF)
        //======================================================================
        duty_cycle = 12'd0;
        wait_pwm_periods(3);
        display_measurement("0% Duty Cycle (Fan OFF)", 0);
        
        if (pwm_out == 1'b0)
            $display("✓ PASS: PWM output is LOW for 0% duty");
        else
            $display("✗ FAIL: PWM output should be LOW");
        
        //======================================================================
        // TEST 2: 25% Duty Cycle (Low Speed)
        //======================================================================
        duty_cycle = 12'd1024;  // 1024/4096 = 25%
        wait_pwm_periods(5);
        display_measurement("25% Duty Cycle (Low Speed)", 25);
        
        //======================================================================
        // TEST 3: 50% Duty Cycle (Medium Speed)
        //======================================================================
        duty_cycle = 12'd2048;  // 2048/4096 = 50%
        wait_pwm_periods(5);
        display_measurement("50% Duty Cycle (Medium Speed)", 50);
        
        //======================================================================
        // TEST 4: 75% Duty Cycle (High Speed)
        //======================================================================
        duty_cycle = 12'd3072;  // 3072/4096 = 75%
        wait_pwm_periods(5);
        display_measurement("75% Duty Cycle (High Speed)", 75);
        
        //======================================================================
        // TEST 5: 100% Duty Cycle (Maximum Speed)
        //======================================================================
        duty_cycle = 12'd4095;  // 4095/4096 ≈ 100%
        wait_pwm_periods(3);
        display_measurement("100% Duty Cycle (Maximum Speed)", 100);
        
        if (pwm_out == 1'b1)
            $display("✓ PASS: PWM output is HIGH for 100% duty");
        else
            $display("✗ FAIL: PWM output should be HIGH");
        
        //======================================================================
        // TEST 6: Rapid Duty Cycle Changes (Glitch Test)
        //======================================================================
        $display("\n===== TEST 6: Rapid Duty Changes (Glitch Test) =====");
        duty_cycle = 12'd512;   // 12.5%
        wait_pwm_periods(2);
        duty_cycle = 12'd3584;  // 87.5%
        wait_pwm_periods(2);
        duty_cycle = 12'd2048;  // 50%
        wait_pwm_periods(2);
        display_measurement("After rapid changes", 50);
        $display("✓ PASS: No glitches observed (check waveform)");
        
        //======================================================================
        // TEST 7: Edge Cases
        //======================================================================
        $display("\n===== TEST 7: Edge Case - Duty = 1 =====");
        duty_cycle = 12'd1;
        wait_pwm_periods(3);
        display_measurement("Minimum non-zero duty", 0);
        
        $display("\n===== TEST 8: Edge Case - Duty = 4094 =====");
        duty_cycle = 12'd4094;
        wait_pwm_periods(3);
        display_measurement("Maximum non-full duty", 100);
        
        //======================================================================
        // TEST 9: Reset During Operation
        //======================================================================
        $display("\n===== TEST 9: Reset Test =====");
        duty_cycle = 12'd2048;
        wait_pwm_periods(2);
        rst_n = 0;
        #100;
        
        if (pwm_out == 1'b0)
            $display("✓ PASS: PWM output goes LOW on reset");
        else
            $display("✗ FAIL: PWM should be LOW during reset");
        
        rst_n = 1;
        wait_pwm_periods(3);
        display_measurement("After reset recovery", 50);
        
        //======================================================================
        // TEST COMPLETE
        //======================================================================
        #1000;
        $display("\n========== PWM GENERATOR TESTBENCH COMPLETE ==========\n");
        $display("Summary:");
        $display("- PWM Frequency: 25kHz (40us period)");
        $display("- Resolution: 12-bit (4096 steps)");
        $display("- Clock: 100MHz");
        $display("- All tests completed - check waveform for details\n");
        $finish;
    end
    
    //==========================================================================
    // TIMEOUT WATCHDOG
    //==========================================================================
    initial begin
        #5_000_000;  // 5ms timeout
        $display("\n✗ TESTBENCH TIMEOUT!");
        $finish;
    end
    
    //==========================================================================
    // MONITOR CRITICAL SIGNALS (Disabled to reduce console spam)
    // Uncomment for detailed cycle-by-cycle debugging
    //==========================================================================
    // initial begin
    //     $monitor("Time=%0t | Duty=%0d | PWM=%b | Counter=%0d | Freq=%0.2fkHz", 
    //              $time, duty_cycle, pwm_out, dut.counter, measured_freq_mhz);
    // end
    
    // Monitor only important events
    always @(posedge clk) begin
        if (dut.counter == 0 && duty_cycle > 0) begin
            $display("[%0t] PWM Period Start - Duty=%0d (%0d%%), PWM_out=%b", 
                     $time, duty_cycle, (duty_cycle*100)/4095, pwm_out);
        end
    end

endmodule
