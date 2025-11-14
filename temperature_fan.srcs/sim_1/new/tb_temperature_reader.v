`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2025 08:44:24 PM
// Design Name: 
// Module Name: tb_temperature_reader
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


module tb_temperature_reader();

    // Clock and reset
    reg clk;
    reg rst_n;
    reg read_trigger;
    
    // I2C Master interface
    reg [1:0]  i2c_cmd_mon;
    reg [6:0]  i2c_slave_addr_mon;
    reg [7:0]  i2c_reg_addr_mon;
    reg [15:0] i2c_read_data;
    reg        i2c_done;
    reg        i2c_busy;
    
    // Temperature outputs
    wire [7:0] temp_celsius;
    wire [7:0] temp_avg;
    wire       temp_valid;
    
    // Wires for I2C cmd from DUT
    wire [1:0] i2c_cmd;
    wire [6:0] i2c_slave_addr;
    wire [7:0] i2c_reg_addr;

    // Instantiate DUT
    temperature_reader dut (
        .clk(clk),
        .rst_n(rst_n),
        .read_trigger(read_trigger),
        .i2c_cmd(i2c_cmd),
        .i2c_slave_addr(i2c_slave_addr),
        .i2c_reg_addr(i2c_reg_addr),
        .i2c_read_data(i2c_read_data),
        .i2c_done(i2c_done),
        .i2c_busy(i2c_busy),
        .temp_celsius(temp_celsius),
        .temp_avg(temp_avg),
        .temp_valid(temp_valid)
    );

    // Clock generation: 100MHz (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        read_trigger = 0;
        i2c_read_data = 16'h0000;
        i2c_done = 0;
        i2c_busy = 0;
        
        // Dump waveforms
        $dumpfile("temp_reader.vcd");
        $dumpvars(0, tb_temperature_reader);
        
        // Reset
        #100;
        rst_n = 1;
        #50;
        
        $display("\n=== Test 1: Basic Temperature Reading (25°C) ===");
        perform_temp_read(16'h1900); // 25°C: 25 * 16 = 400 = 0x190 in upper 12 bits
        check_temp(25, "25°C reading");
        
        #200;
        
        $display("\n=== Test 2: Higher Temperature (30°C) ===");
        perform_temp_read(16'h1E00); // 30°C: 30 * 16 = 480 = 0x1E0
        check_temp(30, "30°C reading");
        
        #200;
        
        $display("\n=== Test 3: Lower Temperature (20°C) ===");
        perform_temp_read(16'h1400); // 20°C: 20 * 16 = 320 = 0x140
        check_temp(20, "20°C reading");
        
        #200;
        
        $display("\n=== Test 4: Temperature with rounding (25.5°C) ===");
        perform_temp_read(16'h1980); // 25.5°C: 25.5 * 16 = 408 = 0x198
        check_temp(26, "25.5°C should round to 26°C");
        
        #200;
        
        $display("\n=== Test 5: Moving Average Calculation ===");
        // Read sequence: 20, 24, 28, 32 -> avg should be (20+24+28+32)/4 = 26
        perform_temp_read(16'h1400); // 20°C
        #100;
        $display("Sample 1: temp_celsius=%d, temp_avg=%d (expect avg=22-23 from initial)", 
                 temp_celsius, temp_avg);
        
        perform_temp_read(16'h1800); // 24°C
        #100;
        $display("Sample 2: temp_celsius=%d, temp_avg=%d (expect avg~23)", 
                 temp_celsius, temp_avg);
        
        perform_temp_read(16'h1C00); // 28°C
        #100;
        $display("Sample 3: temp_celsius=%d, temp_avg=%d (expect avg~24)", 
                 temp_celsius, temp_avg);
        
        perform_temp_read(16'h2000); // 32°C
        #100;
        $display("Sample 4: temp_celsius=%d, temp_avg=%d (expect avg=26)", 
                 temp_celsius, temp_avg);
        
        if (temp_avg == 26) begin
            $display("✓ PASS: Moving average correct");
        end else begin
            $display("✗ FAIL: Moving average incorrect. Got %d, expected 26", temp_avg);
        end
        
        #200;
        
        $display("\n=== Test 6: Multiple Triggers (Stress Test) ===");
        perform_temp_read(16'h1900); // 25°C
        #50;
        perform_temp_read(16'h1A00); // 26°C
        #50;
        perform_temp_read(16'h1B00); // 27°C
        
        #200;
        
        $display("\n=== Test 7: Trigger During Busy (Should Wait) ===");
        // Trigger while I2C is busy
        read_trigger = 1;
        #10;
        read_trigger = 0;
        #10;
        i2c_busy = 1;
        #100;
        // Trigger again while busy
        read_trigger = 1;
        #10;
        read_trigger = 0;
        #50;
        i2c_busy = 0;
        #200;
        
        $display("\n=== Test 8: Edge Cases ===");
        // Very low temperature (0°C)
        perform_temp_read(16'h0000);
        check_temp(0, "0°C reading");
        #100;
        
        // High temperature (50°C)
        perform_temp_read(16'h3200); // 50 * 16 = 800 = 0x320
        check_temp(50, "50°C reading");
        #100;
        
        $display("\n=== Test 9: I2C Address and Register Verification ===");
        read_trigger = 1;
        #10;
        read_trigger = 0;
        wait(i2c_cmd == 2'b01);
        #10;
        if (i2c_slave_addr == 7'h48) begin
            $display("✓ PASS: Correct I2C slave address (0x48)");
        end else begin
            $display("✗ FAIL: Wrong I2C address. Got 0x%h, expected 0x48", i2c_slave_addr);
        end
        if (i2c_reg_addr == 8'h00) begin
            $display("✓ PASS: Correct register address (0x00)");
        end else begin
            $display("✗ FAIL: Wrong register address. Got 0x%h, expected 0x00", i2c_reg_addr);
        end
        // Complete the transaction
        #50;
        i2c_done = 1;
        #10;
        i2c_done = 0;
        #100;
        
        $display("\n=== Test 10: temp_valid Pulse Duration ===");
        read_trigger = 1;
        #10;
        read_trigger = 0;
        wait(i2c_cmd == 2'b01);
        #100;
        i2c_read_data = 16'h1900;
        i2c_done = 1;
        #10;
        i2c_done = 0;
        
        // Check temp_valid is high for exactly one cycle
        wait(temp_valid == 1);
        #10;
        if (temp_valid == 0) begin
            $display("✓ PASS: temp_valid is a single-cycle pulse");
        end else begin
            $display("✗ FAIL: temp_valid stays high too long");
        end
        
        #500;
        
        $display("\n=== All Tests Complete ===");
        $finish;
    end

    // Task to perform a complete temperature read cycle
    task perform_temp_read;
        input [15:0] temp_data;
        begin
            // Trigger read
            read_trigger = 1;
            #10;
            read_trigger = 0;
            
            // Wait for I2C command
            wait(i2c_cmd == 2'b01);
            #20;
            
            // Simulate I2C transaction
            i2c_busy = 1;
            #200; // Simulate I2C transaction time
            
            // Return data
            i2c_read_data = temp_data;
            i2c_done = 1;
            i2c_busy = 0;
            #10;
            i2c_done = 0;
            
            // Wait for processing
            #50;
        end
    endtask

    // Task to check temperature value
    task check_temp;
        input [7:0] expected;
        input [8*50:1] test_name;
        begin
            if (temp_celsius == expected) begin
                $display("✓ PASS: %s - Got %d°C", test_name, temp_celsius);
            end else begin
                $display("✗ FAIL: %s - Got %d°C, expected %d°C", 
                         test_name, temp_celsius, expected);
            end
        end
    endtask
    
    // Monitor for debugging
    always @(posedge clk) begin
        if (temp_valid) begin
            $display("[%0t] NEW TEMP: celsius=%d°C, avg=%d°C", 
                     $time, temp_celsius, temp_avg);
        end
    end

endmodule
