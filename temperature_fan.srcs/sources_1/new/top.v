`timescale 1ns / 1ps

module top(
    input         clk_100MHz,       // basys clk signal
    input        fan_tach,   // tachometer input (open-drain)
    output      fan_pwm,    // PWM output to MOSFET/gate driver
    inout         TMP_SDA,          // i2c sda on temp sensor - bidirectional
    output        TMP_SCL,          // i2c scl on temp sensor
    output [0:6]  SEG,              // 7 segments of each display (CHANGE ENDIANESS)
    output [3:0]  AN,               // 4 anodes of 4 displays
    output        led_speed_off,
    output led_speed_low,
    output led_speed_high
    );
    
    wire w_200kHz;                  // 200kHz SCL
    wire [7:0] c_data;              // celsius data
    
    
    // 10 Hz control tick generator (derived from 100 MHz)
    reg [23:0] tick10_cnt = 24'd0;         // needs to count to 10_000_000-1
    wire tick_10Hz;
    localparam integer T10 = 10_000_000;   // 100e6 / 10 = 10e6 clocks per 10Hz period
    always @(posedge clk_100MHz) begin
        if (tick10_cnt >= (T10 - 1))
            tick10_cnt <= 24'd0;
        else
            tick10_cnt <= tick10_cnt + 1'b1;
    end
    assign tick_10Hz = (tick10_cnt == 24'd0);
    
    // -------------------------------------------------------------

    i2c_master master(
        .clk_200kHz(w_200kHz),
        .temp_data(c_data),
        .SDA(TMP_SDA),
        .SCL(TMP_SCL)
    );
    
    clkgen_200kHz cgen(
        .clk_100MHz(clk_100MHz),    // changed clk name to match constraints file
        .clk_200kHz(w_200kHz)
    );
    
    seg7 seg(
        .clk_100MHz(clk_100MHz),    // changed clk name to match constraints file
        .c_data(c_data),
        .SEG(SEG),
        .AN(AN)
    );
    
    wire        tach_update_tick;
    wire [15:0] rpm_measured;

    tachometer_reader #(
        .CLK_FREQ(100_000_000),
        .UPDATE_RATE(10),
        .PULSES_PER_REV(2),
        .DEBOUNCE_TIME_US(1)
    ) tach_inst (
        .clk(clk_100MHz),
        .tach_in(fan_tach),
        .update_tick(tach_update_tick),
        .rpm_out(rpm_measured)
    );
    
    wire [11:0] duty_from_mapper;
    wire [15:0] target_rpm;
    wire [15:0] temp_filtered_q4;
    wire [1:0]  speed_state;
    
    temperature_to_rpm_mapper #(
        .Kp_SCALED(128),
        .Ki_SCALED(32),
        .INTEGRAL_LIMIT(32'd50000),
        .MA_LEN(8),
        .T_OFF_MAX(27),
        .T_LOW_MAX(30),
        .RPM_LOW_TARGET(2000),
        .RPM_HIGH_TARGET(4000),
        .BASE_DUTY_OFF(0),
        .BASE_DUTY_LOW(12'd1500),
        .BASE_DUTY_HIGH(12'd3300)
    ) mapper_inst (
        .clk(clk_100MHz),
        .control_tick(tick_10Hz),
        .temp_data(c_data),
        .rpm_measured(rpm_measured),
        .target_rpm(target_rpm),
        .duty_out(duty_from_mapper),
        .temp_filtered(temp_filtered_q4),
        .speed_state_out(speed_state)
    );
   
    wire pwm_out;
    pwm_generator #(
        .CLK_FREQ(100_000_000),
        .PWM_FREQ(2000),
        .PWM_BITS(12)
    ) u_pwm_generator (
        .clk(clk_100MHz),
        .duty_cycle(duty_from_mapper),
        .pwm_out(pwm_out)
    );
    
    assign fan_pwm = ~pwm_out;
    
    assign led_speed_off  = (speed_state == 2'd0);
    assign led_speed_low  = (speed_state == 2'd1);
    assign led_speed_high = (speed_state == 2'd2);
endmodule