`timescale 1ns / 1ps
module tachometer_reader #(
    parameter integer CLK_FREQ         = 100_000_000,  // input clock (Hz)
    parameter integer UPDATE_RATE      = 10,           // update rate (Hz)
    parameter integer PULSES_PER_REV   = 2,            // pulses per revolution
    parameter integer DEBOUNCE_TIME_US = 1             // debounce time in microseconds (0 = disabled)
)(
    input  wire        clk,         // system clock
    input  wire        tach_in,     // tachometer input (open-drain, pulled up externally)
    output reg         update_tick, // 1-cycle pulse when rpm_out updated
    output reg  [15:0] rpm_out      // measured RPM (0..65535)
);

    // -------------------------------------------------------------------------
    // Derived constants
    // -------------------------------------------------------------------------
    localparam integer MEASUREMENT_WINDOW = (CLK_FREQ / UPDATE_RATE);
    localparam integer WINDOW_COUNTER_WIDTH = $clog2(MEASUREMENT_WINDOW + 1);

    localparam integer DEBOUNCE_CYCLES_RAW = (CLK_FREQ / 1_000_000) * DEBOUNCE_TIME_US;
    localparam integer DEBOUNCE_CYCLES = (DEBOUNCE_CYCLES_RAW < 0) ? 0 : DEBOUNCE_CYCLES_RAW;
    localparam integer DEBOUNCE_WIDTH = (DEBOUNCE_CYCLES == 0) ? 1 : $clog2(DEBOUNCE_CYCLES + 1);

    localparam integer RPM_MULTIPLIER = (60 * UPDATE_RATE) / PULSES_PER_REV;

    // -------------------------------------------------------------------------
    // Synchronize tach_in into clk domain (2-stage)
    // -------------------------------------------------------------------------
    reg tach_sync_0 = 1'b1;
    reg tach_sync_1 = 1'b1;

    always @(posedge clk) begin
        tach_sync_0 <= tach_in;
        tach_sync_1 <= tach_sync_0;
    end

    // -------------------------------------------------------------------------
    // Optional debounce (very small state machine)
    // If DEBOUNCE_CYCLES == 0 we bypass and use tach_sync_1 directly.
    // -------------------------------------------------------------------------
    reg [DEBOUNCE_WIDTH-1:0] debounce_cnt = {DEBOUNCE_WIDTH{1'b0}};
    reg                      tach_debounced = 1'b1; // assume idle-high

    always @(posedge clk) begin
        if (DEBOUNCE_CYCLES == 0) begin
            tach_debounced <= tach_sync_1;
            debounce_cnt <= {DEBOUNCE_WIDTH{1'b0}};
        end else begin
            if (tach_sync_1 == tach_debounced) begin
                debounce_cnt <= {DEBOUNCE_WIDTH{1'b0}};
            end else begin
                if (debounce_cnt < DEBOUNCE_CYCLES - 1)
                    debounce_cnt <= debounce_cnt + 1'b1;
                else begin
                    debounce_cnt <= {DEBOUNCE_WIDTH{1'b0}};
                    tach_debounced <= tach_sync_1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Falling-edge detection (fan pulses typically pull low)
    // -------------------------------------------------------------------------
    reg tach_prev = 1'b1;
    wire tach_falling_edge = (tach_prev && !tach_debounced);

    always @(posedge clk) begin
        tach_prev <= tach_debounced;
    end

    // -------------------------------------------------------------------------
    // Window counter and pulse counting
    // -------------------------------------------------------------------------
    reg [WINDOW_COUNTER_WIDTH-1:0] window_cnt = {WINDOW_COUNTER_WIDTH{1'b0}};
    reg [WINDOW_COUNTER_WIDTH-1:0] pulse_count = {WINDOW_COUNTER_WIDTH{1'b0}};
    reg [WINDOW_COUNTER_WIDTH-1:0] pulse_count_reg = {WINDOW_COUNTER_WIDTH{1'b0}};

    always @(posedge clk) begin
        // window counter
        if (window_cnt >= (MEASUREMENT_WINDOW - 1)) begin
            window_cnt <= {WINDOW_COUNTER_WIDTH{1'b0}};
            pulse_count_reg <= pulse_count;
            pulse_count <= {WINDOW_COUNTER_WIDTH{1'b0}};
        end else begin
            window_cnt <= window_cnt + 1'b1;
            // count falling edges
            if (tach_falling_edge)
                pulse_count <= pulse_count + 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Calculate RPM and produce update_tick (saturate to 16-bit)
    // rpm_out = pulse_count_reg * RPM_MULTIPLIER
    // -------------------------------------------------------------------------
    wire [47:0] rpm_calc_w = pulse_count_reg * RPM_MULTIPLIER;

    always @(posedge clk) begin
        if (window_cnt == 0) begin
            // window just rolled over (we captured pulse_count_reg earlier)
            if (rpm_calc_w > 48'd65535)
                rpm_out <= 16'd65535;
            else
                rpm_out <= rpm_calc_w[15:0];

            update_tick <= 1'b1;
        end else begin
            update_tick <= 1'b0;
        end
    end

endmodule
