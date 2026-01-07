module conv2_calc_3 (
    input                       clk,
    input                       rst_n,
    input        signed               valid_out_buf,

    // Inputs from Channel 1 Buffer
    input     signed  [11:0]          data_out1_0, data_out1_1, data_out1_2, data_out1_3, data_out1_4,
                                data_out1_5, data_out1_6, data_out1_7, data_out1_8, data_out1_9,
                                data_out1_10, data_out1_11, data_out1_12, data_out1_13, data_out1_14,
                                data_out1_15, data_out1_16, data_out1_17, data_out1_18, data_out1_19,
                                data_out1_20, data_out1_21, data_out1_22, data_out1_23, data_out1_24,
    // Inputs from Channel 2 Buffer
    input    signed   [11:0]          data_out2_0, data_out2_1, data_out2_2, data_out2_3, data_out2_4,
                                data_out2_5, data_out2_6, data_out2_7, data_out2_8, data_out2_9,
                                data_out2_10, data_out2_11, data_out2_12, data_out2_13, data_out2_14,
                                data_out2_15, data_out2_16, data_out2_17, data_out2_18, data_out2_19,
                                data_out2_20, data_out2_21, data_out2_22, data_out2_23, data_out2_24,
    // Inputs from Channel 3 Buffer
    input    signed   [11:0]          data_out3_0, data_out3_1, data_out3_2, data_out3_3, data_out3_4,
                                data_out3_5, data_out3_6, data_out3_7, data_out3_8, data_out3_9,
                                data_out3_10, data_out3_11, data_out3_12, data_out3_13, data_out3_14,
                                data_out3_15, data_out3_16, data_out3_17, data_out3_18, data_out3_19,
                                data_out3_20, data_out3_21, data_out3_22, data_out3_23, data_out3_24,

    output reg signed [13:0]    conv_out_calc,
    output reg                  valid_out_calc
);

    localparam P_STAGES = 7; // Deeper pipeline for 3D convolution

    function signed [7:0] get_w1(input [4:0] addr);
        case(addr)
            5'd00: get_w1 = 8'sh1d; 5'd01: get_w1 = 8'sh2a; 5'd02: get_w1 = 8'sh2b; 5'd03: get_w1 = 8'sh24; 5'd04: get_w1 = 8'sh27; 
            5'd05: get_w1 = 8'sh2c; 5'd06: get_w1 = 8'sh2c; 5'd07: get_w1 = 8'sh2c; 5'd08: get_w1 = 8'sh29; 5'd09: get_w1 = 8'sh22; 
            5'd10: get_w1 = 8'sh15; 5'd11: get_w1 = 8'sh1d; 5'd12: get_w1 = 8'sh38; 5'd13: get_w1 = 8'sh31; 5'd14: get_w1 = 8'sh20; 
            5'd15: get_w1 = 8'sh1b; 5'd16: get_w1 = 8'sh26; 5'd17: get_w1 = 8'sh47; 5'd18: get_w1 = 8'sh30; 5'd19: get_w1 = 8'sh26; 
            5'd20: get_w1 = 8'sh2e; 5'd21: get_w1 = 8'sh6b; 5'd22: get_w1 = 8'sh75; 5'd23: get_w1 = 8'sh5a; 5'd24: get_w1 = 8'sh3b; 
            default: get_w1 = 8'sh00;
        endcase
    endfunction
    function signed [7:0] get_w2(input [4:0] addr);
        case(addr)
            5'd00: get_w2 = 8'sh09; 5'd01: get_w2 = 8'sh13; 5'd02: get_w2 = 8'sh1b; 5'd03: get_w2 = 8'sh12; 5'd04: get_w2 = 8'shf9; 
            5'd05: get_w2 = 8'shfa; 5'd06: get_w2 = 8'sh03; 5'd07: get_w2 = 8'sh08; 5'd08: get_w2 = 8'sh01; 5'd09: get_w2 = 8'shfd; 
            5'd10: get_w2 = 8'sh03; 5'd11: get_w2 = 8'shfc; 5'd12: get_w2 = 8'sh08; 5'd13: get_w2 = 8'sh0d; 5'd14: get_w2 = 8'sh08; 
            5'd15: get_w2 = 8'shfa; 5'd16: get_w2 = 8'shf8; 5'd17: get_w2 = 8'sh02; 5'd18: get_w2 = 8'shfb; 5'd19: get_w2 = 8'shfb; 
            5'd20: get_w2 = 8'shf6; 5'd21: get_w2 = 8'shfb; 5'd22: get_w2 = 8'shed; 5'd23: get_w2 = 8'shd1; 5'd24: get_w2 = 8'shb4; 
            default: get_w2 = 8'sh00;
        endcase
    endfunction
    function signed [7:0] get_w3(input [4:0] addr);
        case(addr)
            5'd00: get_w3 = 8'shf6; 5'd01: get_w3 = 8'sh0b; 5'd02: get_w3 = 8'sh26; 5'd03: get_w3 = 8'sh1f; 5'd04: get_w3 = 8'sh1a; 
            5'd05: get_w3 = 8'sh07; 5'd06: get_w3 = 8'sh0e; 5'd07: get_w3 = 8'sh17; 5'd08: get_w3 = 8'sh16; 5'd09: get_w3 = 8'sh1e; 
            5'd10: get_w3 = 8'sh0d; 5'd11: get_w3 = 8'sh1a; 5'd12: get_w3 = 8'sh1a; 5'd13: get_w3 = 8'sh16; 5'd14: get_w3 = 8'sh1d; 
            5'd15: get_w3 = 8'sh05; 5'd16: get_w3 = 8'sh02; 5'd17: get_w3 = 8'sh12; 5'd18: get_w3 = 8'sh18; 5'd19: get_w3 = 8'sh25; 
            5'd20: get_w3 = 8'shfb; 5'd21: get_w3 = 8'sh10; 5'd22: get_w3 = 8'sh27; 5'd23: get_w3 = 8'sh28; 5'd24: get_w3 = 8'sh18; 
            default: get_w3 = 8'sh00;
        endcase
    endfunction

    // --- Pipeline Registers (identical structure to conv2_calc_1) ---
    reg [11:0] p1_s0[0:24], p2_s0[0:24], p3_s0[0:24];
    reg signed [19:0] product1_s1[0:24], product2_s1[0:24], product3_s1[0:24];
    reg signed [21:0] sum1_s2[0:12], sum2_s2[0:12], sum3_s2[0:12];
    reg signed [21:0] sum1_s3[0:6],  sum2_s3[0:6],  sum3_s3[0:6];
    reg signed [21:0] sum1_s4[0:3],  sum2_s4[0:3],  sum3_s4[0:3];
    reg signed [21:0] sum1_s5[0:1],  sum2_s5[0:1],  sum3_s5[0:1];
    reg signed [22:0] sum1_s6, sum2_s6, sum3_s6;
    reg signed [23:0] final_sum_s7;
    reg [P_STAGES-1:0] valid_pipe;
    
    integer i; // Declare loop variable here
    always @(posedge clk) begin
        
        if (!rst_n) begin
            valid_pipe <= 0;
            valid_out_calc <= 0;
            conv_out_calc <= 0;
            final_sum_s7 <= 0;
            // Omitting detailed resets for brevity, but all pipeline registers should be reset here
        end else begin
            // --- Pipeline Control ---
            valid_pipe <= {valid_pipe[P_STAGES-2:0], valid_out_buf};
            valid_out_calc <= valid_pipe[P_STAGES-1];

            // --- Stage 0: Register Inputs ---
            if (valid_out_buf) begin
                // (Inputs are registered, code omitted for brevity, same as conv2_calc_1)
                p1_s0[0] <= data_out1_0; p1_s0[1] <= data_out1_1; p1_s0[2] <= data_out1_2; p1_s0[3] <= data_out1_3; p1_s0[4] <= data_out1_4; p1_s0[5] <= data_out1_5; p1_s0[6] <= data_out1_6; p1_s0[7] <= data_out1_7; p1_s0[8] <= data_out1_8; p1_s0[9] <= data_out1_9; p1_s0[10] <= data_out1_10; p1_s0[11] <= data_out1_11; p1_s0[12] <= data_out1_12; p1_s0[13] <= data_out1_13; p1_s0[14] <= data_out1_14; p1_s0[15] <= data_out1_15; p1_s0[16] <= data_out1_16; p1_s0[17] <= data_out1_17; p1_s0[18] <= data_out1_18; p1_s0[19] <= data_out1_19; p1_s0[20] <= data_out1_20; p1_s0[21] <= data_out1_21; p1_s0[22] <= data_out1_22; p1_s0[23] <= data_out1_23; p1_s0[24] <= data_out1_24;
                p2_s0[0] <= data_out2_0; p2_s0[1] <= data_out2_1; p2_s0[2] <= data_out2_2; p2_s0[3] <= data_out2_3; p2_s0[4] <= data_out2_4; p2_s0[5] <= data_out2_5; p2_s0[6] <= data_out2_6; p2_s0[7] <= data_out2_7; p2_s0[8] <= data_out2_8; p2_s0[9] <= data_out2_9; p2_s0[10] <= data_out2_10; p2_s0[11] <= data_out2_11; p2_s0[12] <= data_out2_12; p2_s0[13] <= data_out2_13; p2_s0[14] <= data_out2_14; p2_s0[15] <= data_out2_15; p2_s0[16] <= data_out2_16; p2_s0[17] <= data_out2_17; p2_s0[18] <= data_out2_18; p2_s0[19] <= data_out2_19; p2_s0[20] <= data_out2_20; p2_s0[21] <= data_out2_21; p2_s0[22] <= data_out2_22; p2_s0[23] <= data_out2_23; p2_s0[24] <= data_out2_24;
                p3_s0[0] <= data_out3_0; p3_s0[1] <= data_out3_1; p3_s0[2] <= data_out3_2; p3_s0[3] <= data_out3_3; p3_s0[4] <= data_out3_4; p3_s0[5] <= data_out3_5; p3_s0[6] <= data_out3_6; p3_s0[7] <= data_out3_7; p3_s0[8] <= data_out3_8; p3_s0[9] <= data_out3_9; p3_s0[10] <= data_out3_10; p3_s0[11] <= data_out3_11; p3_s0[12] <= data_out3_12; p3_s0[13] <= data_out3_13; p3_s0[14] <= data_out3_14; p3_s0[15] <= data_out3_15; p3_s0[16] <= data_out3_16; p3_s0[17] <= data_out3_17; p3_s0[18] <= data_out3_18; p3_s0[19] <= data_out3_19; p3_s0[20] <= data_out3_20; p3_s0[21] <= data_out3_21; p3_s0[22] <= data_out3_22; p3_s0[23] <= data_out3_23; p3_s0[24] <= data_out3_24;
            end

            // --- Stage 1: Multiplication ---
            for (i = 0; i < 25; i = i + 1) begin
                product1_s1[i] <= $signed(p1_s0[i]) * get_w1(i);
                product2_s1[i] <= $signed(p2_s0[i]) * get_w2(i);
                product3_s1[i] <= $signed(p3_s0[i]) * get_w3(i);
            end

            // --- Stage 2-6: Adder Trees for each channel ---
            // (Logic is identical to conv2_calc_1, omitted for brevity)
            for (i=0; i<12; i=i+1) sum1_s2[i] <= product1_s1[2*i] + product1_s1[2*i+1];
            sum1_s2[12] <= product1_s1[24];
            for (i=0; i<6; i=i+1) sum1_s3[i] <= sum1_s2[2*i] + sum1_s2[2*i+1];
            sum1_s3[6] <= sum1_s2[12];
            sum1_s4[0] <= sum1_s3[0] + sum1_s3[1]; sum1_s4[1] <= sum1_s3[2] + sum1_s3[3]; sum1_s4[2] <= sum1_s3[4] + sum1_s3[5]; sum1_s4[3] <= sum1_s3[6];
            sum1_s5[0] <= sum1_s4[0] + sum1_s4[1]; sum1_s5[1] <= sum1_s4[2] + sum1_s4[3];
            sum1_s6 <= sum1_s5[0] + sum1_s5[1];

            for (i=0; i<12; i=i+1) sum2_s2[i] <= product2_s1[2*i] + product2_s1[2*i+1];
            sum2_s2[12] <= product2_s1[24];
            for (i=0; i<6; i=i+1) sum2_s3[i] <= sum2_s2[2*i] + sum2_s2[2*i+1];
            sum2_s3[6] <= sum2_s2[12];
            sum2_s4[0] <= sum2_s3[0] + sum2_s3[1]; sum2_s4[1] <= sum2_s3[2] + sum2_s3[3]; sum2_s4[2] <= sum2_s3[4] + sum2_s3[5]; sum2_s4[3] <= sum2_s3[6];
            sum2_s5[0] <= sum2_s4[0] + sum2_s4[1]; sum2_s5[1] <= sum2_s4[2] + sum2_s4[3];
            sum2_s6 <= sum2_s5[0] + sum2_s5[1];

            for (i=0; i<12; i=i+1) sum3_s2[i] <= product3_s1[2*i] + product3_s1[2*i+1];
            sum3_s2[12] <= product3_s1[24];
            for (i=0; i<6; i=i+1) sum3_s3[i] <= sum3_s2[2*i] + sum3_s2[2*i+1];
            sum3_s3[6] <= sum3_s2[12];
            sum3_s4[0] <= sum3_s3[0] + sum3_s3[1]; sum3_s4[1] <= sum3_s3[2] + sum3_s3[3]; sum3_s4[2] <= sum3_s3[4] + sum3_s3[5]; sum3_s4[3] <= sum3_s3[6];
            sum3_s5[0] <= sum3_s4[0] + sum3_s4[1]; sum3_s5[1] <= sum3_s4[2] + sum3_s4[3];
            sum3_s6 <= sum3_s5[0] + sum3_s5[1];

            // --- Stage 7: Final Accumulation ---
            final_sum_s7 <= sum1_s6 + sum2_s6 + sum3_s6;

            // --- Final Output Assignment ---
            if (valid_pipe[P_STAGES-1]) begin
//                conv_out_calc <= final_sum_s7[23:10]; // Truncate to 14 bits.
//                conv_out_calc <= $signed(final_sum_s7) >>> 10;
                conv_out_calc <= ($signed(final_sum_s7 ) >>> 7) + 8'shfd;

            end
        end
    end

endmodule
