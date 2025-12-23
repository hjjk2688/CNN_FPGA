# SAVE

직접 적은 글씨를 인식못해서 새로운 모델 학습 noise 추




# 데이터 처리방식

<img width="887" height="459" alt="image" src="https://github.com/user-attachments/assets/c0d06e63-673b-4681-9520-f7fdc0905428" />

```python
# [순서 교정 로직] 
            # 가장 바깥쪽 루프가 'ch (채널)' 인 것이 핵심입니다!
            for ch in range(C):  # 1. 채널(재료)을 먼저 선택하고 (0->1->2)
                for r in range(H): # 2. 그 재료의 위아래를 훑고
                    for c in range(W): # 3. 좌우를 훑습니다.
                        
                        # 여기서 Keras(HWC)의 복잡한 주소를 계산해서 콕 집어 가져옵니다.
                        keras_idx = (r * W + c) * C + ch
                        val = w_fc[keras_idx, n]
```

---

 keras 형식으로 되어있음
---
for ch in range(C)가 제일 위에 있죠?

이게 바로 **"채널 0번(빨강) 다 끝내고 나서 채널 1번(초록)으로 넘어가라"**는 뜻입니다.

keras_idx = ... 부분:

FPGA 순서에 맞춰 돌면서, Keras 데이터 뭉치 속에서 필요한 값만 쏙쏙 뽑아오는 수식입니다.

🍎 결론
사용자님의 질문에 대한 답은 "네, Keras에 있는 가중치 값을 가져오되, 순서는 FPGA가 좋아하는 '채널 우선 순서'로 싹 바꿔서 맞췄습니다." 입니다.

이 순서대로 fully_connected.v에 들어가야 비로소 FPGA가 "아! 이게 6이구나" 하고 제대로 정답을 맞힙니다. 안심하고 돌리셔도 됩니다! 👍

----
# FPGA Fixed-Point Arithmetic & Scaling Logic
> **Subject:** Why Scale 127? & The Logic behind `>>> 7`  
> **Context:** 8-bit Integer Quantization for FPGA CNN  
> **Operation:** Fixed-Point Multiplication, Re-scaling, & Final Comparison

---

## 1. Why Scale Factor 127? (왜 하필 127인가?)

우리는 FPGA 리소스를 아끼기 위해 **`signed 8-bit integer` (int8)** 자료형을 사용합니다.

### A. int8의 표현 범위
* **비트 수:** 8 bit (1 Sign bit + 7 Data bits)
* **표현 범위:** `-128` ~ `+127`

### B. 정밀도 최대화 (Maximize Precision)
실수 `0.0` ~ `1.0` 사이의 값을 `int8`에 담을 때, 해상도를 가장 높이려면 **표현 가능한 가장 큰 수**를 곱해야 합니다.
* 만약 **Scale 10**을 쓴다면: `0.5` $\to$ `5` (나머지 비트 낭비)
* **Scale 127**을 쓴다면: `0.5` $\to$ `63.5` $\approx$ `64` (비트를 꽉 채워서 사용)

👉 **결론:** `int8` 양수 최대값인 **127**을 곱해야 **정보 손실을 최소화**하면서 가장 디테일한 값을 저장할 수 있습니다.

---

## 2. What is `>>> 7`? (7비트 시프트의 정체)

이 연산의 정확한 명칭은 **"리스케일링(Re-scaling)"**입니다. (역양자화 아님)

### A. 곱셈 시 스케일 폭발 (Scale Explosion)
고정 소수점 연산에서 곱셈을 하면 스케일(Scale)도 같이 곱해져서 커집니다.
* **입력 ($2^7$)** $\times$ **가중치 ($2^7$)** = **결과 ($2^{14}$)**

### B. 리스케일링 (Re-scaling)
커져버린 스케일($2^{14}$)을 다음 층이 원하는 입력 스케일($2^7$)로 되돌려야 합니다.
이를 위해 **$2^7(128)$로 나누는 과정**이 필요하며, 하드웨어 비용이 0에 가까운 **비트 시프트(`>>> 7`)**를 사용합니다.

---

## 3. Why NO De-quantization? (우리는 왜 역양자화가 필요 없는가?)

보통의 딥러닝 추론 과정에서는 마지막에 `int`를 다시 `float`로 바꾸는 **역양자화(De-quantization)**를 합니다. 하지만 우리는 이 과정이 **전혀 필요 없습니다.**

### A. 우리의 목적: "누가 1등인가?" (Argmax)
우리의 목표는 이미지가 '4'인지 '5'인지 분류하는 것입니다. 즉, 출력값 10개 중 **가장 큰 값을 가진 인덱스(Index)**만 찾으면 됩니다.

### B. 대소 관계의 보존 (Preservation of Order)
양자화된 정수 값들은 실수 값에 단순히 상수($127$)를 곱한 것입니다. 곱셈은 숫자의 **크기 순서(대소 관계)를 바꾸지 않습니다.**

* **실수(Float):** $P(4) = 0.8$, $P(5) = 0.2$ $\rightarrow$ **4가 큼**
* **정수(Int):** $Score(4) = 101$, $Score(5) = 25$ $\rightarrow$ **여전히 4가 큼**

### C. 결론
우리는 **"비교(Comparison)"**만 하면 되기 때문에, 굳이 자원을 써가며 무거운 실수(Float)로 되돌릴 필요가 없습니다. 정수 상태 그대로 비교해도 **결과는 100% 동일**합니다.

> **Summary:** > "Original floating-point values are NOT needed because the **relative order** of scores remains unchanged in the quantized domain. We only need the **Argmax** index."

---

# FPGA CNN Memory Structure & Weight Arrangement
> **Project:** Handwritten Digit Recognition (Zybo Z7-20)  
> **Input:** 28x28 (Grayscale)  
> **Framework:** TensorFlow/Keras (HWC) $\to$ Verilog ROM (Custom Optimized)

---

## 1. 기본 개념 정리 (Terminology)

### A. 데이터 포맷: HWC
Keras와 Python에서 이미지를 다루는 기본 순서입니다.
* **H (Height):** 세로 (Row, 행)
* **W (Width):** 가로 (Col, 열)
* **C (Channel):** 깊이 (In/Out)

### B. 채널의 흐름: In vs Out
샌드위치 두께(Layer)가 어떻게 변하는지를 나타냅니다.
* **In (Input Channel):** 현재 층으로 **들어오는** 데이터의 두께 (재료의 겹 수).
* **Out (Output Channel):** 필터를 거쳐서 **나가는** 데이터의 두께 (만들어진 특징 맵 수).

---

## 2. 계층별 구조 및 변환 로직 (Layer Specification)

### 🟢 1. Conv1 Layer (입력단)
* **구조:** 입력 채널 1개(흑백) $\rightarrow$ 출력 채널 3개
* **데이터 흐름:** 28x28x1 $\rightarrow$ 24x24x3

| 구분 | 형태 (Shape) | 순서 의미 |
| :--- | :--- | :--- |
| **Keras 원본** | `(5, 5, 1, 3)` | (Row, Col, In, Out) |
| **Python 변환** | `.transpose(3, 0, 1, 2)` | **(Out, Row, Col, In)** |
| **FPGA 타겟** | `function get_w1~3` | 필터별(Out)로 함수 분리 |

> **✅ 검증 (Verification)**
> * **로직:** Out 루프가 가장 바깥에 있음 $\rightarrow$ 필터 1, 2, 3 순서로 값 추출.
> * **하드웨어:** FPGA는 `conv1_calc.v` 모듈 하나에서 필터 3개 값을 다 쓰거나, 루프를 돌며 처리함.
> * **결과:** **정확함.**

---

### 🟡 2. Conv2 Layer (핵심 연산)
* **구조:** 입력 채널 3개 $\rightarrow$ 출력 채널 3개
* **데이터 흐름:** 12x12x3 $\rightarrow$ 8x8x3
* **특이사항:** **가장 복잡한 부분.** HWC 구조를 FPGA 병렬 처리에 맞게 뒤집음.

| 구분 | 형태 (Shape) | 순서 의미 |
| :--- | :--- | :--- |
| **Keras 원본** | `(5, 5, 3, 3)` | (Row, Col, In, Out) |
| **Python 변환** | `.transpose(3, 2, 0, 1)` | **(Out, In, Row, Col)** |
| **FPGA 타겟** | `conv2_calc_1~3.v` | 출력(Out)별 모듈 분리 / 내부에서 입력(In)별 함수 호출 |

> **✅ 검증 (Verification)**
> * **파일 생성 순서 (Loop):**
>     1.  `for out_ch (Out)`: `conv2_calc_X.v` 파일 영역 나눔 (출력 필터별).
>     2.  `for in_ch (In)`: `function get_w1`, `get_w2`... (입력 채널별 함수 생성).
>     3.  `for r, c (Row, Col)`: 5x5 픽셀 가중치 채움.
> * **하드웨어 로직:** FPGA는 Conv2 모듈 내부에서 **입력 채널 3개(In=3)를 동시에 읽어서 더하는 구조 (Parallel Adder Tree)**임. 따라서 입력 채널별 함수(`get_wX`)가 각각 존재해야 함.
> * **결과:** **FPGA 하드웨어 구조와 완벽하게 일치함.**

---

### 🔴 3. Fully Connected (FC) Layer (출력단)
* **구조:** 입력 48개 (4x4x3 Flatten) $\rightarrow$ 출력 10개 (숫자 0~9)
* **데이터 흐름:** 48 $\rightarrow$ 10

| 구분 | 형태 (Shape) | 순서 의미 |
| :--- | :--- | :--- |
| **Keras 원본** | `(48, 10)` | (Input_HWC, Neuron) |
| **Python 변환** | `.transpose(1, 0)` | **(Neuron, Input_HWC)** |
| **FPGA 타겟** | `function get_weight` | 뉴런별(0~9)로 입력 48개를 순차적으로 읽음 |

> **✅ 검증 (Verification)**
> * **파일 생성 순서:**
>     1.  `for n (Neuron 0~9)`: 뉴런 0번부터 9번까지 순서대로 블록 생성.
>     2.  `for k (Input 0~47)`: 각 뉴런이 곱해야 할 입력 48개의 가중치를 나열.
> * **하드웨어 로직:** 각 뉴런 모듈은 들어오는 48개 입력 신호와 자신의 가중치를 **순서대로(Serial) 곱해서 누적(Accumulate)**함.
> * **결과:** `transpose(1, 0)`이 뉴런 기준(Row-Major)으로 데이터를 정렬해주므로 **정확함.**

---

## 3. 최종 요약 (Summary)

1.  **입력 이미지:** `image_rom.v`는 **HWC** 순서 그대로 저장 (채널 1개라 HW 순서).
2.  **가중치 (Weights):** FPGA의 메모리 접근 효율성을 위해 **Python 전처리 단계에서 순서를 변환함.**
    * Conv2: `(Out, In, H, W)`
    * FC: `(Out, In)` == `(Neuron, Input)`
3.  **양자화 (Quantization):** 모든 가중치와 입력은 **Scale 127** (int8)로 변환되어 저장됨.
---
## 학습 방법 변경

네, **"중앙 지점을 움직였다"**는 표현이 아주 정확합니다! 🎯

전문 용어로는 데이터 증강(Data Augmentation) 중에서도 "평행 이동(Translation / Shift)" 기법이라고 부르는데, 원리를 아주 쉽게 설명해 드릴게요.

1. 원리: "도화지는 그대로, 그림만 스윽 밀기"
우리가 사용하는 **28x28 크기의 도화지(캔버스)**는 고정되어 있습니다. 이 안에서 숫자만 손으로 잡고 왼쪽, 오른쪽, 위, 아래로 '스윽' 미는 것이 바로 "흔들었다"는 뜻입니다.

원본: 숫자가 도화지 정중앙에 예쁘게 있습니다.

흔들기 (Shift): 숫자를 왼쪽으로 3칸, 혹은 위로 2칸 밀어버립니다.

밀려서 빈 공간은 검은색(0)으로 채워집니다.

도화지 밖으로 나간 부분은 잘립니다.

결국 사용자님 말씀대로, 숫자의 "중심점(Center of Mass)"이 도화지의 중앙에서 벗어나게 만드는 것입니다.

2. 왜 이렇게 하나요? (AI 참교육)
기존의 AI는 **"온실 속의 화초"**였습니다.

AI의 생각: "아, 정답(숫자)은 항상 화면 가운데에 있구나! 난 가운데 픽셀만 열심히 봐야지!" (게으른 학습)

결과: 사용자님이 숫자를 구석에 그리면, AI는 "어? 가운데가 텅 비었네? 이건 아무것도 아니거나 1인가?" 하고 멍청해집니다.

그래서 데이터를 흔들어서 **"야생 훈련"**을 시키는 겁니다.

훈련: 6을 왼쪽 구석에도 보여주고, 오른쪽 위에도 보여줍니다.

AI의 깨달음: "아! 숫자가 어디에 있든 상관없구나. 위치가 중요한 게 아니라 '동그라미가 밑에 달린 모양(6)' 그 자체가 중요한 거구나!"

3. 코드에서의 의미 (width_shift_range=0.15)
아까 코드에 넣은 이 부분이 바로 그 명령입니다.

```python
datagen = ImageDataGenerator(
    width_shift_range=0.15,  # 가로로 전체 크기의 15%(약 4픽셀)만큼 왔다 갔다 해라
    height_shift_range=0.15  # 세로로 15%만큼 왔다 갔다 해라
)
```

이 코드가 돌아가면, AI는 가만히 있는 6 하나만 보는 게 아니라, **춤추듯이 상하좌우로 움직이는 수천 가지 버전의 6**을 보게 됩니다.

결론: 사용자님이 말씀하신 대로 **"숫자의 중심을 강제로 이동시켜서, AI가 위치에 집착하지 않게 만드는 원리"**가 맞습니다! 아주 정확하게 이해하셨습니다. 👍

---

```python
Epoch 1/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.5770 - loss: 1.2456 - val_accuracy: 0.8725 - val_loss: 0.4410
Epoch 2/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.7656 - loss: 0.7526 - val_accuracy: 0.8939 - val_loss: 0.3500
Epoch 3/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.7968 - loss: 0.6583 - val_accuracy: 0.9062 - val_loss: 0.3183
Epoch 4/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8147 - loss: 0.5941 - val_accuracy: 0.9089 - val_loss: 0.3141
Epoch 5/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8240 - loss: 0.5736 - val_accuracy: 0.9148 - val_loss: 0.2883
Epoch 6/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8344 - loss: 0.5455 - val_accuracy: 0.9235 - val_loss: 0.2563
Epoch 7/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8401 - loss: 0.5239 - val_accuracy: 0.9234 - val_loss: 0.2536
Epoch 8/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8461 - loss: 0.5032 - val_accuracy: 0.9152 - val_loss: 0.2726
Epoch 9/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8469 - loss: 0.5013 - val_accuracy: 0.9188 - val_loss: 0.2677
Epoch 10/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8496 - loss: 0.4922 - val_accuracy: 0.9246 - val_loss: 0.2457
Epoch 11/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8529 - loss: 0.4854 - val_accuracy: 0.9271 - val_loss: 0.2410
Epoch 12/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8559 - loss: 0.4774 - val_accuracy: 0.9278 - val_loss: 0.2389
Epoch 13/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8575 - loss: 0.4679 - val_accuracy: 0.9143 - val_loss: 0.2740
Epoch 14/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8584 - loss: 0.4672 - val_accuracy: 0.9264 - val_loss: 0.2433
Epoch 15/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8587 - loss: 0.4621 - val_accuracy: 0.9319 - val_loss: 0.2230
Epoch 16/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8604 - loss: 0.4586 - val_accuracy: 0.9302 - val_loss: 0.2265
Epoch 17/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 7ms/step - accuracy: 0.8625 - loss: 0.4550 - val_accuracy: 0.9311 - val_loss: 0.2221
Epoch 18/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 14s 7ms/step - accuracy: 0.8622 - loss: 0.4523 - val_accuracy: 0.9294 - val_loss: 0.2245
Epoch 19/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 14s 8ms/step - accuracy: 0.8657 - loss: 0.4444 - val_accuracy: 0.9303 - val_loss: 0.2200
Epoch 20/20
1875/1875 ━━━━━━━━━━━━━━━━━━━━ 12s 6ms/step - accuracy: 0.8654 - loss: 0.4436 - val_accuracy: 0.9318 - val_loss: 0.2218
```

<img width="1372" height="741" alt="image" src="https://github.com/user-attachments/assets/fae35905-ad04-42f4-a377-11f1c0d0a46f" />

