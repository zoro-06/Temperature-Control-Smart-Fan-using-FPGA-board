`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2025 10:01:27 PM
// Design Name: 
// Module Name: tb_tmp102_reader
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

module tb_tmp102_master;

    reg clk;
    reg rst_n;
    reg start;
    wire scl;
    wire sda;
    wire [15:0] temp_raw;
    wire signed [15:0] temp_q16;
    wire busy;
    wire done;

    // Instantiate master
    tmp102_master master_i (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .sda(sda),
        .scl(scl),
        .temp_raw(temp_raw),
        .temp_q16(temp_q16),
        .busy(busy),
        .done(done)
    );

    // Pullup on SDA and SCL for open-drain behavior
    pullup(sda);
    pullup(scl);

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // --- TMP102 behavioral slave (very small, only supports address 0x48 read of register 0x00) ---
    // This model watches the SDA/SCL lines and when master requests read, it will respond with
    // the two bytes provided in 'slave_data' (MSB first).
    reg [15:0] slave_data = 16'h07D0; // default: 0x07D0 -> 125.0 deg? (note: 0x07D0 >>4 = 0x07D = 125 decimal -> *0.0625 = 7.8125; choose value as you like)
    // For clarity: to set 25.0°C -> 25/0.0625 = 400 -> 0x190 -> slave_data = 0x190 << 4 = 0x1900

    // For this TB we'll send 25.0°C: 25 / 0.0625 = 400 = 0x0190 -> packed into 16-bit register as bits[15:4]=0x190
    initial slave_data = 16'h1900; // 25.0°C

    // Internal state for slave decoding
    reg [3:0] s_cnt;
    reg [7:0] recv_shift;
    reg in_address_phase;
    reg expecting_reg_ptr;
    reg responding_read;
    reg [3:0] bit_index;
    reg sda_drive; // when 1, slave drives SDA low (ACK or data 0), when 0, release.

    // Connect sda to master: if slave drives, it pulls low; else high (pullup)
    // We use wired-OR behavior: master uses sda_oe to drive; slave will pull low when needed.
    // Implement as follows: create an internal net 'sda_from_master' reading master's assigned tri-state; and then produce actual sda net by tying pulls.
    // But simpler in TB: sample sda and drive via 'force' approach:
    tri sda_tri;
    // We cannot directly override the master's sda tri-state easily; instead implement a small resolution:
    // Master drives SDA when master.sda_oe==1. To simulate slave pulling low we conditionally drive sda low when needed.
    // Create 'sda_slave_drive' and tie to sda net with weak pullup above.
    reg sda_slave_drive;
    assign sda = sda_slave_drive ? 1'b0 : 1'bz; // slave pulls low when sda_slave_drive==1

    // We'll implement slave actions synchronized to scl edges sampled in tb (rising edge sampling).
    reg prev_scl;
    always @(posedge clk) prev_scl <= scl;

    // Simple edge detector
    wire scl_rising = (scl == 1'b1) && (prev_scl == 1'b0);
    wire scl_falling = (scl == 1'b0) && (prev_scl == 1'b1);

    initial begin
        rst_n = 0;
        start = 0;
        sda_slave_drive = 0;
        s_cnt = 0;
        in_address_phase = 0;
        expecting_reg_ptr = 0;
        responding_read = 0;
        bit_index = 7;
        recv_shift = 8'd0;
        #200;
        rst_n = 1;
        #1000;

        // Send start
        @(posedge clk);
        start = 1;
        #20;
        start = 0;

        // Wait for master to become busy
        wait (busy);
        // Wait for transaction completion (done)
        wait (done);
        #200;
        $display("[TB] temp_raw = 0x%h  temp_q16 = %0d (fixed-point, C*16)", temp_raw, temp_q16);
        // Convert to integer Celsius for printing: temp_q16 / 16.0 printed as float-like
        $display("[TB] Temperature (degC approx) = %0d.%02d", temp_q16>>>4, ((temp_q16 & 16'h000F)*625)/1000);
        $finish;
    end

    // very small behavioral slave logic:
    // - watches SDA during SCL rising to sample bits
    // - when it receives address 0x48 with write (R/W=0) then reg ptr 0x00, and then sees repeated start + address with read (R/W=1),
    //   it drives the two data bytes of slave_data MSB then LSB during subsequent SCL phases, and provides ACKs (drive SDA low) after bytes from master when required.
    reg [3:0] slave_state;
    parameter S_IDLE = 4'd0, S_ADDR = 4'd1, S_ACK = 4'd2, S_REG = 4'd3, S_REP = 4'd4, S_ADDRR = 4'd5, S_SEND1=4'd6, S_SEND2=4'd7, S_DONE=4'd8;

    always @(posedge clk) begin
        if (!rst_n) begin
            slave_state <= S_IDLE;
            recv_shift <= 8'd0;
            sda_slave_drive <= 0;
            bit_index <= 7;
        end else begin
            sda_slave_drive <= 0; // default release
            if (scl_rising) begin
                // sample SDA from bus at rising edges when master drives addresses/ptr
                case (slave_state)
                    S_IDLE: begin
                        // look for start sequence (we detect by master pulling SDA low while SCL high)
                        // It's difficult to robustly detect START in small TB; instead we begin sampling incoming address when master starts drive bits.
                        // We'll attempt to sample bits if master is driving them (i.e., sda tri-state is being driven by master)
                        // Start sampling first byte as address if master drives sda (master.sda_oe=1)
                        // We'll simply attempt to sample when scl rising and the master is busy
                        if (master_i.busy) begin
                            slave_state <= S_ADDR;
                            bit_index <= 7;
                            recv_shift <= 8'd0;
                        end
                    end
                    S_ADDR: begin
                        recv_shift <= {recv_shift[6:0], sda};
                        if (bit_index == 0) begin
                            // received full address+rw
                            if (recv_shift[7:1] == 7'h48) begin
                                if (recv_shift[0] == 1'b0) begin
                                    // write command -> expect reg ptr next
                                    slave_state <= S_ACK;
                                end else begin
                                    // read request from address phase (rare here)
                                    slave_state <= S_ACK;
                                end
                            end else begin
                                // not our address -> ignore
                                slave_state <= S_DONE;
                            end
                            bit_index <= 7;
                        end else begin
                            bit_index <= bit_index - 1;
                        end
                    end

                    S_REG: begin
                        // sample reg pointer
                        recv_shift <= {recv_shift[6:0], sda};
                        if (bit_index == 0) begin
                            // we got reg pointer; expect repeated start and read next
                            slave_state <= S_ACK;
                            bit_index <= 7;
                        end else bit_index <= bit_index - 1;
                    end

                    S_SEND1, S_SEND2: begin
                        // while sending, master will sample slave on rising edges; we do not sample here.
                    end

                    default: ;
                endcase
            end

            // Provide ACK by driving SDA low during ACK bit time: master releases SDA and expects ACK on rising edge
            // We'll attempt a simplistic heuristic: whenever master releases SDA (sda tri-state) and a byte just finished (we detect master bit count by observing transitions),
            // we drive SDA low for one SCL cycle to ACK.
            // To keep testbench simple, we will ACK after the first address (write) and after reg ptr, and then when master issues address read we'll ACK.
            // We'll approximate by checking master's internal state (this is allowed in TB).
            if (master_i.state == master_i.ACK_WAIT) begin
                // master is about to sample ACK on next SCL rising; drive ACK low now so that master's sample sees it
                sda_slave_drive <= 1;
            end

            // When master releases SDA for reading data (master.state==READ_BYTE), we must drive data bits on SDA during SCL low so master samples on rising.
            if (master_i.state == master_i.READ_BYTE) begin
                // Determine which byte and which bit to drive
                // master samples bits on scl_rising, but slave must set SDA while SCL low. We'll prepare the bit when scl_falling arrives.
                // We'll handle actual bit drive on scl_falling block below.
            end
        end
    end

    // Drive data bits during SCL falling edges (so they are stable when master samples on rising)
    reg [3:0] send_bit_idx;
    always @(posedge clk) begin
        if (!rst_n) begin
            send_bit_idx <= 7;
            sda_slave_drive <= 0;
        end else begin
            if (scl_falling) begin
                if (master_i.state == master_i.READ_BYTE) begin
                    if (master_i.byte_index == 3) begin
                        // drive MSB byte (slave_data[15:8])
                        sda_slave_drive <= ~slave_data[15 - send_bit_idx] ? 0 : 1; // but we only pull low for '0'. simulate open-drain: pull low for bit==0
                        // Implement simpler: if bit==0 -> drive low, else release
                        if (slave_data[15 - send_bit_idx] == 1'b0) sda_slave_drive <= 1; else sda_slave_drive <= 0;
                        if (send_bit_idx == 0) send_bit_idx <= 7; else send_bit_idx <= send_bit_idx - 1;
                    end else if (master_i.byte_index == 4) begin
                        // drive LSB byte (slave_data[7:0])
                        if (slave_data[7 - send_bit_idx] == 1'b0) sda_slave_drive <= 1; else sda_slave_drive <= 0;
                        if (send_bit_idx == 0) send_bit_idx <= 7; else send_bit_idx <= send_bit_idx - 1;
                    end else begin
                        sda_slave_drive <= 0;
                    end
                end else begin
                    sda_slave_drive <= 0;
                    send_bit_idx <= 7;
                end
            end
        end
    end

endmodule




