`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/08/2025 09:18:12 AM
// Design Name: 
// Module Name: tachometer_reader
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

/*
periodically trigger i2c to get tmp102 data
wait for i2c to get it
process the 16bit raw data
compute to celcius and 4-sample moving average
output temp_celcius, temp_avg, temp_valid
*/
module temperature_reader (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        read_trigger,     // Pulse to start reading (10Hz tick)
    
    // I2C Master interface
    output reg  [1:0]  i2c_cmd,          // 00=idle, 01=read16
    output reg  [6:0]  i2c_slave_addr,   // 7-bit i2c address
    output reg  [7:0]  i2c_reg_addr,    // internal addr to read
    input  wire [15:0] i2c_read_data,   // 16 bit data fom i2c
    input  wire        i2c_done,    // high when i2c read finishes 
    input  wire        i2c_busy,    // high when i2c is currently communicating
    
    // Temperature outputs
    output reg  [7:0]  temp_celsius,     // Instant (raw) temperature in °C
    output reg  [7:0]  temp_avg,         // 4-sample moving average temperature
    output reg         temp_valid        // High for one clk cycle when new temp ready
);

    // --- TMP102 constants ---
    localparam TMP102_ADDR = 7'h48;
    localparam TEMP_REG    = 8'h00;

    // --- State machine encoding ---
    localparam IDLE         = 2'd0;
    localparam REQUEST_READ = 2'd1;
    localparam WAIT_DONE    = 2'd2;
    localparam PROCESS_DATA = 2'd3;

    reg [1:0] state;
    reg read_trigger_prev;
    wire read_trigger_edge;

    // --- Moving average registers (4 samples for easy division) ---
    reg [7:0] t0, t1, t2, t3;
    
    // --- Edge detection for read_trigger ---
    assign read_trigger_edge = read_trigger & ~read_trigger_prev;

    // --- Variable for temperature processing (declared outside always block) ---
    reg [11:0] raw_temp_12bit;
    reg [7:0] temp_rounded;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i2c_cmd <= 2'b00;
            i2c_slave_addr <= TMP102_ADDR;
            i2c_reg_addr <= TEMP_REG;
            temp_celsius <= 8'd25;      // Default room temp
            temp_avg <= 8'd25;
            temp_valid <= 0;
            t0 <= 8'd25;
            t1 <= 8'd25;
            t2 <= 8'd25;
            t3 <= 8'd25;
            read_trigger_prev <= 0;
            raw_temp_12bit <= 0;
            temp_rounded <= 0;
        end else begin
            read_trigger_prev <= read_trigger;
            temp_valid <= 0;  // Default: one-cycle pulse only

            case (state)
                //---------------------------------------------------
                // IDLE: Wait for trigger to start new reading
                //---------------------------------------------------
                IDLE: begin
                    i2c_cmd <= 2'b00;
                    if (read_trigger_edge && !i2c_busy) begin
                        state <= REQUEST_READ;
                    end
                end

                //---------------------------------------------------
                // REQUEST_READ: Issue read command to I2C master
                //---------------------------------------------------
                REQUEST_READ: begin
                    if (!i2c_busy) begin
                        i2c_cmd <= 2'b01;           // read16 command
                        i2c_slave_addr <= TMP102_ADDR;
                        i2c_reg_addr <= TEMP_REG;
                        state <= WAIT_DONE;
                    end
                end

                //---------------------------------------------------
                // WAIT_DONE: Wait for I2C transaction to complete
                //---------------------------------------------------
                WAIT_DONE: begin
                    i2c_cmd <= 2'b00;  // Clear command
                    if (i2c_done) begin
                        state <= PROCESS_DATA;
                    end
                end

                //---------------------------------------------------
                // PROCESS_DATA: Convert raw data and update filters
                //---------------------------------------------------
                PROCESS_DATA: begin
                    // TMP102 format: 12-bit temperature in bits [15:4]
                    // Resolution: 0.0625°C per LSB
                    // Extract 12-bit value
                    
                    // Convert to integer °C with rounding
                    // Upper 8 bits give integer part
                    // Bit 3 is 0.5°C - use for rounding
                    // Use i2c_read_data directly
                    temp_rounded <= i2c_read_data[15:8] + i2c_read_data[7];
                    
                    // Store instant temperature
                    temp_celsius <= temp_rounded;

                    // This creates a 4-sample moving average
                    // Newest sample goes into t0, oldest (t3) is discarded
                    t3 <= t2;
                    t2 <= t1;
                    t1 <= t0;
                    t0 <= temp_rounded;

                    // Compute average INCLUDING the newest reading (not delayed)
                    // Sum old samples (t3, t2, t1) + new sample (temp_rounded)
                    // Divide by 4 using shift right by 2
                    temp_avg <= (t3 + t2 + t1 + t0) >> 2;

                    // Signal that new temperature data is available
                    temp_valid <= 1;
                    state <= IDLE;
                end

                //---------------------------------------------------
                default: state <= IDLE;
            endcase
        end
    end

endmodule