`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// fan_controller_top_final.v
// Top-level that wires clock_divider, i2c_master, tachometer_reader,
// temperature_to_rpm_mapper, pwm_generator, and seg7 together.
//////////////////////////////////////////////////////////////////////////////////
module fan_controller_top (
    input  wire        clk,        // 100 MHz system clock
    input  wire        rst_n,      // active-low reset

    // I2C (PmodTMP2) - SDA is bidirectional
    inout  wire        i2c_sda,
    output wire        i2c_scl,

    // Fan interface
    input  wire        fan_tach,   // tachometer input (open-drain)
    output wire        fan_pwm,    // PWM output to MOSFET/gate driver

    // 7-seg display (Basys3)
    output wire [0:6]  seg,        // segments
    output wire [3:0]  an,         // anodes

    // Speed mode LEDs (3 LEDs)
    output wire        led_speed_off,
    output wire        led_speed_low,
    output wire        led_speed_high
);

    // ---------------------------------------------------------------------
    // Internal wires (only what is needed)
    // ---------------------------------------------------------------------
    // clocks / ticks from clock_divider (trimmed)
    wire clk_200kHz;
    wire tick_10Hz;

    // I2C temp
    wire [7:0] i2c_temp_data;
    wire       i2c_scl_internal;

    // Tachometer
    wire       tach_update_tick;
    wire [15:0] rpm_measured;

    // Mapper outputs
    wire [15:0] target_rpm;
    wire [11:0] duty_from_mapper;
    wire [15:0] temp_filtered_q4;
    wire [1:0]  speed_state;

    // PWM
    wire pwm_out;

    // ---------------------------------------------------------------------
    // clock_divider instantiation (provides clk_200kHz and tick_10Hz)
    // ---------------------------------------------------------------------
    clock_divider #(
        .SYS_CLK_HZ(100_000_000)
    ) u_clock_divider (
        .clk_in(clk),
        .rst_n(rst_n),

        .clk_200kHz(clk_200kHz),
        .tick_10Hz(tick_10Hz)
    );

    // ---------------------------------------------------------------------
    // I2C master (runs from clk_200kHz)
    // ---------------------------------------------------------------------
    i2c_master i2c_master_inst (
        .clk_200kHz(clk_200kHz),
        .SDA(i2c_sda),
        .temp_data(i2c_temp_data),
        .SCL(i2c_scl_internal)
    );

    // Drive top-level SCL pin from i2c_master SCL
    assign i2c_scl = i2c_scl_internal;

    // ---------------------------------------------------------------------
    // Tachometer reader instantiation (uses 100 MHz clk)
    // ---------------------------------------------------------------------
    tachometer_reader #(
        .CLK_FREQ(100_000_000),
        .UPDATE_RATE(10),
        .PULSES_PER_REV(2),
        .DEBOUNCE_TIME_US(1)
    ) u_tachometer_reader (
        .clk(clk),
        .rst_n(rst_n),
        .tach_in(fan_tach),
        .update_tick(tach_update_tick),
        .rpm_out(rpm_measured)
    );
    
    // Use a fallback of 30°C whenever the I2C read is exactly zero (debugging aid)
//    wire [7:0] temp_data_used = (i2c_temp_data == 8'd0) ? 8'd30 : i2c_temp_data;

    // ---------------------------------------------------------------------
    // temperature_to_rpm_mapper instantiation (uses tick_10Hz from clock_divider)
    // ---------------------------------------------------------------------
    wire [15:0] temp_q4 = { i2c_temp_data, 4'b0000 }; // integer °C in bits[15:4]

    temperature_to_rpm_mapper #(
        .Kp_SCALED(128),
        .Ki_SCALED(32),
        .INTEGRAL_LIMIT(32'd50000),
        .MA_LEN(8),
        .T_OFF_MAX(28),
        .T_LOW_MAX(38),
        .RPM_LOW_TARGET(2000),
        .RPM_HIGH_TARGET(4000),
        .BASE_DUTY_OFF(0),
        .BASE_DUTY_LOW(12'd1500),
        .BASE_DUTY_HIGH(12'd3300)
    ) u_temp_to_rpm_mapper (
        .clk(clk),
        .rst_n(rst_n),
        .control_tick(tick_10Hz),    // update 10 Hz
        .temp_raw_q4(temp_q4),
        .rpm_measured(rpm_measured),
        .target_rpm(target_rpm),
        .duty_out(duty_from_mapper),
        .temp_filtered(temp_filtered_q4),
        .speed_state_out(speed_state)
    );

    // ---------------------------------------------------------------------
    // PWM generator: feed duty_from_mapper
    // ---------------------------------------------------------------------
    pwm_generator #(
        .CLK_FREQ(100_000_000),
        .PWM_FREQ(2000),
        .PWM_BITS(12)
    ) u_pwm_generator (
        .clk(clk),
        .rst_n(rst_n),
        .duty_cycle(duty_from_mapper),
        .pwm_out(pwm_out)
    );

    // If you require active-low PWM for MOSFET gate, invert here:
    assign fan_pwm = ~pwm_out;
    // assign fan_pwm = pwm_out;

    // ---------------------------------------------------------------------
    // 7-seg display: show Celsius (8-bit from i2c_master)
    // ---------------------------------------------------------------------
    seg7 u_seg7 (
        .clk_100MHz(clk),
        .c_data(i2c_temp_data),
        .SEG(seg),
        .AN(an)
    );

    // ---------------------------------------------------------------------
    // Speed mode LEDs mapping (3 LEDs)
    //  speed_state: 0 = OFF, 1 = LOW, 2 = HIGH
    // ---------------------------------------------------------------------
    assign led_speed_off  = (speed_state == 2'd0);
    assign led_speed_low  = (speed_state == 2'd1);
    assign led_speed_high = (speed_state == 2'd2);

endmodule
