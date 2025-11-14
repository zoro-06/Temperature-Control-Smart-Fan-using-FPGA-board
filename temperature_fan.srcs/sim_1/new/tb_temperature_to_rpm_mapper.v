`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2025 10:59:42 PM
// Design Name: 
// Module Name: tb_temperature_to_rpm_mapper
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


`timescale 1ns / 1ps

`timescale 1ns / 1ps

module tb_temperature_to_rpm_mapper;

    //==========================================================================
    // TESTBENCH SIGNALS
    //==========================================================================
    reg         clk;
    reg         rst_n;
    reg         control_tick;
    reg  [15:0] temp_raw;
    reg  [15:0] rpm_measured;
    wire [15:0] target_rpm;
    wire [11:0] duty_out;
    
    //==========================================================================
    // INSTANTIATE DUT (Device Under Test)
    //==========================================================================
    temperature_to_rpm_mapper #(
        .Kp_SCALED(128),
        .Ki_SCALED(32),
        .INTEGRAL_LIMIT(50000)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .control_tick(control_tick),
        .temp_raw(temp_raw),
        .rpm_measured(rpm_measured),
        .target_rpm(target_rpm),
        .duty_out(duty_out)
    );
    
    //==========================================================================
    // CLOCK GENERATION (100MHz)
    //==========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end
    
    //==========================================================================
    // CONTROL TICK GENERATION (Faster for simulation: 1ms period)
    // In real hardware this would be 10Hz (100ms), but we use 1ms for faster sim
    //==========================================================================
    initial begin
        control_tick = 0;
        #50;  // Initial delay
        forever begin
            #1_000_000 control_tick = 1;  // 1ms (1000us)
            #100 control_tick = 0;
            #1_000_000;  // Complete the period
        end
    end
    
    //==========================================================================
    // HELPER FUNCTION: Convert Celsius to Q4 format
    // Q4 format: 4 fractional bits, so multiply by 16
    //==========================================================================
    function [15:0] celsius_to_q4;
        input integer temp_c;
        begin
            celsius_to_q4 = temp_c << 4;  // Multiply by 16
        end
    endfunction
    
    //==========================================================================
    // HELPER TASK: Wait for N control ticks
    //==========================================================================
    task wait_control_ticks;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge control_tick);
                @(negedge control_tick);
            end
        end
    endtask
    
    //==========================================================================
    // HELPER TASK: Display current state
    //==========================================================================
    task display_status;
        input [80*8-1:0] msg;
        begin
            $display("--------------------------------------------------");
            $display("%s", msg);
            $display("Time: %0t ns", $time);
            $display("Temp: %0d°C (raw=0x%h)", temp_raw>>4, temp_raw);
            $display("RPM Measured: %0d, Target: %0d", rpm_measured, target_rpm);
            $display("Duty: %0d/4095 (%0d%%)", duty_out, (duty_out*100)/4095);
            $display("Speed State: %0d", dut.speed_state);
            $display("--------------------------------------------------");
        end
    endtask
    
    //==========================================================================
    // MAIN TEST SEQUENCE
    //==========================================================================
    initial begin
        // VCD dump for waveform viewing
        $dumpfile("temp_rpm_mapper.vcd");
        $dumpvars(0, tb_temperature_to_rpm_mapper);
        
        // Initialize signals
        rst_n = 0;
        temp_raw = celsius_to_q4(20);  // Start at 20°C
        rpm_measured = 0;
        
        $display("\n========== TESTBENCH START ==========\n");
        
        // Reset sequence
        #100;
        rst_n = 1;
        #100;
        
        //======================================================================
        // TEST 1: Temperature below threshold (OFF state)
        //======================================================================
        $display("\n===== TEST 1: Temperature at 20°C (below OFF threshold) =====");
        temp_raw = celsius_to_q4(20);
        wait_control_ticks(5);  // Wait for filter to settle
        display_status("After settling at 20°C");
        
        // Verify OFF state
        if (duty_out == 0 && target_rpm == 0)
            $display("✓ PASS: Fan is OFF");
        else
            $display("✗ FAIL: Fan should be OFF");
        
        //======================================================================
        // TEST 2: Temperature rises to turn fan ON (23°C → 26°C)
        //======================================================================
        $display("\n===== TEST 2: Temperature rising 23°C → 26°C =====");
        temp_raw = celsius_to_q4(23);
        wait_control_ticks(5);
        display_status("At 23°C (below hysteresis)");
        
        temp_raw = celsius_to_q4(26);
        wait_control_ticks(5);
        display_status("At 26°C (above hysteresis - should turn ON)");
        
        // Verify LOW state activated (duty will be high initially due to PI controller)
        if (target_rpm == 800)
            $display("✓ PASS: Fan turned ON to LOW speed (target=800 RPM)");
        else
            $display("✗ FAIL: Fan should be at LOW speed");
        
        // Note: duty_out will be high initially because PI controller sees large error
        $display("INFO: Duty=%0d%% (PI controller responding to error)", (duty_out*100)/4095);
        
        //======================================================================
        // TEST 3: Simulate fan reaching target RPM
        //======================================================================
        $display("\n===== TEST 3: Fan reaching target RPM (PI control test) =====");
        rpm_measured = 600;  // Start below target
        wait_control_ticks(2);
        display_status("RPM at 600 (below target 800)");
        
        rpm_measured = 750;
        wait_control_ticks(2);
        display_status("RPM at 750 (approaching target)");
        
        rpm_measured = 800;  // Reached target
        wait_control_ticks(3);
        display_status("RPM at 800 (at target)");
        
        // Duty should stabilize near base duty when RPM matches target
        if (duty_out >= 1000 && duty_out <= 1200)
            $display("✓ PASS: PI controller stabilized");
        else
            $display("✗ FAIL: Duty out of expected range");
        
        //======================================================================
        // TEST 4: Temperature drops - test hysteresis
        //======================================================================
        $display("\n===== TEST 4: Temperature drops to 24°C (hysteresis test) =====");
        temp_raw = celsius_to_q4(24);
        wait_control_ticks(5);
        display_status("At 24°C (above lower threshold 23°C)");
        
        // Should stay in LOW state due to hysteresis
        if (target_rpm == 800)
            $display("✓ PASS: Hysteresis working - still at LOW");
        else
            $display("✗ FAIL: Should maintain LOW speed");
        
        temp_raw = celsius_to_q4(22);
        wait_control_ticks(5);
        display_status("At 22°C (below lower threshold)");
        
        // Should turn OFF now
        if (duty_out == 0 && target_rpm == 0)
            $display("✓ PASS: Fan turned OFF");
        else
            $display("✗ FAIL: Fan should be OFF");
        
        //======================================================================
        // TEST 5: Jump to high temperature
        //======================================================================
        $display("\n===== TEST 5: Temperature jumps to 51°C =====");
        temp_raw = celsius_to_q4(51);
        rpm_measured = 0;  // Fan starting from stopped
        wait_control_ticks(6);
        display_status("At 51°C (HIGH state expected)");
        
        // Verify HIGH state
        if (duty_out == 4095 && target_rpm == 2400)
            $display("✓ PASS: Fan at HIGH speed");
        else
            $display("✗ FAIL: Fan should be at HIGH speed");
        
        //======================================================================
        // TEST 6: Simulate fan spinning up to high speed
        //======================================================================
        $display("\n===== TEST 6: Fan spinning up to high speed =====");
        rpm_measured = 1000;
        wait_control_ticks(2);
        display_status("RPM at 1000");
        
        rpm_measured = 1800;
        wait_control_ticks(2);
        display_status("RPM at 1800");
        
        rpm_measured = 2400;  // Reached target
        wait_control_ticks(3);
        display_status("RPM at 2400 (target reached)");
        
        //======================================================================
        // TEST 7: Temperature drops to transition states
        //======================================================================
        $display("\n===== TEST 7: Temperature drops 51°C → 47°C =====");
        temp_raw = celsius_to_q4(47);
        wait_control_ticks(5);
        display_status("At 47°C (below HIGH threshold)");
        
        // Should drop to LOW state
        if (target_rpm == 800)
            $display("✓ PASS: Transitioned to LOW state");
        else
            $display("✗ FAIL: Should be in LOW state");
        
        //======================================================================
        // TEST 8: Moving average filter test
        //======================================================================
        $display("\n===== TEST 8: Moving average filter test =====");
        temp_raw = celsius_to_q4(30);
        wait_control_ticks(1);
        temp_raw = celsius_to_q4(35);
        wait_control_ticks(1);
        temp_raw = celsius_to_q4(25);
        wait_control_ticks(1);
        temp_raw = celsius_to_q4(30);
        wait_control_ticks(2);
        display_status("After temperature fluctuations");
        $display("Average temp: %0d°C", dut.temp_avg >> 4);
        
        //======================================================================
        // TEST 9: Reset test
        //======================================================================
        $display("\n===== TEST 9: Reset functionality =====");
        rst_n = 0;
        #200;
        rst_n = 1;
        #100;
        display_status("After reset");
        
        if (duty_out == 0 && target_rpm == 0 && dut.speed_state == 0)
            $display("✓ PASS: Reset successful");
        else
            $display("✗ FAIL: Reset incomplete");
        
        //======================================================================
        // TEST COMPLETE
        //======================================================================
        #1000;
        $display("\n========== TESTBENCH COMPLETE ==========\n");
        $finish;
    end
    
    //==========================================================================
    // TIMEOUT WATCHDOG (Increased for longer tests)
    //==========================================================================
    initial begin
        #500_000_000;  // 100ms timeout (was 500ms, reduced for faster fail)
        $display("\n✗ TESTBENCH TIMEOUT - Simulation took too long!");
        $finish;
    end
    
endmodule
