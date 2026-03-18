clear; clc; close all;

%% ---------- 标定曲线：电流 I -> 磁感应强度 B0 ----------
I_cal = [1.30, 1.40, 1.50, 1.60, 1.70, 1.80, 1.90, 2.00, 2.10, 2.20, 2.30];
B_cal = [0.202, 0.213, 0.224, 0.234, 0.242, 0.249, 0.255, 0.261, 0.265, 0.270, 0.274];

%% ---------- 水样品 (^1H) 原始数据 ----------
nu_H = [11.60, 11.23, 11.18, 10.95, 10.77, 10.30, 10.00]; % MHz
I_H  = [2.24, 2.02, 2.00, 1.96, 1.80, 1.66, 1.56];       % A
% 由电流插值得到 B0（允许线性外推）
B_H = interp1(I_cal, B_cal, I_H, 'linear', 'extrap');

%% ---------- 聚四氟乙烯样品 (^{19}F) 原始数据（全量参与） ----------
nu_F = [11.80, 11.50, 11.20, 10.90, 10.60, 10.30, 10.00, 11.65]; % MHz
I_F  = [2.90, 2.61, 2.39, 2.17, 1.96, 1.86, 1.74, 2.77];         % A
B_F  = interp1(I_cal, B_cal, I_F, 'linear', 'extrap');

%% ---------- 常量（理论磁旋比） ----------
gamma_H_theory = 2.675e8; % rad·T^-1·s^-1  (^1H)
gamma_F_theory = 2.518e8; % rad·T^-1·s^-1  (^{19}F)

%% ========================= 拟合与评价函数 =========================
% 强制过原点最小二乘斜率：k0 = (B'*nu)/(B'*B)
fit_through_origin = @(B, nu) (B(:)'*nu(:)) / (B(:)'*B(:));

% 普通线性拟合（含截距）
fit_linear = @(B, nu) polyfit(B, nu, 1);  % 返回 [k, b]

% 计算 R^2：基于普通定义 1 - SSE/SST
compute_R2 = @(y, yfit) 1 - sum((y - yfit).^2) / sum((y - mean(y)).^2);

% 由斜率 k (MHz/T) 计算 gamma (rad·T^-1·s^-1)
k_to_gamma = @(k_MHz_per_T) 2*pi*k_MHz_per_T*1e6;

% 相对误差（%）
rel_err = @(expv, theory) abs(expv - theory)/theory*100;

%% ========================= 水样品：拟合与结果 =========================
% 1) 过原点拟合
k_H0 = fit_through_origin(B_H, nu_H);               % MHz/T
nu_H_fit0 = k_H0 * B_H;                             % 过原点拟合预测
R2_H0 = compute_R2(nu_H, nu_H_fit0);
gamma_H0 = k_to_gamma(k_H0);
err_H0 = rel_err(gamma_H0, gamma_H_theory);

% 2) 含截距普通线性拟合（参考）
p_H = fit_linear(B_H, nu_H);                        % [k, b]
nu_H_fit_lin = polyval(p_H, B_H);
R2_H_lin = compute_R2(nu_H, nu_H_fit_lin);
gamma_H_lin = k_to_gamma(p_H(1));
err_H_lin = rel_err(gamma_H_lin, gamma_H_theory);

%% ========================= 19F：拟合与结果 =========================
% 1) 过原点拟合
k_F0 = fit_through_origin(B_F, nu_F);               % MHz/T
nu_F_fit0 = k_F0 * B_F;
R2_F0 = compute_R2(nu_F, nu_F_fit0);
gamma_F0 = k_to_gamma(k_F0);
err_F0 = rel_err(gamma_F0, gamma_F_theory);

% 2) 含截距普通线性拟合（参考）
p_F = fit_linear(B_F, nu_F);
nu_F_fit_lin = polyval(p_F, B_F);
R2_F_lin = compute_R2(nu_F, nu_F_fit_lin);
gamma_F_lin = k_to_gamma(p_F(1));
err_F_lin = rel_err(gamma_F_lin, gamma_F_theory);

%% ========================= 打印结果 =========================
fprintf('========== 水样品(^1H) 结果 ==========\n');
fprintf('[过原点] 斜率 k_H0 = %.3f MHz/T\n', k_H0);
fprintf('[过原点] R^2 = %.4f\n', R2_H0);
fprintf('[过原点] 磁旋比 gamma_H0 = %.3e rad·T^-1·s^-1\n', gamma_H0);
fprintf('理论值 gamma_H = %.3e rad·T^-1·s^-1\n', gamma_H_theory);
fprintf('[过原点] 相对误差 = %.2f%%\n\n', err_H0);

fprintf('[含截距-参考] 斜率 k_H = %.3f MHz/T, 截距 b_H = %.3f MHz\n', p_H(1), p_H(2));
fprintf('[含截距-参考] R^2 = %.4f\n', R2_H_lin);
fprintf('[含截距-参考] 磁旋比 gamma_H = %.3e rad·T^-1·s^-1\n', gamma_H_lin);
fprintf('[含截距-参考] 相对误差 = %.2f%%\n\n', err_H_lin);

fprintf('========== 聚四氟乙烯(^{19}F) 结果 ==========\n');
fprintf('[过原点] 斜率 k_F0 = %.3f MHz/T\n', k_F0);
fprintf('[过原点] R^2 = %.4f\n', R2_F0);
fprintf('[过原点] 磁旋比 gamma_F0 = %.3e rad·T^-1·s^-1\n', gamma_F0);
fprintf('理论值 gamma_F = %.3e rad·T^-1·s^-1\n', gamma_F_theory);
fprintf('[过原点] 相对误差 = %.2f%%\n\n', err_F0);

fprintf('[含截距-参考] 斜率 k_F = %.3f MHz/T, 截距 b_F = %.3f MHz\n', p_F(1), p_F(2));
fprintf('[含截距-参考] R^2 = %.4f\n', R2_F_lin);
fprintf('[含截距-参考] 磁旋比 gamma_F = %.3e rad·T^-1·s^-1\n', gamma_F_lin);
fprintf('[含截距-参考] 相对误差 = %.2f%%\n\n', err_F_lin);

%% ========================= 作图：水样品 =========================
figure('Color','w', 'Position', [100, 100, 820, 620]);
plot(B_H, nu_H, 'ro', 'MarkerSize', 9, 'MarkerFaceColor', 'r', 'LineWidth', 1.2); hold on;
% 过原点拟合线
B_H_range = linspace(min(B_H), max(B_H), 100);
plot(B_H_range, k_H0*B_H_range, 'b-', 'LineWidth', 2.0);
% 含截距拟合线（虚线，参考）
plot(B_H_range, polyval(p_H, B_H_range), 'k--', 'LineWidth', 1.5);

grid on;
xlabel('磁感应强度 B_0 (T)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('共振频率 \\nu (MHz)', 'FontSize', 13, 'FontWeight', 'bold');
title('水样品(^1H)：\nu 与 B_0 的关系', 'FontSize', 16, 'FontWeight', 'bold');
legend('实验数据','过原点拟合','含截距拟合(参考)','Location','northwest','FontSize',11);

txt_H = sprintf('过原点: \n \\nu = %.3f B_0 \nR^2 = %.4f \n \\gamma = %.3e', k_H0, R2_H0, gamma_H0);
text(min(B_H)+0.02*(max(B_H)-min(B_H)), max(nu_H)-0.08*(max(nu_H)-min(nu_H)), ...
    txt_H, 'FontSize', 11, 'BackgroundColor','w', 'EdgeColor','k');

%% ========================= 作图：聚四氟乙烯 =========================
figure('Color','w', 'Position', [140, 140, 820, 620]);
plot(B_F, nu_F, 'bs', 'MarkerSize', 9, 'MarkerFaceColor', 'b', 'LineWidth', 1.2); hold on;
% 过原点拟合线
B_F_range = linspace(min(B_F), max(B_F), 100);
plot(B_F_range, k_F0*B_F_range, 'r-', 'LineWidth', 2.0);
% 含截距拟合线（虚线，参考）
plot(B_F_range, polyval(p_F, B_F_range), 'k--', 'LineWidth', 1.5);

grid on;
xlabel('磁感应强度 B_0 (T)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('共振频率 \nu (MHz)', 'FontSize', 13, 'FontWeight', 'bold');
title('聚四氟乙烯(^{19}F)：\\nu 与 B_0 的关系', 'FontSize', 16, 'FontWeight', 'bold');
legend('实验数据','过原点拟合','含截距拟合(参考)','Location','northwest','FontSize',11);

txt_F = sprintf('过原点: \n \\nu = %.3f B_0\nR^2 = %.4f\n \\gamma = %.3e', k_F0, R2_F0, gamma_F0);
text(min(B_F)+0.02*(max(B_F)-min(B_F)), max(nu_F)-0.08*(max(nu_F)-min(nu_F)), ...
    txt_F, 'FontSize', 11, 'BackgroundColor','w', 'EdgeColor','k');

%% ========================= 理论斜率 =========================
kH_th = (gamma_H_theory/(2*pi))/1e6; % MHz/T
kF_th = (gamma_F_theory/(2*pi))/1e6; % MHz/T
fprintf('--- 理论斜率对照 ---\n');
fprintf('k_H_theory ≈ %.3f MHz/T, k_F_theory ≈ %.3f MHz/T\n', kH_th, kF_th);
