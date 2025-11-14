`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/20/2025 10:27:20 AM
// Design Name: 
// Module Name: i2c_master_tb
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
// Testbench for i2c_master
// Behaviorally simulates a TMP102-like I2C temperature sensor
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module i2c_master_tb;

    reg clk;
    reg reset_n;
    reg [1:0] cmd;
    reg [6:0] slave_addr;
    reg [7:0] reg_addr;
    reg [7:0] write_data;

    wire [15:0] read_data;
    wire done;
    wire busy;
    wire sda_bus;
    wire scl_wire;

    // Instantiate I2C master
    i2c_master uut(
        .clk(clk),
        .reset_n(reset_n),
        .cmd(cmd),
        .slave_addr(slave_addr),
        .reg_addr(reg_addr),
        .write_data(write_data),
        .read_data(read_data),
        .done(done),
        .busy(busy),
        .sda(sda_bus),
        .scl(scl_wire)
    );

    // Instantiate fake slave
    i2c_fake_slave slave(
        .clk(clk),
        .reset_n(reset_n),
        .scl(scl_wire),
        .sda(sda_bus)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz

    initial begin
        // Initialize signals
        reset_n = 0;
        cmd = 2'b00;
        slave_addr = 7'h50;
        reg_addr = 8'h01;
        write_data = 8'hA5;

        #20 reset_n = 1;

        // Small delay to observe SCL toggling
        $display("==== Checking SCL toggling ====");
        #2000;
        $display("SCL at time %0t is %b", $time, scl_wire);

        // Send WRITE8 command
        $display("==== Starting WRITE8 command ====");
        cmd = 2'b10; // WRITE8
        #10;
        cmd = 2'b00; // remove command after 1 cycle

        // Monitor signals for some time
        repeat (50) begin
            #1000;
            $display("Time: %0t | Done=%b Busy=%b SDA=%b SCL=%b ReadData=%h",
                     $time, done, busy, sda_bus, scl_wire, read_data);
        end

        $display("==== Testbench done ====");
        $stop;
    end

endmodule


// Minimal fake I2C slave for ACKing WRITE8
module i2c_fake_slave(
    input  wire clk,
    input  wire reset_n,
    input  wire scl,
    inout  wire sda
);
    reg sda_out_en;
    reg sda_out_val;
    assign sda = sda_out_en ? sda_out_val : 1'bz;

    reg [2:0] bit_cnt;

    always @(posedge scl or negedge reset_n) begin
        if (!reset_n) begin
            bit_cnt     <= 0;
            sda_out_en  <= 0;
            sda_out_val <= 1;
        end else begin
            if (bit_cnt == 7) begin
                sda_out_en  <= 1; // ACK
                sda_out_val <= 0;
            end else begin
                sda_out_en <= 0; // release SDA
            end
            bit_cnt <= bit_cnt + 1;
        end
    end
endmodule








