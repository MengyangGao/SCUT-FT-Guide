# 数字逻辑电路实验预习报告

## 一、实验目的

1. 掌握 VHDL 程序的基本结构及编写方法；
2. 掌握 Verilog 程序的基本结构及编写方法；
3. 掌握使用 QuartusII 软件对 VHDL 和 Verilog 程序进行编译的方法；
4. 掌握使用 ModelSim 编写 testbench 并进行仿真的基本流程。

## 二、预习内容

### 2.1 VHDL 基本语法结构

#### 实体结构（Entity）

```vhdl
entity and_gate is
    Port (
        A : in STD_LOGIC;
        B : in STD_LOGIC;
        Y : out STD_LOGIC
    );
end and_gate;
```

#### 架构结构（Architecture）

```vhdl
architecture Behavioral of and_gate is
begin
    Y <= A and B;
end Behavioral;
```

### 2.2 Verilog 基本语法结构

#### 模块结构（Module）

```verilog
module and_gate (
    input A,
    input B,
    output Y
);
assign Y = A & B;
endmodule
```

### 2.3 QuartusII 文本编辑器使用方法

- 打开 QuartusII，新建 VHDL 或 Verilog 文件；
- 输入代码并保存为 .vhd 或 .v 文件；
- 添加到工程中并设为顶层实体；
- 编译前进行语法检查；
- 点击“Start Compilation”开始编译。

## 三、实验器材

1. 计算机；
2. QuartusII 软件；
3. ModelSim 仿真工具。

## 四、实验内容与步骤

### 4.1 实验内容

- 针对指定逻辑电路题目，编写 VHDL 和 Verilog 程序；
- 在 QuartusII 上进行编译；
- 编写 testbench，在 ModelSim 中进行仿真，并记录仿真结果。

### 4.2 实验步骤

1. 在 QuartusII 中通过文本输入法输入 VHDL 程序；
2. 编译并观察生成的 RTL 图，