clear; clc; close all;

%% Raw Data
x_hyst = [ 2.08,  0.72,  0.00, -0.48, -0.64, -0.88, -2.08, -0.64, ...
           0.00,  0.32,  0.56,  0.80,  2.08]; % V
y_hyst = [ 0.288, 0.232, 0.176, 0.080, 0.000, -0.112, -0.272, -0.208, ...
          -0.144, -0.080, 0.000,  0.128, 0.288]; % V

% 平滑模板回线 pchip
t  = 1:numel(x_hyst);
tt = linspace(1, numel(x_hyst), 600);
x_hyst_s = pchip(t, x_hyst, tt);
y_hyst_s = pchip(t, y_hyst, tt);

% a 点
x_a = 2.08;   % V
y_a = 0.288;  % V

%% 基本磁化曲线（10 点）
x_mag = [1.50, 1.22, 1.03, 0.86, 0.72, 0.62, 0.52, 0.44, 0.36, 0.24]; % V
y_mag = [0.250, 0.228, 0.206, 0.184, 0.152, 0.132, 0.104, 0.080, 0.056, 0.028]; % V

xx = linspace(min(x_mag), max(x_mag), 400);
yy = pchip(x_mag, y_mag, xx);

%% 磁滞回线（平滑）
figure('Color','w');
plot(x_hyst_s, y_hyst_s, 'r-', 'LineWidth', 2); hold on;
plot(x_hyst,   y_hyst,   'ko', 'MarkerFaceColor','k', 'MarkerSize',5);
grid on;
xlabel('u_H (V)'); ylabel('u_B (V)');
title('磁滞回线（平滑）');
legend('平滑磁滞回线','实验测点','Location','best');

%% 基本磁化曲线 + 各采样点的小磁滞回线
figure('Color','w');
plot(xx, yy, 'b-', 'LineWidth', 2); hold on;
plot(x_mag, y_mag, 'ks', 'MarkerFaceColor','k', 'MarkerSize',5);

alphaVal = 0.6; lw = 1.2;
for i = 1:numel(x_mag)
    scale_x = x_mag(i) / x_a;
    scale_y = y_mag(i) / y_a;

    xs = scale_x * x_hyst_s;  
    ys = scale_y * y_hyst_s;

    p = plot(xs, ys, 'r--', 'LineWidth', lw);
    p.Color(4) = alphaVal;

    % 缩放后的 a 点
    xa_tip = scale_x * x_a;
    ya_tip = scale_y * y_a;
    plot(xa_tip, ya_tip, 'ro', 'MarkerFaceColor','r', 'MarkerSize',3);

end
grid on;
xlabel('u_H (V)'); ylabel('u_B (V)');
title('基本磁化曲线（平滑）及采样点磁滞回线（各向异性缩放）');
legend('基本磁化曲线（平滑）','采样点','缩放磁滞回线','缩放回线顶点','Location','best');

%% 居里点输出
Tc = 104;
fprintf('测得居里点温度: %d °C\n', Tc);
