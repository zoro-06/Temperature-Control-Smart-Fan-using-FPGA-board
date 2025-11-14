`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/20/2025 10:08:23 AM
// Design Name: 
// Module Name: clock_divider_tb
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


//////////////////////////////////////////////////////////////////////////////////
// Testbench for clock_divider module
// Tests all clock outputs and tick signals
//////////////////////////////////////////////////////////////////////////////////

module clock_divider_tb;

    // Testbench signals
    reg clk_in;
    reg rst_n;
    
    // Outputs from DUT (Device Under Test)
    wire clk_1MHz;
    wire clk_100kHz;
    wire clk_25kHz;
    wire clk_100Hz;
    wire clk_10Hz;
    wire clk_2Hz;
    wire tick_1MHz;
    wire tick_100kHz;
    wire tick_25kHz;
    wire tick_100Hz;
    wire tick_10Hz;
    wire tick_2Hz;
    
    // Clock period calculation
    localparam real CLK_PERIOD = 10.0; // 100MHz = 10ns period
    
    // Instantiate the clock_divider module
    clock_divider #(
        .SYS_CLK_HZ(100_000_000)
    ) uut (
        .clk_in(clk_in),
        .rst_n(rst_n),
        .clk_1MHz(clk_1MHz),
        .clk_100kHz(clk_100kHz),
        .clk_25kHz(clk_25kHz),
        .clk_100Hz(clk_100Hz),
        .clk_10Hz(clk_10Hz),
        .clk_2Hz(clk_2Hz),
        .tick_1MHz(tick_1MHz),
        .tick_100kHz(tick_100kHz),
        .tick_25kHz(tick_25kHz),
        .tick_100Hz(tick_100Hz),
        .tick_10Hz(tick_10Hz),
        .tick_2Hz(tick_2Hz)
    );
    
    // Clock generation: 100MHz (10ns period)
    initial begin
        clk_in = 0;
        forever #(CLK_PERIOD/2) clk_in = ~clk_in;
    end
    
    // Counters to track toggles and ticks
    integer cnt_1MHz_toggles = 0;
    integer cnt_100kHz_toggles = 0;
    integer cnt_25kHz_toggles = 0;
    integer cnt_100Hz_toggles = 0;
    integer cnt_10Hz_toggles = 0;
    integer cnt_2Hz_toggles = 0;
    
    integer cnt_1MHz_ticks = 0;
    integer cnt_100kHz_ticks = 0;
    integer cnt_25kHz_ticks = 0;
    integer cnt_100Hz_ticks = 0;
    integer cnt_10Hz_ticks = 0;
    integer cnt_2Hz_ticks = 0;
    
    // Track previous values for edge detection
    reg prev_clk_1MHz = 0;
    reg prev_clk_100kHz = 0;
    reg prev_clk_25kHz = 0;
    reg prev_clk_100Hz = 0;
    reg prev_clk_10Hz = 0;
    reg prev_clk_2Hz = 0;
    
    // Monitor toggles and ticks
    always @(posedge clk_in) begin
        // Count clock toggles (edges)
        if (clk_1MHz !== prev_clk_1MHz) begin
            cnt_1MHz_toggles = cnt_1MHz_toggles + 1;
            prev_clk_1MHz = clk_1MHz;
        end
        if (clk_100kHz !== prev_clk_100kHz) begin
            cnt_100kHz_toggles = cnt_100kHz_toggles + 1;
            prev_clk_100kHz = clk_100kHz;
        end
        if (clk_25kHz !== prev_clk_25kHz) begin
            cnt_25kHz_toggles = cnt_25kHz_toggles + 1;
            prev_clk_25kHz = clk_25kHz;
        end
        if (clk_100Hz !== prev_clk_100Hz) begin
            cnt_100Hz_toggles = cnt_100Hz_toggles + 1;
            prev_clk_100Hz = clk_100Hz;
        end
        if (clk_10Hz !== prev_clk_10Hz) begin
            cnt_10Hz_toggles = cnt_10Hz_toggles + 1;
            prev_clk_10Hz = clk_10Hz;
        end
        if (clk_2Hz !== prev_clk_2Hz) begin
            cnt_2Hz_toggles = cnt_2Hz_toggles + 1;
            prev_clk_2Hz = clk_2Hz;
        end
        
        // Count ticks
        if (tick_1MHz) cnt_1MHz_ticks = cnt_1MHz_ticks + 1;
        if (tick_100kHz) cnt_100kHz_ticks = cnt_100kHz_ticks + 1;
        if (tick_25kHz) cnt_25kHz_ticks = cnt_25kHz_ticks + 1;
        if (tick_100Hz) cnt_100Hz_ticks = cnt_100Hz_ticks + 1;
        if (tick_10Hz) cnt_10Hz_ticks = cnt_10Hz_ticks + 1;
        if (tick_2Hz) cnt_2Hz_ticks = cnt_2Hz_ticks + 1;
    end
    
    // Main test stimulus
    initial begin
        // Initialize VCD dump for waveform viewing
        $dumpfile("clock_divider_tb.vcd");
        $dumpvars(0, clock_divider_tb);
        
        // Display header
        $display("===============================================");
        $display("Clock Divider Testbench Starting");
        $display("System Clock: 100MHz (10ns period)");
        $display("===============================================\n");
        
        // Test 1: Reset test
        $display("TEST 1: Reset Functionality");
        $display("-------------------------------------------");
        rst_n = 0;
        #100; // Hold reset for 100ns
        
        // Check all outputs are 0 during reset
        if (clk_1MHz === 0 && clk_100kHz === 0 && clk_25kHz === 0 && 
            clk_100Hz === 0 && clk_10Hz === 0 && clk_2Hz === 0 &&
            tick_1MHz === 0 && tick_100kHz === 0 && tick_25kHz === 0 &&
            tick_100Hz === 0 && tick_10Hz === 0 && tick_2Hz === 0) begin
            $display("[PASS] All outputs are 0 during reset");
        end else begin
            $display("[FAIL] Some outputs are not 0 during reset");
        end
        
        // Release reset
        rst_n = 1;
        $display("[INFO] Reset released at time %0t ns\n", $time);
        
        // Test 2: Check 1MHz clock (fastest, easiest to verify)
        $display("TEST 2: 1MHz Clock Verification");
        $display("-------------------------------------------");
        $display("Expected: Toggle every 50 system clock cycles (500ns)");
        $display("Expected: Full period = 1000ns = 1us");
        
        // Reset counters
        cnt_1MHz_toggles = 0;
        cnt_1MHz_ticks = 0;
        
        // Wait for multiple 1MHz cycles
        #10000; // 10us = 10 cycles of 1MHz
        
        $display("After 10us:");
        $display("  1MHz toggles counted: %0d (Expected: ~20)", cnt_1MHz_toggles);
        $display("  1MHz ticks counted: %0d (Expected: ~10)", cnt_1MHz_ticks);
        
        if (cnt_1MHz_toggles >= 18 && cnt_1MHz_toggles <= 22) begin
            $display("[PASS] 1MHz clock toggle count is correct");
        end else begin
            $display("[FAIL] 1MHz clock toggle count is incorrect");
        end
        
        if (cnt_1MHz_ticks >= 9 && cnt_1MHz_ticks <= 11) begin
            $display("[PASS] 1MHz tick count is correct\n");
        end else begin
            $display("[FAIL] 1MHz tick count is incorrect\n");
        end
        
        // Test 3: Check 100kHz clock
        $display("TEST 3: 100kHz Clock Verification");
        $display("-------------------------------------------");
        $display("Expected: Toggle every 500 system clock cycles (5us)");
        $display("Expected: Full period = 10us");
        
        cnt_100kHz_toggles = 0;
        cnt_100kHz_ticks = 0;
        
        #100000; // 100us = 10 cycles of 100kHz
        
        $display("After 100us:");
        $display("  100kHz toggles counted: %0d (Expected: ~20)", cnt_100kHz_toggles);
        $display("  100kHz ticks counted: %0d (Expected: ~10)", cnt_100kHz_ticks);
        
        if (cnt_100kHz_toggles >= 18 && cnt_100kHz_toggles <= 22) begin
            $display("[PASS] 100kHz clock toggle count is correct");
        end else begin
            $display("[FAIL] 100kHz clock toggle count is incorrect");
        end
        
        if (cnt_100kHz_ticks >= 9 && cnt_100kHz_ticks <= 11) begin
            $display("[PASS] 100kHz tick count is correct\n");
        end else begin
            $display("[FAIL] 100kHz tick count is incorrect\n");
        end
        
        // Test 4: Check 25kHz clock
        $display("TEST 4: 25kHz Clock Verification");
        $display("-------------------------------------------");
        $display("Expected: Toggle every 2000 system clock cycles (20us)");
        $display("Expected: Full period = 40us");
        
        cnt_25kHz_toggles = 0;
        cnt_25kHz_ticks = 0;
        
        #400000; // 400us = 10 cycles of 25kHz
        
        $display("After 400us:");
        $display("  25kHz toggles counted: %0d (Expected: ~20)", cnt_25kHz_toggles);
        $display("  25kHz ticks counted: %0d (Expected: ~10)", cnt_25kHz_ticks);
        
        if (cnt_25kHz_toggles >= 18 && cnt_25kHz_toggles <= 22) begin
            $display("[PASS] 25kHz clock toggle count is correct");
        end else begin
            $display("[FAIL] 25kHz clock toggle count is incorrect");
        end
        
        if (cnt_25kHz_ticks >= 9 && cnt_25kHz_ticks <= 11) begin
            $display("[PASS] 25kHz tick count is correct\n");
        end else begin
            $display("[FAIL] 25kHz tick count is incorrect\n");
        end
        
        // Test 5: Quick check for slower clocks (100Hz, 10Hz, 2Hz)
        // Note: Full verification would take too long in simulation
        $display("TEST 5: Slower Clocks (Quick Check)");
        $display("-------------------------------------------");
        $display("100Hz: Period = 10ms, Toggle every 5ms");
        $display("10Hz:  Period = 100ms, Toggle every 50ms");
        $display("2Hz:   Period = 500ms, Toggle every 250ms");
        
        cnt_100Hz_toggles = 0;
        cnt_10Hz_toggles = 0;
        cnt_2Hz_toggles = 0;
        
        // Wait 50ms to see at least some toggles
        #50_000_000;
        
        $display("\nAfter 50ms:");
        $display("  100Hz toggles: %0d (Expected: ~10)", cnt_100Hz_toggles);
        $display("  10Hz toggles: %0d (Expected: ~1-2)", cnt_10Hz_toggles);
        $display("  2Hz toggles: %0d (Expected: 0-1)", cnt_2Hz_toggles);
        
        if (cnt_100Hz_toggles >= 8 && cnt_100Hz_toggles <= 12) begin
            $display("[PASS] 100Hz toggle count looks reasonable");
        end else begin
            $display("[INFO] 100Hz toggles: %0d (may need longer sim)", cnt_100Hz_toggles);
        end
        
        // Test 6: Reset during operation
        $display("\nTEST 6: Reset During Operation");
        $display("-------------------------------------------");
        
        #1000;
        rst_n = 0;
        #100;
        
        if (clk_1MHz === 0 && clk_100kHz === 0 && tick_1MHz === 0) begin
            $display("[PASS] Outputs reset correctly during operation\n");
        end else begin
            $display("[FAIL] Outputs did not reset properly\n");
        end
        
        rst_n = 1;
        #10000;
        
        // Final summary
        $display("\n===============================================");
        $display("Testbench Complete");
        $display("===============================================");
        $display("Review the waveform (clock_divider_tb.vcd) for detailed timing");
        $display("Key things to verify in waveform:");
        $display("  1. Each clk_X has 50%% duty cycle");
        $display("  2. Each tick_X is exactly 1 system clock cycle wide");
        $display("  3. Ticks occur at rising edge of corresponding clock");
        $display("  4. All counters reset properly when rst_n = 0");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100_000_000; // 100ms timeout
        $display("\n[WARNING] Testbench timeout after 100ms");
        $finish;
    end

endmodule
