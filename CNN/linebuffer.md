# CNN Verilog

## Buffer

```verilog
// buf_flag == 0 일 때
if(buf_flag == 3'd0) begin
  data_out_0 <= buffer[w_idx];              // buffer[0]
  data_out_1 <= buffer[w_idx + 1];          // buffer[1]
  data_out_2 <= buffer[w_idx + 2];          // buffer[2]
  data_out_3 <= buffer[w_idx + 3];          // buffer[3]
  data_out_4 <= buffer[w_idx + 4];          // buffer[4]

  data_out_5 <= buffer[w_idx + WIDTH];      // buffer[28]
  data_out_6 <= buffer[w_idx + 1 + WIDTH];  // buffer[29]
  ...
  
  data_out_20 <= buffer[w_idx + WIDTH * 4];  // buffer[112]
  data_out_21 <= buffer[w_idx + 1 + WIDTH * 4]; // buffer[113]
  ...
  data_out_24 <= buffer[w_idx + 4 + WIDTH * 4]; // buffer[116]
end
```

buf_flag=0일 때 (w_idx=0 기준):

data_out_0부터4 = buffer[0부터4] → 데이터 0,1,2,3,4 (Row 0)
data_out_5부터9 = buffer[28부터32] → 데이터 28,29,30,31,32 (Row 1)
data_out_10부터14 = buffer[56부터60] → Row 2
data_out_15부터19 = buffer[84부터88] → Row 3
data_out_20부터24 = buffer[112부터116] → Row 4

```verilog
// buf_flag == 1 일 때
else if(buf_flag == 3'd1) begin
  data_out_0 <= buffer[w_idx + WIDTH];           // buffer[28]
  data_out_1 <= buffer[w_idx + 1 + WIDTH];       // buffer[29]
  ...
  data_out_4 <= buffer[w_idx + 4 + WIDTH];       // buffer[32]

  data_out_5 <= buffer[w_idx + WIDTH * 2];       // buffer[56]
  ...

  data_out_15 <= buffer[w_idx + WIDTH * 4];      // buffer[112]
  ...

  data_out_20 <= buffer[w_idx];                  // buffer[0]
  data_out_21 <= buffer[w_idx + 1];              // buffer[1]
  ...
  data_out_24 <= buffer[w_idx + 4];              // buffer[4]
end
```

buf_flag=1일 때 (w_idx=0 기준):

data_out_0부터4 = buffer[28부터32] → 데이터 28,29,30,31,32 (Row 1)
data_out_5부터9 = buffer[56부터60] → Row 2
data_out_10부터14 = buffer[84부터88] → Row 3
data_out_15부터19 = buffer[112부터116] → Row 4
data_out_20부터24 = buffer[0부터4] → 데이터 140,141,142,143,144 (Row 5) ⭐


buf_flag=1일 때는 data_out_20부터24가 buffer[w_idx]부터 시작합니다
이 시점에 buffer[0부터27]에는 데이터 140부터167 (Row 5)이 들어있으니까,
data_out_20부터24는 140,141,142,143,144를 출력하게 됩니다.
즉, 코드에서 buf_flag에 따라 출력 포트 매핑이 회전하는 게 구현되어 있습니다

---

<img width="1137" height="775" alt="image" src="https://github.com/user-attachments/assets/269cef70-8bf7-4749-a5fe-aa1230df20db" />

<img width="1312" height="699" alt="image" src="https://github.com/user-attachments/assets/9c11f414-85b4-4b57-9458-4fa1c8b56772" />

---
#### w_idx , h_idx

1. 동작:
  초기값: h_idx = 0 (Row 0부터 시작)
  증가 조건: w_idx가 한 줄 끝(WIDTH-1 = 27)에 도달할 때마다 h_idx가 1씩 증가
  w_idx = 0~27 스캔 완료 → h_idx++
  즉, 한 row를 다 스캔하면 다음 row로 이동

> 종료 조건: h_idx == HEIGHT - FILTER_SIZE (= 28 - 5 = 23)

왜 23? → 5x5 윈도우를 만들려면 Row 23부터 Row 27까지 5줄이 필요
Row 0~4: 첫 윈도우
Row 1~5: 두 번째 윈도우

Row 23~27: 마지막 윈도우 (총 24개 윈도우)

2. h_idx == 23에 도달하면:

28x28 이미지 전체 스캔 완료
state를 0으로 되돌림 (다음 이미지 대기)

w_idx: 가로(width) 방향 인덱스 (0~27 반복)
h_idx: 세로(height) 방향 인덱스 (0~23, 현재 몇 번째 row 스캔 중인지)
buf_flag: 버퍼 내에서 어느 위치가 첫 번째 row인지 (0~4 순환)

---

<img width="970" height="414" alt="image" src="https://github.com/user-attachments/assets/5c34406d-514c-4cca-9f2a-13ba336a731c" />


<img width="981" height="423" alt="image" src="https://github.com/user-attachments/assets/96919d94-9356-4d12-9315-173aba4f019c" />

- w_idx 가 1~25 까지 25개 출력 26 때 valid_out_buf = 0 으로 사용불가
- h_dix 가 23까지 하고 0으로 초기화 buf 139에 맞춰 멈춰야되지만 110에 멈춤 => 제대로된 이미지를 처리할수없음

---

# line buffer 구현

#### 보드 구현 문제를 해결하기 위해서 line buffer 구현

<img width="1439" height="269" alt="image" src="https://github.com/user-attachments/assets/d56b7b38-df56-4bbd-a8d9-7653794163a6" />

