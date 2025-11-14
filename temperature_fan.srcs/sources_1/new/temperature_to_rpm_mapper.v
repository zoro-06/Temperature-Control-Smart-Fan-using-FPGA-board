`timescale 1ns / 1ps
module temperature_to_rpm_mapper #(
    parameter integer Kp_SCALED      = 128,         // Kp scaled by 256
    parameter integer Ki_SCALED      = 32,          // Ki scaled by 256
    parameter integer INTEGRAL_LIMIT = 32'd50000,  // anti-windup cap
    parameter integer MA_LEN         = 8,           // moving avg length (>0)
    parameter integer T_OFF_MAX      = 28,          // <= this => OFF (°C)
    parameter integer T_LOW_MAX      = 38,          // <= this => LOW, else HIGH
    parameter integer RPM_LOW_TARGET  = 2000,       // RPM for LOW
    parameter integer RPM_HIGH_TARGET = 4000,       // RPM for HIGH
    parameter integer BASE_DUTY_OFF   = 0,          // base duty for OFF
    parameter integer BASE_DUTY_LOW   = 12'd1500,   // base duty for LOW
    parameter integer BASE_DUTY_HIGH  = 12'd3300    // base duty for HIGH
)(
    input  wire        clk,
    input  wire        control_tick,     // 1-cycle pulse to update mapper (e.g. tick_10Hz)
    input  wire [7:0]  temp_data,        // integer °C (8-bit)
    input  wire [15:0] rpm_measured,     // measured RPM (unsigned)
    output reg  [15:0] target_rpm = 16'd0,
    output reg  [11:0] duty_out = 12'd0,
    output reg  [15:0] temp_filtered = 16'd0,    // averaged temp Q4
    output reg  [1:0]  speed_state_out = 2'd0    // 0=OFF,1=LOW,2=HIGH
);

    // ----------------------------
    // Parameter sanity / locals
    // ----------------------------
    localparam integer MA_DEPTH = (MA_LEN < 1) ? 1 : MA_LEN;
    localparam integer IDX_WIDTH = (MA_DEPTH <= 1) ? 1 : $clog2(MA_DEPTH);
    localparam integer SAMPLE_W = 8; // integer °C fits 8 bits
    localparam integer SUM_W = SAMPLE_W + IDX_WIDTH + 1;

    // ----------------------------
    // Moving average storage (initialized)
    // ----------------------------
    reg [SAMPLE_W-1:0] ma_buf [0:MA_DEPTH-1];
    reg [IDX_WIDTH-1:0] ma_idx = {IDX_WIDTH{1'b0}};
    reg [SUM_W-1:0] ma_sum = {SUM_W{1'b0}};

    integer i;
    initial begin
        for (i = 0; i < MA_DEPTH; i = i + 1) ma_buf[i] = {SAMPLE_W{1'b0}};
    end

    // current sample (integer °C)
    wire [SAMPLE_W-1:0] sample_int_w = temp_data;

    // new sum and average (combinational)
    wire [SUM_W-1:0] ma_new_sum_w;
    assign ma_new_sum_w = ma_sum - ma_buf[ma_idx] + sample_int_w;

    wire [SAMPLE_W-1:0] avg_temp_int_w;
    assign avg_temp_int_w = (MA_DEPTH == 1) ? ma_new_sum_w[SAMPLE_W-1:0] : (ma_new_sum_w / MA_DEPTH);

    // ----------------------------
    // Mapping & PI helpers
    // ----------------------------
    reg [11:0] base_duty = 12'd0;
    reg [15:0] base_rpm  = 16'd0;
    reg [1:0]  next_speed_state = 2'd0;

    // error = base_rpm - rpm_measured
    wire signed [16:0] error17_w = $signed({1'b0, base_rpm}) - $signed({1'b0, rpm_measured});
    wire signed [31:0] error32_w = {{15{error17_w[16]}}, error17_w};

    wire signed [31:0] kp_s = $signed({16'd0, Kp_SCALED});
    wire signed [31:0] ki_s = $signed({16'd0, Ki_SCALED});

    reg signed [31:0] integral = 32'sd0;

    wire signed [31:0] integral_candidate_w = integral + error32_w;
    wire signed [31:0] integral_clamped_w =
        (integral_candidate_w > $signed(INTEGRAL_LIMIT)) ? $signed(INTEGRAL_LIMIT) :
        (integral_candidate_w < -$signed(INTEGRAL_LIMIT)) ? -$signed(INTEGRAL_LIMIT) :
        integral_candidate_w;

    wire signed [47:0] pterm_ext_w = error32_w * kp_s;
    wire signed [47:0] iterm_ext_w = integral_clamped_w * ki_s;

    wire signed [31:0] pterm_w = pterm_ext_w >>> 8;
    wire signed [31:0] iterm_w = iterm_ext_w >>> 8;

    wire signed [31:0] pi_adjust_w = pterm_w + iterm_w;
    wire signed [31:0] desired_candidate_w = $signed({20'd0, base_duty}) + pi_adjust_w;

    // ----------------------------
    // Sequential update on control_tick only
    // ----------------------------
    always @(posedge clk) begin
        if (control_tick) begin
            // moving average update
            ma_sum <= ma_new_sum_w;
            ma_buf[ma_idx] <= sample_int_w;
            if (ma_idx == MA_DEPTH - 1) ma_idx <= {IDX_WIDTH{1'b0}};
            else ma_idx <= ma_idx + 1'b1;

            // temp_filtered in Q4
            temp_filtered <= { avg_temp_int_w, 4'b0000 };

            // mapping based on avg_temp_int_w
            if (avg_temp_int_w <= T_OFF_MAX) begin
                next_speed_state <= 2'd0;
                base_rpm <= 16'd0;
                base_duty <= BASE_DUTY_OFF[11:0];
                target_rpm <= 16'd0;
            end else if (avg_temp_int_w <= T_LOW_MAX) begin
                next_speed_state <= 2'd1;
                base_rpm <= RPM_LOW_TARGET;
                base_duty <= BASE_DUTY_LOW[11:0];
                target_rpm <= RPM_LOW_TARGET;
            end else begin
                next_speed_state <= 2'd2;
                base_rpm <= RPM_HIGH_TARGET;
                base_duty <= BASE_DUTY_HIGH[11:0];
                target_rpm <= RPM_HIGH_TARGET;
            end
            speed_state_out <= next_speed_state;

            // PI: update integral (clamped) and compute duty
            integral <= integral_clamped_w;

            if (desired_candidate_w <= 0)
                duty_out <= 12'd0;
            else if (desired_candidate_w >= 12'sd4095)
                duty_out <= 12'd4095;
            else
                duty_out <= desired_candidate_w[11:0];
        end
    end

endmodule
