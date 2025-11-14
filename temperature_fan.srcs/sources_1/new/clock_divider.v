`timescale 1ns / 1ps
// clock_divider.v
// Minimal divider: generates clk_200kHz (for I2C) and tick_10Hz (control update).
module clock_divider #(
    parameter integer SYS_CLK_HZ = 100_000_000 // input system clock (Hz)
)(
    input  wire clk_in,
    input  wire rst_n,          // active-low reset

    // outputs
    output reg  clk_200kHz,     // 200 kHz clock (50% duty)
    output reg  tick_10Hz       // single-cycle tick asserted at clk_in domain (10 Hz)
);

    // desired frequencies
    localparam integer F_200KHZ = 200_000;
    localparam integer F_10HZ   = 10;

    // half-period counts (number of sys clk cycles for half period)
    localparam integer HALF_200KHZ = SYS_CLK_HZ / (2 * F_200KHZ); // e.g., 100_000_000/(2*200_000)=250
    localparam integer FULL_10HZ   = SYS_CLK_HZ / F_10HZ;         // e.g., 100_000_000/10 = 10_000_000

    // widths
    localparam integer CNT_HALF_WIDTH = $clog2(HALF_200KHZ + 1);
    localparam integer CNT_FULL10_WIDTH = $clog2(FULL_10HZ + 1);

    // counters
    reg [CNT_HALF_WIDTH-1:0] cnt_half_200k;
    reg [CNT_FULL10_WIDTH-1:0] cnt_full_10hz;

    // synchronous logic
    always @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            clk_200kHz     <= 1'b0;
            tick_10Hz      <= 1'b0;
            cnt_half_200k  <= {CNT_HALF_WIDTH{1'b0}};
            cnt_full_10hz  <= {CNT_FULL10_WIDTH{1'b0}};
        end else begin
            // ----- generate 200 kHz clock (50% duty) -----
            if (cnt_half_200k >= (HALF_200KHZ - 1)) begin
                cnt_half_200k <= {CNT_HALF_WIDTH{1'b0}};
                clk_200kHz    <= ~clk_200kHz;
            end else begin
                cnt_half_200k <= cnt_half_200k + 1'b1;
            end

            // ----- generate 10 Hz single-cycle tick -----
            // count FULL_10HZ cycles of clk_in, assert tick_10Hz for one clk_in cycle
            if (cnt_full_10hz >= (FULL_10HZ - 1)) begin
                cnt_full_10hz <= {CNT_FULL10_WIDTH{1'b0}};
                tick_10Hz <= 1'b1;
            end else begin
                cnt_full_10hz <= cnt_full_10hz + 1'b1;
                tick_10Hz <= 1'b0;
            end
        end
    end

endmodule