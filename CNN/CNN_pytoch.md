# CNN pytoch
```python
# Training MNIST DataSet using CNN

import torch
import torchvision.datasets as dsets
import torchvision.transforms as transforms
import torch.nn.init

# device set - CPU/GPU
device = 'cuda' if torch.cuda.is_available() else 'cpu'

torch.manual_seed(777)

if device == 'cuda':
  torch.cuda.manual_seed_all(777)
  print('Device is set to GPU')
else:
  print('Device is set to CPU')

# Parameter Setting
learning_rate = 0.001
training_epochs = 15
batch_size = 100

# DataSet Definition
mnist_train = dsets.MNIST(root='MNIST_data/', train=True, transform=transforms.ToTensor(), download=True)
mnist_test = dsets.MNIST(root='MNIST_data/', train=False, transform=transforms.ToTensor(), download=True)

# Batch Size
data_loader = torch.utils.data.DataLoader(dataset=mnist_train, batch_size=batch_size, shuffle=True, drop_last=True)

class CNN(torch.nn.Module):
    def __init__(self):
        super(CNN, self).__init__()
        # 1st Layer
        # Image Input Shape -> (?, 28, 28, 1)
        # Convolution Layer -> (?, 28, 28, 32)
        # PoolingMax Layer -> (?, 14, 14, 32)
        self.layer1 = torch.nn.Sequential(
            torch.nn.Conv2d(1, 32, kernel_size=3, stride=1, padding=1),
            torch.nn.ReLU(),
            torch.nn.MaxPool2d(kernel_size=2, stride=2))

        # 2nd Layer
        # Image Input Shape = (?, 14, 14, 32)
        # Convolution Layer -> (?, 14, 14, 64)
        # PoolingMax Layer -> (?, 7, 7, 64)
        self.layer2 = torch.nn.Sequential(
            torch.nn.Conv2d(32, 64, kernel_size=3, stride=1, padding=1),
            torch.nn.ReLU(),
            torch.nn.MaxPool2d(kernel_size=2, stride=2))

        # Fully Connected Layer
        # 7x7x64 inputs -> 10 outputs
        self.fc = torch.nn.Linear(7 * 7 * 64, 10, bias=True)

        # reset weight
        torch.nn.init.xavier_uniform_(self.fc.weight)

    def forward(self, x):
        out = self.layer1(x)
        out = self.layer2(out)
        out = out.view(out.size(0), -1) # Flatten
        out = self.fc(out)
        return out

# CNN Model
model = CNN().to(device)

print(model)
from torchsummary import summary
summary(model, input_size=(1,28,28))


while True: ...

criterion = torch.nn.CrossEntropyLoss().to(device)
optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)

total_batch = len(data_loader)
print('Total Batch : {}'.format(total_batch))

# Training
for epoch in range(training_epochs):
    avg_cost = 0

    for X, Y in data_loader:
        # X : mini Batch, Y : lable
        # image is already size of (28x28), no reshape
        # label is not one-hot encoded
        X = X.to(device)
        Y = Y.to(device)

        optimizer.zero_grad() # wE, bE = 0 
        hypothesis = model(X) # 1공식
        cost = criterion(hypothesis, Y) # 2공식
        cost.backward() # 3+6(역전파) 공식
        optimizer.step() # 7공식 w = w-lr*wE, b= b-lr=bE

        avg_cost += cost / total_batch

    print('[Epoch: {:>4}] cost = {:>.9}'.format(epoch + 1, avg_cost))

# Test
with torch.no_grad():
#     X_test = mnist_test.test_data.view(len(mnist_test), 1, 28, 28).float().to(device)
#     Y_test = mnist_test.test_labels.to(device)
    
    X_test = mnist_test.data.view(len(mnist_test), 1, 28, 28).float().to(device)
    Y_test = mnist_test.targets.to(device)

    prediction = model(X_test)
    correct_prediction = torch.argmax(prediction, 1) == Y_test
    accuracy = correct_prediction.float().mean()
    print('Accuracy:', accuracy.item())

```
<img width="415" height="370" alt="image" src="https://github.com/user-attachments/assets/ba793111-2355-459a-965b-ece06ee1747f" />


- model 정보를 확인 하는 함수 
```python
print(model)
from torchsummary import summary
summary(model, input_size=(1,28,28))

while True: ... # 나중에 작성하겠다
```
---

## project에 맞춘 CNN 구현

<img width="1300" height="607" alt="image" src="https://github.com/user-attachments/assets/ceddecc3-fb07-4302-8829-8e3efa237f0f" />


<table>
  <tr>
    <td><img width="216" height="141" alt="image" src="https://github.com/user-attachments/assets/794dc435-9ac6-4171-81af-5d858b07b82e" /></td>
    <td><img width="621" height="63" alt="image" src="https://github.com/user-attachments/assets/7569ac35-ddd4-41c8-b513-2901d235009b" /></td>
  </tr>
</table>

---

## 양자화
```python

# Calibration
int_conv1_weight_1 =  torch.tensor((model.conv1.weight.data[0][0] * 128), dtype = torch.int32)  # 실수 -> 정수
int_conv1_weight_2 =  torch.tensor((model.conv1.weight.data[1][0] * 128), dtype = torch.int32)
int_conv1_weight_3 =  torch.tensor((model.conv1.weight.data[2][0] * 128), dtype = torch.int32)
int_conv1_bias = torch.tensor((model.conv1.bias.data * 128), dtype = torch.int32)
```

양자화란, 모델의 가중치나 중간 계산 값처럼 정밀한 실수(floating-point)를, 연산이 빠르고 메모리를 적게 차지하는 정수(integer)로 변환하는 과정을 말합니다.

1. `... * 128`: 스케일링(Scaling) 단계입니다.
   * 원래 가중치 값(예: 0.15 같은 작은 실수)을 정수로 만들기 위해 특정 값(여기서는 128)을 곱해 값을 뻥튀기합니다. (예: 0.15 * 128 = 19.2)
   * 이 128이라는 숫자를 스케일 팩터(Scale factor)라고 부릅니다.


2. `torch.tensor(..., dtype = torch.int32)`: 정수 변환(Casting) 단계입니다.
   * 뻥튀기된 값을 정수형(int32)으로 변환합니다. 이 과정에서 소수점 아래는 버려집니다. (예: 19.2 -> 19)

>결과적으로, 실수 0.15는 정수 19로 양자화되었습니다. 나중에 하드웨어에서 계산을 마친 뒤, 다시 128로 나누어주면
>원래의 실수 값과 비슷한 값으로 복원할 수 있습니다.

#### 양자화를 하는 이유? (특히 Verilog 구현 시)

 1. 하드웨어 구현의 용이성: Verilog로 실수를 계산하는 회로(Floating-Point Unit)를 만드는 것은 매우 복잡하고
    큽니다. 하지만 정수를 계산하는 덧셈기, 곱셈기는 훨씬 간단하게 만들 수 있습니다.
 2. 속도 및 효율성: 정수 연산은 실수 연산보다 훨씬 빠르고 전력 소모도 적습니다. NPU나 우리가 만들려는 FPGA
    기반 가속기는 대부분 내부적으로 정수 연산을 기반으로 동작합니다.

> 고정소수점(Fixed-point) 개념과 사실상 같습니다.
> 128 (즉, * 2^7)을 해주는 것은, 소수점 아래 7비트를 정수부로 끌어올리는 것과 같은 효과를 냅니다.
