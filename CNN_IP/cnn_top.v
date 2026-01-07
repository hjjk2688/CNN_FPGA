`timescale 1ns / 1ps
module cnn_top (
    input wire          clk_cnn_10M,     
    input wire          rst_n,           
    
    // --- AXI-Stream Slave Interface ---
    input wire [7:0]    s_axis_tdata,  
    input wire          s_axis_tvalid, 
    output reg          s_axis_tready,   
    input wire          s_axis_tlast,    

    // --- Control and Output ---
    output reg [31:0] final_time, 
    
    input wire          start_sw,        
    output reg [3:0]    result_leds,     
    output reg          done_led,        
    output wire         done_led_g,
    output wire         done_led_b
   
    
    );

    assign done_led_g = 0;
    assign done_led_b = 0;

    // 상태 정의
    localparam S_IDLE      = 3'd0;
    localparam S_RUN_CNN   = 3'd1;
    localparam S_PADDING   = 3'd2; // [추가됨] 파이프라인 밀어내기 상태
    localparam S_WAIT_DONE = 3'd3; 
    localparam S_RESULT    = 3'd4; 

    reg [2:0] state;
    
    // [중요] 패딩 카운터를 2000까지 세기 위해 12비트로 선언
    reg [11:0] padding_cnt; 
    reg cnn_pipeline_valid;
    

    wire [3:0] fc_result_wire; 
    
    reg [3:0] captured_result; 
    reg       result_captured_flag; // 결과를 잡았는지 표시하는 깃발

    wire soft_rst_n_wire = rst_n && start_sw; 
    
        // 파이프라인 제어 신호들
    wire conv1_valid, mp1_valid, conv2_valid, mp2_valid, fc_valid;
    
    // 데이터 연결 와이어들
    wire [11:0] conv1_out_1, conv1_out_2, conv1_out_3;
    wire [11:0] mp1_out_1, mp1_out_2, mp1_out_3;
    wire [11:0] conv2_out_1, conv2_out_2, conv2_out_3;
    wire [11:0] mp2_out_1, mp2_out_2, mp2_out_3;
    
    
     // [핵심] 패딩 상태일 때는 외부 데이터 대신 '0(검정색)'을 강제로 주입
    wire [7:0] cnn_data_in;
    assign cnn_data_in = (state == S_PADDING) ? 8'd0 : s_axis_tdata;
    
    // --- 모듈 연결 수정 ---
    // [중요] data_in에 s_axis_tdata 대신 위에서 만든 'cnn_data_in'을 연결해야 합니다.
    conv1_layer u_conv1 (
        .clk(clk_cnn_10M), .rst_n(soft_rst_n_wire), .valid_in(cnn_pipeline_valid), 
        .data_in(cnn_data_in), // <--- 수정된 부분
        .conv_out_1(conv1_out_1), .conv_out_2(conv1_out_2), .conv_out_3(conv1_out_3),
        .valid_out_conv(conv1_valid)
    );
    
    // 나머지 모듈들은 기존과 동일하게 연결
    maxpool_relu u_mp1 (
        .clk(clk_cnn_10M), .rst_n(soft_rst_n_wire), .valid_in(conv1_valid),
        .conv_out_1(conv1_out_1), .conv_out_2(conv1_out_2), .conv_out_3(conv1_out_3),
        .max_value_1(mp1_out_1), .max_value_2(mp1_out_2), .max_value_3(mp1_out_3),
        .valid_out_relu(mp1_valid)
    );

    conv2_layer u_conv2 (
        .clk(clk_cnn_10M), .rst_n(soft_rst_n_wire), .valid_in(mp1_valid),
        .max_value_1(mp1_out_1), .max_value_2(mp1_out_2), .max_value_3(mp1_out_3),
        .conv2_out_1(conv2_out_1), .conv2_out_2(conv2_out_2), .conv2_out_3(conv2_out_3),
        .valid_out_conv2(conv2_valid)
    );

    maxpool_relu u_mp2 (
        .clk(clk_cnn_10M), .rst_n(soft_rst_n_wire), .valid_in(conv2_valid),
        .conv_out_1(conv2_out_1), .conv_out_2(conv2_out_2), .conv_out_3(conv2_out_3),
        .max_value_1(mp2_out_1), .max_value_2(mp2_out_2), .max_value_3(mp2_out_3),
        .valid_out_relu(mp2_valid)
    );

    fully_connected u_fc (
        .clk(clk_cnn_10M), .rst_n(soft_rst_n_wire), 
        .valid_in(mp2_valid), // u_mp2의 출력 valid를 연결
        .data_in_1(mp2_out_1), .data_in_2(mp2_out_2), .data_in_3(mp2_out_3),
        .result_leds(fc_result_wire), 
        .valid_out_fc(fc_valid)
    );     
    


    // 1. TREADY 제어 (RUN 상태에서만 데이터 받음)
    always @(*) begin
        if (state == S_RUN_CNN && start_sw == 1'b1) 
            s_axis_tready = 1'b1;
        else 
            s_axis_tready = 1'b0;
    end


    // 2. 메인 상태 머신
    always @(posedge clk_cnn_10M or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            cnn_pipeline_valid <= 0;
            padding_cnt <= 0;
            // [초기화 추가]
            captured_result <= 0;
            result_captured_flag <= 0;
        end 
        else begin
            // [항상 체크] 상태와 상관없이, FC Layer에서 유효한 결과가 나오면
            // 그리고 아직 결과를 잡지 않았다면(flag == 0), 그 값을 '진짜 결과'로 저장한다.
            if (fc_valid && !result_captured_flag) begin
                captured_result <= fc_result_wire;
                result_captured_flag <= 1'b1;
            end

            if (start_sw == 1'b0) begin 
                state <= S_IDLE;
                cnn_pipeline_valid <= 0;
                padding_cnt <= 0;
                result_captured_flag <= 0; // 스위치 끄면 플래그 초기화
            end 
            else begin
                case(state)
                    S_IDLE: begin
                        state <= S_RUN_CNN;
                        padding_cnt <= 0;
                        result_captured_flag <= 0; // 시작할 때 플래그 초기화
                    end

                    S_RUN_CNN: begin
                        // 기존 코드 유지
                        if (s_axis_tvalid && s_axis_tready) begin
                            cnn_pipeline_valid <= 1'b1;
                            if (s_axis_tlast) begin
                                state <= S_PADDING;
                                padding_cnt <= 0;
                            end
                        end else begin
                            cnn_pipeline_valid <= 1'b0;
                        end
                    end

                    S_PADDING: begin
                        cnn_pipeline_valid <= 1'b1;
                        padding_cnt <= padding_cnt + 1;
                        
                        // 2000클럭 밀어내기
                        if (padding_cnt > 2000) begin
                             state <= S_WAIT_DONE;
                             cnn_pipeline_valid <= 1'b0;
                        end
                    end

                    S_WAIT_DONE: begin
                        cnn_pipeline_valid <= 1'b0;
                        // [수정] 이미 결과를 잡았다면 바로 결과창으로 이동
                        if (result_captured_flag) state <= S_RESULT;
                        // 만약 아직도 안 나왔다면(그럴리 없겠지만) 기다림
                        else if (fc_valid) state <= S_RESULT; 
                    end

                    S_RESULT: begin
                        // 결과 유지
                    end
                endcase
            end
        end
    end
// cnn_top.v 복구
    always @(posedge clk_cnn_10M or negedge rst_n) begin
        if(!rst_n) begin
            result_leds <= 4'b1111; // 리셋 확인용 (다 켜짐)
            done_led <= 0;
        end
        else begin
            if (state == S_RESULT) begin
                result_leds <= captured_result; // ★ 진짜 결과 출력
                done_led <= 1'b1;
            end
            else begin
                done_led <= 1'b0;
                if (start_sw == 0) result_leds <= 4'b1111;
            end
        end
    end
// 1. 포트 선언 (모듈 상단에 추가)
// output reg [31:0] final_time, 

    // 2. 내부 카운터 변수
    reg [31:0] cycle_counter;
    
    // 3. [분리된 로직] CNN 실행 시간 측정 카운터
    always @(posedge clk_cnn_10M or negedge rst_n) begin
        if (!rst_n) begin
            cycle_counter <= 0;
            final_time <= 0;
        end
        else if (start_sw == 1'b0) begin
            // 스위치가 꺼지면 언제든지 카운터 초기화
            cycle_counter <= 0;
        end
        else begin
            case (state)
                S_IDLE: begin
                    cycle_counter <= 0; // 시작 전 대기 상태에서는 0 유지
                end
    
                S_RUN_CNN, S_PADDING, S_WAIT_DONE: begin
                    // 데이터 입력 시작부터 결과가 나오기 전까지 카운트 증가
                    cycle_counter <= cycle_counter + 1;
                end
    
                S_RESULT: begin
                    // 결과 상태에 진입하는 순간의 값을 final_time에 고정 (Latching)
                    if (cycle_counter != 0) begin
                        final_time <= cycle_counter;
                    end
                    cycle_counter <= 0; // 카운터는 다음 계산을 위해 초기화 가능
                end
                
                default: cycle_counter <= 0;
            endcase
        end
    end
endmodule



