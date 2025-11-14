`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2025 04:32:21 PM
// Design Name: 
// Module Name: i2c_fake_slave
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

