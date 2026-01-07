`timescale 1ns / 1ps

module vga_controller (
    input wire clk,           // Pixel Clock (25MHz)
    input wire reset_n,       

    // AXI Stream Interface
    input wire [31:0] s_axis_tdata,
    input wire        s_axis_tvalid,
    input wire        s_axis_tlast,
    input wire        s_axis_tuser,   // 이건 이제 안 씁니다 (연결만 해두세요)
    output wire       s_axis_tready,

    // VGA Output (빵판 연결용)
    output wire hsync,
    output wire vsync,
    output wire vgaRed,
    output wire vgaGreen,
    output wire vgaBlue
);

    // =============================================================
    // [해상도 설정] 640 x 480 @ 60Hz
    // =============================================================
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;
    
    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    reg [9:0] h_cnt = 0;
    reg [9:0] v_cnt = 0;
    wire active_area;

    // ★★★ 핵심 변수: 시스템 켜진 후 첫 데이터를 받았는지 체크 ★★★
    reg system_synced = 0; 

    // =============================================================
    // [Ready 신호]
    // =============================================================
    // 1. 화면 출력 구간(active_area)이면 데이터를 달라고 함
    // 2. OR, 아직 싱크가 안 맞았는데 데이터가 들어오려고 하면(tvalid)
    //    일단 데이터를 받아서 카운터를 리셋해야 하므로 Ready를 줍니다.
    assign s_axis_tready = active_area || (!system_synced && s_axis_tvalid);

    // =============================================================
    // [카운터 및 강제 정렬 로직]
    // =============================================================
    always @(posedge clk) begin
        if (!reset_n) begin
            h_cnt <= 0;
            v_cnt <= 0;
            system_synced <= 0;
        end
        else begin
            // [강제 정렬 로직]
            // 시스템 켜지고 아직 정렬 안 됨(0) + 데이터 유효(Valid) + 준비됨(Ready)
            // -> 즉, "VDMA가 보내는 첫 번째 픽셀"이 도착한 순간!
            if (!system_synced && s_axis_tvalid && s_axis_tready) begin
                h_cnt <= 0;          // 좌표를 무조건 0,0으로 강제 초기화
                v_cnt <= 0;
                system_synced <= 1;  // "이제 정렬 맞췄다"고 깃발 꽂음 (두 번 다시 안 함)
            end
            // [평상시 동작]
            else begin
                if (h_cnt == H_TOTAL - 1) begin
                    h_cnt <= 0;
                    if (v_cnt == V_TOTAL - 1) v_cnt <= 0;
                    else v_cnt <= v_cnt + 1;
                end 
                else begin
                    h_cnt <= h_cnt + 1;
                end
            end
        end
    end

    // =============================================================
    // [출력 로직]
    // =============================================================
    assign hsync = ~((h_cnt >= H_VISIBLE + H_FRONT) && (h_cnt < H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync = ~((v_cnt >= V_VISIBLE + V_FRONT) && (v_cnt < V_VISIBLE + V_FRONT + V_SYNC));

    assign active_area = (h_cnt < H_VISIBLE) && (v_cnt < V_VISIBLE);

    // 상위 비트 하나씩만 따서 출력 (빵판 1비트 컬러용)
    assign vgaRed   = (active_area && s_axis_tvalid) ? s_axis_tdata[23] : 1'b0; 
    assign vgaGreen = (active_area && s_axis_tvalid) ? s_axis_tdata[15] : 1'b0; 
    assign vgaBlue  = (active_area && s_axis_tvalid) ? s_axis_tdata[7]  : 1'b0; 

endmodule
