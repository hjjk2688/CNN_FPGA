## 스위치 (start_sw_0) - Zybo 보드의 SW0
#set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { start_sw_0 }];

## 결과 출력 LED (result_leds_0[3:0]) - Zybo LD0 ~ LD3
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { result_leds_0[0] }];
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { result_leds_0[1] }];
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { result_leds_0[2] }];
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { result_leds_0[3] }];

## 연산 완료 및 상태 LED (done_led들)
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { done_led_0 }];    # LD4
set_property -dict { PACKAGE_PIN F17   IOSTANDARD LVCMOS33 } [get_ports { done_led_g_0 }];  # RGB LED Green
set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { done_led_b_0 }];  # RGB LED Blue


## ----------------------------------------------------------------------------
## 1. I2C (Touch Screen) - JD Header (T14, T15)
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33   PULLUP TRUE } [get_ports IIC_0_0_scl_io]
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS33   PULLUP TRUE } [get_ports IIC_0_0_sda_io]

## ----------------------------------------------------------------------------
## 2. SPI (LCD ILI9341) - JE Header (V12, W16, J15, H15)
## ----------------------------------------------------------------------------
# SCK (JE1)
set_property -dict { PACKAGE_PIN V12   IOSTANDARD LVCMOS33 } [get_ports SPI_0_0_sck_io]

# MOSI (JE2)
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS33 } [get_ports SPI_0_0_io0_io]

# MISO (JE3)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports SPI_0_0_io1_io]

# CS (JE4) - 에러 메시지에 맞춰 대괄호 삭제
set_property -dict { PACKAGE_PIN H15   IOSTANDARD LVCMOS33 } [get_ports SPI_0_0_ss_io]

## ----------------------------------------------------------------------------
## 3. GPIO (12-bit) - 터치 제어, LCD 제어, 버튼 및 나머지 JC 할당
## ----------------------------------------------------------------------------

# [0] 터치 리셋 (R14)
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[0]}]
# [1] 터치 인터럽트 (P14)
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[1]}]
# [2] LCD D/C (V13)
set_property -dict { PACKAGE_PIN V13   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[2]}]
# [3] LCD RST (U17)
set_property -dict { PACKAGE_PIN U17   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[3]}]
# [4] 버튼 0 (K18)
set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[4]}]
# [5] 버튼 1 (P16)
set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[5]}]

# 나머지 안 쓰는 GPIO (6~11) -> JC 헤더 임의 할당
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[6]}]  ;# JC1
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[7]}]  ;# JC2
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[8]}]  ;# JC3
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[9]}]  ;# JC4
set_property -dict { PACKAGE_PIN W14   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[10]}] ;# JC7
set_property -dict { PACKAGE_PIN Y14   IOSTANDARD LVCMOS33 } [get_ports {GPIO_0_0_tri_io[11]}] ;# JC8


# SPI 엑스트라 칩 셀렉트 (사용하지 않지만 에러 방지를 위해 임의 할당)
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports SPI_0_0_ss1_o]
set_property -dict { PACKAGE_PIN T12   IOSTANDARD LVCMOS33 } [get_ports SPI_0_0_ss2_o]


## ----------------------------------------------------------------------------
## Pmod Header JB (Standard)
## 핀 배치:
## 윗줄: 1(Red), 2(Green), 3(Blue)
## 아랫줄: 7(Hsync), 8(Vsync)
## ----------------------------------------------------------------------------

# JB1 -> Red (V8)
set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { vgaRed_0}]; 

# JB2 -> Green (W8)
set_property -dict { PACKAGE_PIN W8    IOSTANDARD LVCMOS33 } [get_ports { vgaGreen_0}]; 

# JB3 -> Blue (U7)
set_property -dict { PACKAGE_PIN U7    IOSTANDARD LVCMOS33 } [get_ports { vgaBlue_0}]; 

# JB7 -> Hsync (Y7 - 아랫줄 첫 번째)
set_property -dict { PACKAGE_PIN Y7    IOSTANDARD LVCMOS33 } [get_ports { hsync_0}]; 

# JB8 -> Vsync (Y6 - 아랫줄 두 번째)
set_property -dict { PACKAGE_PIN Y6    IOSTANDARD LVCMOS33 } [get_ports { vsync_0}];


set_clock_groups -asynchronous -group [get_clocks clk_fpga_0] -group [get_clocks clk_fpga_1]
