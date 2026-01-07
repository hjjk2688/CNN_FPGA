module maxpool_relu #(parameter CONV_BIT = 12, HALF_WIDTH = 12, HALF_HEIGHT = 12, HALF_WIDTH_BIT = 4) (
    input clk,
    input rst_n,    // asynchronous reset, active low
    input valid_in,
    input signed [CONV_BIT - 1 : 0] conv_out_1, conv_out_2, conv_out_3,
    output reg [CONV_BIT - 1 : 0] max_value_1, max_value_2, max_value_3,
    output reg valid_out_relu
    );

    reg signed [CONV_BIT - 1:0] buffer1 [0:HALF_WIDTH - 1];
    reg signed [CONV_BIT - 1:0] buffer2 [0:HALF_WIDTH - 1];
    reg signed [CONV_BIT - 1:0] buffer3 [0:HALF_WIDTH - 1];

    reg [HALF_WIDTH_BIT - 1:0] pcount;
    reg state;
    reg flag;
    
    integer k; // 초기화 루프용 변수

    // ★★★ [수정됨] 비동기 리셋 적용 (or negedge rst_n 추가) ★★★
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            // 이제 리셋 신호가 오면 클럭을 안 기다리고 '즉시' 실행됩니다.
            valid_out_relu <= 0;
            pcount <= 0;
            state <= 0;
            flag <= 0;
            
            max_value_1 <= 0;
            max_value_2 <= 0;
            max_value_3 <= 0;

            for (k = 0; k < HALF_WIDTH; k = k + 1) begin
                buffer1[k] <= 0;
                buffer2[k] <= 0;
                buffer3[k] <= 0;
            end
            
        end else if(valid_in) begin
            // 1. 동작 제어
            flag <= ~flag;

            // 2. 데이터 처리 로직
            if(state == 0) begin    // 첫 번째 행
                valid_out_relu <= 0;
                if(flag == 0) begin 
                    buffer1[pcount] <= conv_out_1;
                    buffer2[pcount] <= conv_out_2;
                    buffer3[pcount] <= conv_out_3;
                end else begin      
                    if(buffer1[pcount] < conv_out_1) buffer1[pcount] <= conv_out_1;
                    if(buffer2[pcount] < conv_out_2) buffer2[pcount] <= conv_out_2;
                    if(buffer3[pcount] < conv_out_3) buffer3[pcount] <= conv_out_3;
                end
            end else begin          // 두 번째 행
                if(flag == 0) begin 
                    valid_out_relu <= 0;
                    if(buffer1[pcount] < conv_out_1) buffer1[pcount] <= conv_out_1;
                    if(buffer2[pcount] < conv_out_2) buffer2[pcount] <= conv_out_2;
                    if(buffer3[pcount] < conv_out_3) buffer3[pcount] <= conv_out_3;
                end else begin      
                    valid_out_relu <= 1;
                    
                    // ReLU & Max 값 결정
                    max_value_1 <= ( (buffer1[pcount] < conv_out_1 ? conv_out_1 : buffer1[pcount]) > 0 ) ? (buffer1[pcount] < conv_out_1 ? conv_out_1 : buffer1[pcount]) : 0;
                    max_value_2 <= ( (buffer2[pcount] < conv_out_2 ? conv_out_2 : buffer2[pcount]) > 0 ) ? (buffer2[pcount] < conv_out_2 ? conv_out_2 : buffer2[pcount]) : 0;
                    max_value_3 <= ( (buffer3[pcount] < conv_out_3 ? conv_out_3 : buffer3[pcount]) > 0 ) ? (buffer3[pcount] < conv_out_3 ? conv_out_3 : buffer3[pcount]) : 0;
                end
            end

            // 3. 카운터 업데이트
            if(flag == 1) begin
                if(pcount == HALF_WIDTH - 1) begin
                    pcount <= 0;
                    state <= ~state;
                end else begin
                    pcount <= pcount + 1;
                end
            end
        end else begin
             valid_out_relu <= 0;
        end
    end

endmodule
