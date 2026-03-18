clc;

% 金属丝长度与温度关系的分析与拟合

% 数据输入
T = [23.3, 32.0, 41.0, 53.0, 62.0, 71.0, 87.0, 99.0]; % 温度数据 (°C)
L = [71.0, 73.0, 75.0, 78.0, 80.0, 82.0, 86.0, 89.1]; % 长度数据 (mm)

% 绘制原始数据散点图
figure;
plot(T, L, 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
hold on;
grid on;
xlabel('温度 T (°C)');
ylabel('长度 L_T (mm)');
title('金属丝长度与温度的关系');

% 使用最小二乘法进行线性拟合
p = polyfit(T, L, 1); % 一次多项式拟合
a = p(1); % 斜率
b = p(2); % 截距

% 计算拟合线
T_fit = linspace(min(T), max(T), 100);
L_fit = a * T_fit + b;

% 绘制拟合线
plot(T_fit, L_fit, 'r-', 'LineWidth', 2);
legend('实验数据', '拟合曲线');

% 计算 L0 和 α
L0 = b;
alpha = a / L0;

% 计算相关系数 R
R = corrcoef(T, L);
R = R(1, 2);

% 显示结果
fprintf('拟合方程: L_T = %.4f + %.4f * T\n', b, a);
fprintf('即: L_T = %.4f * (1 + %.6f * T)\n', L0, alpha);
fprintf('L0 = %.4f mm\n', L0);
fprintf('α = %.6f /°C\n', alpha);
fprintf('相关系数 R = %.4f\n', R);