#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xiicps.h"
#include "xgpiops.h"
#include "xspips.h"
#include "sleep.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xaxidma.h"   // CNN DMA
#include "xaxivdma.h"  // Monitor VDMA
#include "xil_cache.h"
#include "xgpio.h"     // CNN Control
#include "image_data.h" // 모니터 이미지 데이터

// =============================================================
// [ID 정의]
// =============================================================
#define INTC_DEVICE_ID      XPAR_SCUGIC_SINGLE_DEVICE_ID
#define GPIO_INTR_ID        XPAR_XGPIOPS_0_INTR
#define PS_GPIO_ID          XPAR_XGPIOPS_0_DEVICE_ID
#define PS_IIC_ID           XPAR_XIICPS_0_DEVICE_ID
#define PS_SPI_ID           XPAR_XSPIPS_0_DEVICE_ID
#define CNN_DMA_ID          XPAR_AXIDMA_0_DEVICE_ID
#define AXI_GPIO_ID         XPAR_AXI_GPIO_0_DEVICE_ID
#define AXI_TIME_GPIO_ID 	XPAR_AXI_GPIO_1_DEVICE_ID
#define VDMA_DEVICE_ID      XPAR_AXI_VDMA_0_DEVICE_ID

// [메모리 및 해상도]
#define DDR_MONITOR_ADDR    0x10000000
#define SCREEN_WIDTH        640
#define SCREEN_HEIGHT       480

// [GPIO 핀]
#define GPIO_TOUCH_RST      (54 + 0)
#define GPIO_TOUCH_INT      (54 + 1)
#define GPIO_LCD_DC         (54 + 2)
#define GPIO_LCD_RST        (54 + 3)
#define GPIO_BTN_0          (54 + 4)
#define GPIO_BTN_1          (54 + 5)

#define I2C_ADDR_FT6336G    0x38
#define WHITE               0x0000
#define BLACK               0xFFFF

// =============================================================
// [전역 변수]
// =============================================================
XIicPs Iic;
XGpioPs Gpio;
XSpiPs SpiLcd;
XScuGic Intc;
XAxiDma AxiDma;     // CNN
XAxiVdma Vdma;      // Monitor
XGpio CnnCtrl;      // CNN Control
XGpio TimeCtrl;
u8 my_canvas[320][240];
u8 cnn_input_buffer[784] __attribute__ ((aligned (32)));
unsigned int *MonitorFrameBuffer = (unsigned int *) DDR_MONITOR_ADDR;

volatile int g_new_touch = 0;
int g_last_x = -1;
int g_last_y = -1;
volatile int LCD_ClearB = 0;
volatile int Print_CNN = 0;

// =============================================================
// [함수] VDMA (모니터) 설정
// =============================================================
int Init_VDMA() {
    xil_printf("Initializing VDMA...\r\n");
    XAxiVdma_Config *Config = XAxiVdma_LookupConfig(VDMA_DEVICE_ID);
    if (!Config) return XST_FAILURE;

    XAxiVdma_CfgInitialize(&Vdma, Config, Config->BaseAddress);

    XAxiVdma_DmaSetup ReadCfg;
    ReadCfg.VertSizeInput = SCREEN_HEIGHT;
    ReadCfg.HoriSizeInput = SCREEN_WIDTH * 4;
    ReadCfg.Stride = SCREEN_WIDTH * 4;
    ReadCfg.FrameDelay = 0;
    ReadCfg.EnableCircularBuf = 0;
    ReadCfg.EnableSync = 0;
    ReadCfg.FixedFrameStoreAddr = 0;
    ReadCfg.PointNum = 0;
    ReadCfg.EnableFrameCounter = 0;

    if (XAxiVdma_DmaConfig(&Vdma, XAXIVDMA_READ, &ReadCfg) != XST_SUCCESS) return XST_FAILURE;

    UINTPTR FrameStoreAddr = DDR_MONITOR_ADDR;
    if (XAxiVdma_DmaSetBufferAddr(&Vdma, XAXIVDMA_READ, &FrameStoreAddr) != XST_SUCCESS) return XST_FAILURE;
    if (XAxiVdma_DmaStart(&Vdma, XAXIVDMA_READ) != XST_SUCCESS) return XST_FAILURE;

    return XST_SUCCESS;
}

void Update_Monitor_Image(int result_index) {
    if (result_index < 0 || result_index > 9) return;
    xil_printf("Updating Monitor to %d\r\n", result_index);
    const u8 *src_image = num_images[result_index];
    for (int i = 0; i < SCREEN_WIDTH * SCREEN_HEIGHT; i++) {
        MonitorFrameBuffer[i] = (src_image[i] > 0) ? 0xFFFFFFFF : 0xFF000000;
    }
    Xil_DCacheFlushRange((UINTPTR) DDR_MONITOR_ADDR, SCREEN_WIDTH * SCREEN_HEIGHT * 4);
}

void Clear_Monitor() {
    memset((void*)MonitorFrameBuffer, 0, SCREEN_WIDTH * SCREEN_HEIGHT * 4);
    Xil_DCacheFlushRange((UINTPTR) DDR_MONITOR_ADDR, SCREEN_WIDTH * SCREEN_HEIGHT * 4);
}

// =============================================================
// [함수] CNN DMA 설정
// =============================================================
int Init_CNN_DMA() {
    XAxiDma_Config *CfgPtr = XAxiDma_LookupConfig(CNN_DMA_ID);
    if (!CfgPtr) return XST_FAILURE;
    if (XAxiDma_CfgInitialize(&AxiDma, CfgPtr) != XST_SUCCESS) return XST_FAILURE;
    XAxiDma_IntrDisable(&AxiDma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DMA_TO_DEVICE);
    return XST_SUCCESS;
}

// =============================================================
// [함수] LCD/Touch 드라이버 (변경 없음)
// =============================================================
void LCD_Write_Command(u8 cmd) { XGpioPs_WritePin(&Gpio, GPIO_LCD_DC, 0); XSpiPs_PolledTransfer(&SpiLcd, &cmd, NULL, 1); }
void LCD_Write_Data(u8 data) { XGpioPs_WritePin(&Gpio, GPIO_LCD_DC, 1); XSpiPs_PolledTransfer(&SpiLcd, &data, NULL, 1); }
void LCD_Write_Buffer(u8 *data, int len) { XGpioPs_WritePin(&Gpio, GPIO_LCD_DC, 1); XSpiPs_PolledTransfer(&SpiLcd, data, NULL, len); }
void LCD_SetAddressWindow(u16 x1, u16 y1, u16 x2, u16 y2) {
    LCD_Write_Command(0x2A); u8 x_buf[4] = { x1 >> 8, x1 & 0xFF, x2 >> 8, x2 & 0xFF }; LCD_Write_Buffer(x_buf, 4);
    LCD_Write_Command(0x2B); u8 y_buf[4] = { y1 >> 8, y1 & 0xFF, y2 >> 8, y2 & 0xFF }; LCD_Write_Buffer(y_buf, 4);
    LCD_Write_Command(0x2C);
}
void LCD_Clear(u16 color) {
    LCD_SetAddressWindow(0, 0, 239, 319); u8 c_buf[2] = { color >> 8, color & 0xFF };
    XGpioPs_WritePin(&Gpio, GPIO_LCD_DC, 1);
    for (int i = 0; i < 240 * 320; i++) XSpiPs_PolledTransfer(&SpiLcd, c_buf, NULL, 2);
    memset(my_canvas, 0, sizeof(my_canvas));
}
void LCD_DrawThickPoint(u16 x, u16 y, u16 color) {
    if (x < 5 || x > 234 || y < 5 || y > 314) return;
    LCD_SetAddressWindow(x - 5, y - 5, x + 5, y + 5);
    u8 p_data[242]; u8 hi = color >> 8, lo = color & 0xFF;
    for (int i = 0; i < 242; i += 2) { p_data[i] = hi; p_data[i + 1] = lo; }
    LCD_Write_Buffer(p_data, 242);
    for (int dy = -5; dy <= 5; dy++) for (int dx = -5; dx <= 5; dx++) my_canvas[y + dy][x + dx] = 255;
}
void LCD_DrawLine(int x1, int y1, int x2, int y2, u16 color) {
    int dx = abs(x2 - x1), dy = -abs(y2 - y1), sx = (x1 < x2) ? 1 : -1, sy = (y1 < y2) ? 1 : -1;
    int err = dx + dy, e2;
    while (1) {
        LCD_DrawThickPoint((u16) x1, (u16) y1, color);
        if (x1 == x2 && y1 == y2) break;
        e2 = 2 * err; if (e2 >= dy) { err += dy; x1 += sx; } if (e2 <= dx) { err += dx; y1 += sy; }
    }
}
void Process_Touch() {
    u8 buf[7]; u8 reg = 0x00;
    if (g_new_touch) {
        g_new_touch = 0;
        if (XIicPs_MasterSendPolled(&Iic, &reg, 1, I2C_ADDR_FT6336G) == XST_SUCCESS) {
            if (XIicPs_MasterRecvPolled(&Iic, buf, 7, I2C_ADDR_FT6336G) == XST_SUCCESS) {
                int touches = buf[2] & 0x0F;
                if (touches > 0) {
                    int x = ((buf[3] & 0x0F) << 8) | buf[4]; int y = ((buf[5] & 0x0F) << 8) | buf[6];
                    if (x < 240 && y < 320) {
                        if (g_last_x != -1) LCD_DrawLine(g_last_x, g_last_y, x, y, BLACK);
                        else LCD_DrawThickPoint(x, y, BLACK);
                        g_last_x = x; g_last_y = y; usleep(1000);
                    }
                } else { g_last_x = -1; g_last_y = -1; }
            }
        }
    }
}

// =============================================================
// [함수] 인터럽트 핸들러
// =============================================================
void GpioIntrHandler(void *CallBackRef) {
    XGpioPs *GpioPtr = (XGpioPs *) CallBackRef;
    if (XGpioPs_IntrGetStatusPin(GpioPtr, GPIO_TOUCH_INT)) {
        g_new_touch = 1; XGpioPs_IntrClearPin(GpioPtr, GPIO_TOUCH_INT);
    }
    if (XGpioPs_IntrGetStatusPin(GpioPtr, GPIO_BTN_0)) {
        XGpioPs_IntrClearPin(GpioPtr, GPIO_BTN_0);
        if (XGpioPs_ReadPin(GpioPtr, GPIO_BTN_0)) { LCD_ClearB = 1; XGpioPs_IntrDisablePin(GpioPtr, GPIO_BTN_0); }
    }
    if (XGpioPs_IntrGetStatusPin(GpioPtr, GPIO_BTN_1)) {
        XGpioPs_IntrClearPin(GpioPtr, GPIO_BTN_1);
        if (XGpioPs_ReadPin(GpioPtr, GPIO_BTN_1)) { Print_CNN = 1; XGpioPs_IntrDisablePin(GpioPtr, GPIO_BTN_1); }
    }
}

// =============================================================
// [함수] CNN Logic
// =============================================================
void Convert_Canvas_To_Buffer() {
	xil_printf("Converting Canvas to 28x28 Buffer...\r\n");

	// 버퍼 초기화
	memset(cnn_input_buffer, 0, 784);

	for (int i = 0; i < 28; i++) {
		for (int j = 0; j < 28; j++) {
			// 다운샘플링 영역 계산
			int start_y = (i * 320) / 28;
			int end_y = ((i + 1) * 320) / 28;
			int start_x = (j * 240) / 28;
			int end_x = ((j + 1) * 240) / 28;

			u8 pixel_val = 0;

			// 해당 영역에 점이 하나라도 있으면 127~255 값 부여
			for (int y = start_y; y < end_y; y++) {
				for (int x = start_x; x < end_x; x++) {
					if (y < 320 && x < 240) {
						if (my_canvas[y][x] == 255) {
							pixel_val = 127; // CNN 학습 데이터 값에 맞춰 조정 (보통 0~255)
							break;
						}
					}
				}
				if (pixel_val > 0)
					break;
			}
			// 변환된 값을 버퍼에 저장 (행 우선: row * 28 + col)
			cnn_input_buffer[i * 28 + j] = pixel_val;
		}
	}
}

int Send_Data_To_CNN() {
    Xil_DCacheFlushRange((UINTPTR) cnn_input_buffer, 784);
    if(XAxiDma_SimpleTransfer(&AxiDma, (UINTPTR) cnn_input_buffer, 784, XAXIDMA_DMA_TO_DEVICE) != XST_SUCCESS) return XST_FAILURE;
    int timeout = 0;
    while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) { timeout++; if (timeout > 1000000) return XST_FAILURE; }
    return XST_SUCCESS;
}

void Print_Data_For_AI(int label) {
    xil_printf("--- DATA START ---\r\n");
    for (int i = 0; i < 784; i++) {
        xil_printf("%3d ", cnn_input_buffer[i]);
        if ((i + 1) % 28 == 0) xil_printf("\r\n");
    }
    xil_printf("--- DATA END ---\r\n");
}

// =============================================================
// [핵심] 하드웨어 초기화 (순서 수정됨: LCD -> FPGA)
// =============================================================
int Hardware_Init() {
    int Status; // <--- 여기서 이미 선언했음!

    // ============================================================
    // 1. PS Peripherals (GPIO, SPI, I2C) - 안전한 초기화
    // ============================================================
    XGpioPs_Config *G = XGpioPs_LookupConfig(PS_GPIO_ID);
    XGpioPs_CfgInitialize(&Gpio, G, G->BaseAddr);
    XGpioPs_SetDirectionPin(&Gpio, GPIO_TOUCH_RST, 1); XGpioPs_SetOutputEnablePin(&Gpio, GPIO_TOUCH_RST, 1);
    XGpioPs_SetDirectionPin(&Gpio, GPIO_TOUCH_INT, 0);
    XGpioPs_SetDirectionPin(&Gpio, GPIO_LCD_DC, 1); XGpioPs_SetOutputEnablePin(&Gpio, GPIO_LCD_DC, 1);
    XGpioPs_SetDirectionPin(&Gpio, GPIO_LCD_RST, 1); XGpioPs_SetOutputEnablePin(&Gpio, GPIO_LCD_RST, 1);
    XGpioPs_SetDirectionPin(&Gpio, GPIO_BTN_0, 0); XGpioPs_SetDirectionPin(&Gpio, GPIO_BTN_1, 0);

    XSpiPs_Config *S = XSpiPs_LookupConfig(PS_SPI_ID);
    XSpiPs_CfgInitialize(&SpiLcd, S, S->BaseAddress);
    XSpiPs_SetOptions(&SpiLcd, XSPIPS_MASTER_OPTION | XSPIPS_FORCE_SSELECT_OPTION);
    XSpiPs_SetClkPrescaler(&SpiLcd, XSPIPS_CLK_PRESCALE_8);
    XSpiPs_SetSlaveSelect(&SpiLcd, 0);

    XIicPs_Config *I = XIicPs_LookupConfig(PS_IIC_ID);
    XIicPs_CfgInitialize(&Iic, I, I->BaseAddress);
    XIicPs_SetSClk(&Iic, 100000);

    // ============================================================
    // [Step 1] LCD부터 켭니다 (흰 화면 나오게)
    // ============================================================
    xil_printf("1. Turning ON LCD...\r\n");
    XGpioPs_WritePin(&Gpio, GPIO_LCD_RST, 0); usleep(50000);
    XGpioPs_WritePin(&Gpio, GPIO_LCD_RST, 1); usleep(150000);
    LCD_Write_Command(0x11); usleep(120000);
    LCD_Write_Command(0x36); LCD_Write_Data(0x48);
    LCD_Write_Command(0x3A); LCD_Write_Data(0x55);
    LCD_Write_Command(0x29);
    XGpioPs_WritePin(&Gpio, GPIO_TOUCH_RST, 0); usleep(20000);
    XGpioPs_WritePin(&Gpio, GPIO_TOUCH_RST, 1); usleep(200000);

    LCD_Clear(WHITE);
    xil_printf("   - LCD ON Success.\r\n");

    // ============================================================
    // [Step 2] FPGA IP 초기화 (위험 구간)
    // ============================================================
    xil_printf("2. Initializing FPGA IPs...\r\n");

    // [2-1] AXI GPIO (CNN Control)
    Status = XGpio_Initialize(&CnnCtrl, AXI_GPIO_ID);
    if (Status != XST_SUCCESS) {
        xil_printf("   !!! ERROR: AXI GPIO Init Failed.\r\n");
    } else {
        XGpio_SetDataDirection(&CnnCtrl, 1, 0x0);
        XGpio_SetDataDirection(&CnnCtrl, 2, 0xFFFFFFFF);
    }

    Status = XGpio_Initialize(&TimeCtrl, AXI_TIME_GPIO_ID);
	if (Status != XST_SUCCESS) {
		xil_printf(" !!! ERROR: Time GPIO Init Failed.\r\n");
	} else {
		XGpio_SetDataDirection(&TimeCtrl, 1, 0xFFFFFFFF); // Channel 1: final_time (Input)
	}

    // [2-2] Interrupts (수정됨: int 제거, 콜백 추가, NULL 체크)
    xil_printf("   [2-2] Checking Interrupts...\r\n");
    XScuGic_Config *Config = XScuGic_LookupConfig(INTC_DEVICE_ID);

    if (Config == NULL) {
        xil_printf("   !!! ERROR: GIC Config Not Found!\r\n");
        return XST_FAILURE;
    }

    // ★ 수정: int 제거 (Status 재사용)
    Status = XScuGic_CfgInitialize(&Intc, Config, Config->CpuBaseAddress);
    if (Status != XST_SUCCESS) {
        xil_printf("   !!! ERROR: GIC Init Failed.\r\n");
        return XST_FAILURE;
    }

    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler) XScuGic_InterruptHandler, &Intc);
    Xil_ExceptionEnable();

    Status = XScuGic_Connect(&Intc, GPIO_INTR_ID, (Xil_ExceptionHandler) XGpioPs_IntrHandler, &Gpio);
    if (Status != XST_SUCCESS) {
        xil_printf("   !!! ERROR: GPIO Interrupt Connect Failed.\r\n");
        return XST_FAILURE;
    }

    XGpioPs_SetIntrTypePin(&Gpio, GPIO_TOUCH_INT, XGPIOPS_IRQ_TYPE_LEVEL_LOW);
    XGpioPs_SetIntrTypePin(&Gpio, GPIO_BTN_0, XGPIOPS_IRQ_TYPE_LEVEL_HIGH);
    XGpioPs_SetIntrTypePin(&Gpio, GPIO_BTN_1, XGPIOPS_IRQ_TYPE_LEVEL_HIGH);

    // ★★★ 핵심: 콜백 핸들러 등록 (이거 없으면 터치 안됨) ★★★
    XGpioPs_SetCallbackHandler(&Gpio, (void *)&Gpio, (XGpioPs_Handler)GpioIntrHandler);

    XGpioPs_IntrEnablePin(&Gpio, GPIO_TOUCH_INT);
    XGpioPs_IntrEnablePin(&Gpio, GPIO_BTN_0);
    XGpioPs_IntrEnablePin(&Gpio, GPIO_BTN_1);

    XScuGic_Enable(&Intc, GPIO_INTR_ID);
    xil_printf("   - Interrupts OK.\r\n");

    // [2-3] CNN DMA
    if (Init_CNN_DMA() != XST_SUCCESS) {
        xil_printf("   !!! ERROR: CNN DMA Init Failed\r\n");
    }

    // [2-4] Monitor VDMA
    if (Init_VDMA() != XST_SUCCESS) {
        xil_printf("   !!! WARNING: Monitor VDMA Init Failed\r\n");
    } else {
        Clear_Monitor();
    }

    return XST_SUCCESS;
}
// =============================================================
// MAIN FUNCTION
// =============================================================
int main() {
    init_platform();
    xil_printf("===========================\r\n");
    xil_printf("   AI DRAWING SYSTEM v2.0  \r\n");
    xil_printf("===========================\r\n");

    if (Hardware_Init() != XST_SUCCESS) {
        xil_printf("Hardware Init Failed (Critical)\r\n");
        return -1;
    }
    xil_printf("System Ready. Draw -> BTN1\r\n");

    while (1) {
        // [작업 A] 화면 지우기 (BTN 0)
        if (LCD_ClearB) {
            LCD_Clear(WHITE);
            g_last_x = -1; g_last_y = -1;
            XGpio_DiscreteWrite(&CnnCtrl, 1, 0);
            while (XGpioPs_ReadPin(&Gpio, GPIO_BTN_0) == 1) Process_Touch();
            usleep(50000);
            LCD_ClearB = 0;
            XGpioPs_IntrEnablePin(&Gpio, GPIO_BTN_0);
        }

        // [작업 B] CNN 추론 & 모니터 (BTN 1)
        if (Print_CNN) {
            xil_printf("\r\n--- Inference ---\r\n");
            XGpio_DiscreteWrite(&CnnCtrl, 1, 0); usleep(100);
            Convert_Canvas_To_Buffer();

            if (Send_Data_To_CNN() == XST_SUCCESS) {
                Print_Data_For_AI(999);
                XGpio_DiscreteWrite(&CnnCtrl, 1, 1);

                u32 val;
                int timeout = 0;
                u32 cycle_count;

                while (1) {
                    val = XGpio_DiscreteRead(&CnnCtrl, 2);
                    if ((val & 0x01) == 1) break;
                    timeout++; if (timeout > 10000000) { xil_printf("Timeout!\r\n"); break; }
                }
                int pred = (val >> 1) & 0x0F;
                xil_printf("RESULT: %d\r\n", pred);

                cycle_count = XGpio_DiscreteRead(&TimeCtrl, 1);
                xil_printf("TIME  : %u cycles\r\n", cycle_count);

                // ★ 결과가 나오면 모니터 화면 업데이트 ★
                Update_Monitor_Image(pred);
            } else {
                xil_printf("DMA Error (Check Bitstream)\r\n");
            }

            while (XGpioPs_ReadPin(&Gpio, GPIO_BTN_1) == 1) Process_Touch();
            usleep(50000);
            Print_CNN = 0;
            XGpioPs_IntrEnablePin(&Gpio, GPIO_BTN_1);
        }

        // [작업 C] 평상시 터치
        Process_Touch();
    }
    cleanup_platform();
    return 0;
}
