clc;

% 定义表3中的数据
t = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18]; % 时间（秒）
s = [12.50, 18.52, 24.60, 30.50, 36.45, 42.55, 48.50, 54.60, 60.53, 66.58]; % 位移（米）

% 绘制数据点
figure;
plot(t, s, 'o', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
hold on;
grid on;
xlabel('时间 t (s)');
ylabel('位移 s (m)');
title('小车位移与时间的关系');

% 使用最小二乘法进行线性拟合
p = polyfit(t, s, 1);
v = p(1); % 速度是斜率
s0 = p(2); % 初始位置是截距

% 生成拟合线
t_fit = linspace(min(t), max(t), 100);
s_fit = v * t_fit + s0;

% 绘制拟合线
plot(t_fit, s_fit, 'r-', 'LineWidth', 2);

% 在图上显示结果
equation = sprintf('s = %.4f t + %.4f', v, s0);
velocity = sprintf('速度 v = %.4f m/s', v);
legend('实验数据', '线性拟合', 'Location', 'northwest');

% 添加方程和速度文本
text(max(t)*0.4, min(s)*1.1, equation, 'FontSize', 12);
text(max(t)*0.4, min(s)*1.2, velocity, 'FontSize', 12);

% 在命令窗口中显示结果
fprintf('线性拟合方程: s = %.4f t + %.4f\n', v, s0);
fprintf('小车的速度为: v = %.4f m/s\n', v);

% 计算R平方以评估拟合优度
s_mean = mean(s);
SS_total = sum((s - s_mean).^2);
SS_residual = sum((s - (v*t + s0)).^2);
R_squared = 1 - (SS_residual / SS_total);
fprintf('拟合优度 R² = %.6f\n', R_squared);