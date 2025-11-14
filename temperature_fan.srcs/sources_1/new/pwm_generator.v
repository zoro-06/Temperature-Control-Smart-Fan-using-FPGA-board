`timescale 1ns / 1ps
module pwm_generator #(
    parameter integer CLK_FREQ  = 100_000_000, // input clock (Hz)
    parameter integer PWM_FREQ  = 2_000,       // PWM frequency (Hz)
    parameter integer PWM_BITS  = 12            // PWM resolution (bits)
)(
    input  wire                    clk,
    input  wire [PWM_BITS-1:0]     duty_cycle,  // desired duty (0 .. 2^PWM_BITS - 1)
    output reg                     pwm_out
);

    // Compute PWM period in clk cycles (integer division)
    localparam integer PWM_PERIOD = (CLK_FREQ / PWM_FREQ);
    // Ensure counter width at least 1
    localparam integer COUNTER_WIDTH_RAW = $clog2(PWM_PERIOD == 0 ? 1 : PWM_PERIOD);
    localparam integer COUNTER_WIDTH = (COUNTER_WIDTH_RAW == 0) ? 1 : COUNTER_WIDTH_RAW;

    // widths for multiply result
    localparam integer DUTY_TEMP_W = PWM_BITS + COUNTER_WIDTH;

    // counters and registers (initialized so no reset required)
    reg [COUNTER_WIDTH-1:0] counter = {COUNTER_WIDTH{1'b0}};
    reg [PWM_BITS-1:0]      duty_cycle_reg = {PWM_BITS{1'b0}};

    // pipeline registers for multiply/scale
    reg [DUTY_TEMP_W-1:0]   duty_temp_reg = {DUTY_TEMP_W{1'b0}};
    reg [COUNTER_WIDTH-1:0] duty_scaled_reg = {COUNTER_WIDTH{1'b0}}; // compare value

    // constant full value for comparison
    localparam [PWM_BITS-1:0] FULL = {PWM_BITS{1'b1}};

    // PWM period counter (wraps)
    always @(posedge clk) begin
        if (counter >= (PWM_PERIOD - 1))
            counter <= {COUNTER_WIDTH{1'b0}};
        else
            counter <= counter + 1'b1;
    end

    // latch duty_cycle at period boundary to avoid glitching
    always @(posedge clk) begin
        if (counter == {COUNTER_WIDTH{1'b0}})
            duty_cycle_reg <= duty_cycle;
    end

    always @(posedge clk) begin
        duty_temp_reg <= duty_cycle_reg * PWM_PERIOD;
        // stage 1: scale -> compare value (from previous cycle's product)
        duty_scaled_reg <= duty_temp_reg >> PWM_BITS;
    end

    always @(posedge clk) begin
        if (duty_cycle_reg == {PWM_BITS{1'b0}}) begin
            pwm_out <= 1'b0; // 0%
        end else if (duty_cycle_reg == FULL) begin
            pwm_out <= 1'b1; // 100%
        end else begin
            pwm_out <= (counter < duty_scaled_reg);
        end
    end

endmodule
