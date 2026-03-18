clear; clc; close all;

%% 数据输入 - 将角度分秒转换为十进制度数
% 已知光栅 100L (100线/mm, d = 10 μm = 10000 nm)
d_known = 10000; % nm

% 绿光数据 (3次测量,每行: k=+2左游标, k=+2右游标, k=-2左游标, k=-2右游标)
green_known = [
    15 + 7/60,  195 + 1/60,  2 + 34/60, 182 + 31/60;
    15 + 6/60,  195 + 0/60,  2 + 34/60, 182 + 30/60;
    15 + 8/60,  195 + 1/60,  2 + 35/60, 182 + 31/60
];

% 黄光I数据 (3次测量)
yellow1_known = [
    15 + 31/60, 195 + 29/60, 2 + 12/60, 182 + 6/60;
    15 + 30/60, 195 + 30/60, 2 + 11/60, 182 + 5/60;
    15 + 31/60, 195 + 30/60, 2 + 13/60, 182 + 7/60
];

% 黄光II数据 (3次测量)
yellow2_known = [
    15 + 37/60, 195 + 30/60, 2 + 13/60, 182 + 9/60;
    15 + 38/60, 195 + 32/60, 2 + 12/60, 182 + 8/60;
    15 + 37/60, 195 + 31/60, 2 + 12/60, 182 + 9/60
];

% 未知光栅的绿光数据 (3次测量)
green_unknown = [
    27 + 57/60, 207 + 57/60, 349 + 50/60, 169 + 48/60;
    27 + 56/60, 207 + 57/60, 349 + 51/60, 169 + 49/60;
    27 + 58/60, 207 + 58/60, 349 + 50/60, 169 + 48/60
];

% 已知波长
lambda_green_known = 546.1; % nm (汞灯绿光)

%% 函数定义：计算衍射角
% 根据公式: θ = 1/4(|φ₁ - φ₋₁| + |φ'₁ - φ'₋₁|)
% 处理跨越360°的情况
calculate_angle_diff = @(a, b) min(abs(a - b), 360 - abs(a - b));
calculate_theta = @(phi1_p2, phi2_p2, phi1_m2, phi2_m2) ...
    0.25 * (calculate_angle_diff(phi1_p2, phi1_m2) + calculate_angle_diff(phi2_p2, phi2_m2));

% 处理多次测量数据的函数
function [theta_mean, theta_std, theta_all] = process_multiple_measurements(data_matrix, calc_func)
    n_measurements = size(data_matrix, 1);
    theta_all = zeros(n_measurements, 1);
    for i = 1:n_measurements
        theta_all(i) = calc_func(data_matrix(i,1), data_matrix(i,2), ...
                                  data_matrix(i,3), data_matrix(i,4));
    end
    theta_mean = mean(theta_all);
    theta_std = std(theta_all);
end

%% 计算已知光栅的衍射角 (含不确定度)
[theta_green_known, std_green_known, theta_green_all] = ...
    process_multiple_measurements(green_known, calculate_theta);
[theta_yellow1_known, std_yellow1_known, theta_yellow1_all] = ...
    process_multiple_measurements(yellow1_known, calculate_theta);
[theta_yellow2_known, std_yellow2_known, theta_yellow2_all] = ...
    process_multiple_measurements(yellow2_known, calculate_theta);

fprintf('========== 已知光栅 100L 数据处理 ==========\n');
fprintf('绿光衍射角:\n');
for i = 1:length(theta_green_all)
    fprintf('  测量%d: θ = %.4f°\n', i, theta_green_all(i));
end
fprintf('  平均值: θ = %.4f° ± %.4f°\n', theta_green_known, std_green_known);

fprintf('\n黄光I衍射角:\n');
for i = 1:length(theta_yellow1_all)
    fprintf('  测量%d: θ = %.4f°\n', i, theta_yellow1_all(i));
end
fprintf('  平均值: θ = %.4f° ± %.4f°\n', theta_yellow1_known, std_yellow1_known);

fprintf('\n黄光II衍射角:\n');
for i = 1:length(theta_yellow2_all)
    fprintf('  测量%d: θ = %.4f°\n', i, theta_yellow2_all(i));
end
fprintf('  平均值: θ = %.4f° ± %.4f°\n', theta_yellow2_known, std_yellow2_known);

%% 验证已知光栅常数 (使用绿光)
% d sin θ = k λ, k = 2
k = 2;
d_measured = (k * lambda_green_known) / sind(theta_green_known);

% 计算光栅常数的不确定度 (使用误差传递公式)
% Δd/d = Δθ/tanθ (角度的不确定度以弧度计算)
delta_d = d_measured * (std_green_known * pi/180) / tand(theta_green_known);

fprintf('\n使用绿光验证光栅常数: d = %.2f ± %.2f nm\n', d_measured, delta_d);
fprintf('理论值: d = %.2f nm\n', d_known);
fprintf('相对误差: %.2f%%\n', abs(d_measured - d_known) / d_known * 100);

%% 使用已知光栅测量黄光波长
lambda_yellow1 = (d_known * sind(theta_yellow1_known)) / k;
lambda_yellow2 = (d_known * sind(theta_yellow2_known)) / k;

% 计算波长的不确定度
delta_lambda_yellow1 = (d_known * cosd(theta_yellow1_known) * std_yellow1_known * pi/180) / k;
delta_lambda_yellow2 = (d_known * cosd(theta_yellow2_known) * std_yellow2_known * pi/180) / k;

fprintf('\n黄光I波长 λ₁ = %.2f ± %.2f nm\n', lambda_yellow1, delta_lambda_yellow1);
fprintf('黄光II波长 λ₂ = %.2f ± %.2f nm\n', lambda_yellow2, delta_lambda_yellow2);

% 与汞灯黄光双线标准值比较 (589.0 nm, 589.6 nm)
fprintf('\n标准值: 589.0 nm, 589.6 nm\n');
fprintf('相对误差: %.2f%%, %.2f%%\n', ...
    abs(lambda_yellow1 - 589.0) / 589.0 * 100, ...
    abs(lambda_yellow2 - 589.6) / 589.6 * 100);

%% 计算光栅特性参数
% 分辨本领 R = λ̄/Δλ = kN
lambda_bar = (lambda_yellow1 + lambda_yellow2) / 2;
delta_lambda = abs(lambda_yellow2 - lambda_yellow1);
N_effective = 100 * 20; % 假设有效宽度20mm，100线/mm
R_theory = k * N_effective;
R_measured = lambda_bar / delta_lambda;

fprintf('\n========== 光栅特性参数 ==========\n');
fprintf('黄光双线平均波长 λ̄ = %.2f nm\n', lambda_bar);
fprintf('波长差 Δλ = %.2f nm\n', delta_lambda);
fprintf('理论分辨本领 R = kN = %.0f\n', R_theory);
fprintf('实测分辨本领 R = λ̄/Δλ = %.0f\n', R_measured);

% 角色散率 D = k/(d cos θ)
D_yellow = k / (d_known * cosd(theta_yellow1_known));
fprintf('角色散率 D = %.4e rad/nm = %.4f °/nm\n', D_yellow * pi/180, D_yellow);

%% 计算未知光栅常数
[theta_green_unknown, std_green_unknown, theta_green_unknown_all] = ...
    process_multiple_measurements(green_unknown, calculate_theta);

fprintf('\n========== 未知光栅数据处理 ==========\n');
fprintf('绿光衍射角:\n');
for i = 1:length(theta_green_unknown_all)
    fprintf('  测量%d: θ = %.4f°\n', i, theta_green_unknown_all(i));
end
fprintf('  平均值: θ = %.4f° ± %.4f°\n', theta_green_unknown, std_green_unknown);

% 使用绿光已知波长计算未知光栅常数
d_unknown = (k * lambda_green_known) / sind(theta_green_unknown);

% 计算未知光栅常数的不确定度
delta_d_unknown = d_unknown * (std_green_unknown * pi/180) / tand(theta_green_unknown);

fprintf('\n未知光栅常数 d = %.2f ± %.2f nm\n', d_unknown, delta_d_unknown);
fprintf('对应线数 n = %.0f 线/mm\n', 1e6 / d_unknown);

%% 生成数据表格用于LaTeX
fprintf('\n========== 数据记录表 ==========\n');
fprintf('已知光栅测量数据:\n');
fprintf('谱线\t\t平均衍射角θ\t标准差\t\t波长λ\t\t不确定度\n');
fprintf('绿光\t\t%.4f°\t%.4f°\t%.2f nm\t已知\n', ...
    theta_green_known, std_green_known, lambda_green_known);
fprintf('黄光I\t\t%.4f°\t%.4f°\t%.2f nm\t±%.2f nm\n', ...
    theta_yellow1_known, std_yellow1_known, lambda_yellow1, delta_lambda_yellow1);
fprintf('黄光II\t\t%.4f°\t%.4f°\t%.2f nm\t±%.2f nm\n', ...
    theta_yellow2_known, std_yellow2_known, lambda_yellow2, delta_lambda_yellow2);

fprintf('\n原始测量数据（已知光栅-绿光）:\n');
for i = 1:size(green_known, 1)
    fprintf('测量%d: k=+2左 %.2f°, k=+2右 %.2f°, k=-2左 %.2f°, k=-2右 %.2f°, θ=%.4f°\n', ...
        i, green_known(i,1), green_known(i,2), green_known(i,3), green_known(i,4), theta_green_all(i));
end

fprintf('\n原始测量数据（已知光栅-黄光I）:\n');
for i = 1:size(yellow1_known, 1)
    fprintf('测量%d: k=+2左 %.2f°, k=+2右 %.2f°, k=-2左 %.2f°, k=-2右 %.2f°, θ=%.4f°\n', ...
        i, yellow1_known(i,1), yellow1_known(i,2), yellow1_known(i,3), yellow1_known(i,4), theta_yellow1_all(i));
end

fprintf('\n原始测量数据（已知光栅-黄光II）:\n');
for i = 1:size(yellow2_known, 1)
    fprintf('测量%d: k=+2左 %.2f°, k=+2右 %.2f°, k=-2左 %.2f°, k=-2右 %.2f°, θ=%.4f°\n', ...
        i, yellow2_known(i,1), yellow2_known(i,2), yellow2_known(i,3), yellow2_known(i,4), theta_yellow2_all(i));
end

fprintf('\n原始测量数据（未知光栅-绿光）:\n');
for i = 1:size(green_unknown, 1)
    fprintf('测量%d: k=+2左 %.2f°, k=+2右 %.2f°, k=-2左 %.2f°, k=-2右 %.2f°, θ=%.4f°\n', ...
        i, green_unknown(i,1), green_unknown(i,2), green_unknown(i,3), green_unknown(i,4), theta_green_unknown_all(i));
end

%% 可视化 1: 衍射角与波长关系
figure('Color', 'w', 'Position', [100, 100, 900, 600]);

% 已知光栅数据点
wavelengths_known = [lambda_green_known, lambda_yellow1, lambda_yellow2];
angles_known = [theta_green_known, theta_yellow1_known, theta_yellow2_known];

% 理论曲线
lambda_range = 500:1:650;
theta_theory = asind(k * lambda_range / d_known);

plot(wavelengths_known, angles_known, 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'r', 'LineWidth', 2);
hold on;
plot(lambda_range, theta_theory, 'b-', 'LineWidth', 2);
grid on;

xlabel('波长 λ (nm)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('衍射角 θ (°)', 'FontSize', 14, 'FontWeight', 'bold');
title('光栅二级衍射角与波长关系 (已知光栅 100L)', 'FontSize', 16, 'FontWeight', 'bold');
legend('实验数据', '理论曲线 d sin θ = 2λ', 'Location', 'northwest', 'FontSize', 12);

% 标注数据点
text(lambda_green_known, theta_green_known + 0.1, sprintf('绿光 %.1f nm', lambda_green_known), ...
    'FontSize', 10, 'HorizontalAlignment', 'center');
text(lambda_yellow1, theta_yellow1_known + 0.1, sprintf('黄光I %.1f nm', lambda_yellow1), ...
    'FontSize', 10, 'HorizontalAlignment', 'center');
text(lambda_yellow2, theta_yellow2_known + 0.1, sprintf('黄光II %.1f nm', lambda_yellow2), ...
    'FontSize', 10, 'HorizontalAlignment', 'center');

saveas(gcf, 'assets/wavelength_angle_relation.png');
fprintf('\n图表已保存: assets/wavelength_angle_relation.png\n');

%% 可视化 2: 黄光双线分辨
figure('Color', 'w', 'Position', [150, 150, 900, 600]);

% 模拟光谱线强度分布 (假设为高斯分布)
angle_range = linspace(theta_yellow1_known - 0.2, theta_yellow2_known + 0.2, 1000);
sigma = 0.03; % 线宽

intensity1 = exp(-((angle_range - theta_yellow1_known).^2) / (2 * sigma^2));
intensity2 = exp(-((angle_range - theta_yellow2_known).^2) / (2 * sigma^2));
intensity_total = intensity1 + intensity2;

plot(angle_range, intensity1, 'r--', 'LineWidth', 1.5);
hold on;
plot(angle_range, intensity2, 'g--', 'LineWidth', 1.5);
plot(angle_range, intensity_total, 'b-', 'LineWidth', 2);
grid on;

xlabel('衍射角 θ (°)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('相对强度', 'FontSize', 14, 'FontWeight', 'bold');
title('黄光双线光谱分辨示意图', 'FontSize', 16, 'FontWeight', 'bold');
legend('黄光I (589.0 nm)', '黄光II (589.6 nm)', '总强度', 'Location', 'northeast', 'FontSize', 12);

% 标注波长差
xline(theta_yellow1_known, 'r:', 'LineWidth', 1);
xline(theta_yellow2_known, 'g:', 'LineWidth', 1);
text((theta_yellow1_known + theta_yellow2_known)/2, max(intensity_total)*0.9, ...
    sprintf('Δθ = %.4f°', abs(theta_yellow2_known - theta_yellow1_known)), ...
    'FontSize', 11, 'HorizontalAlignment', 'center', 'BackgroundColor', 'w');

saveas(gcf, 'assets/yellow_doublet_resolution.png');
fprintf('图表已保存: assets/yellow_doublet_resolution.png\n');

%% 可视化 3: 已知与未知光栅对比
figure('Color', 'w', 'Position', [200, 200, 900, 600]);

% 对比数据
gratings = {'已知光栅 (100 L)', '未知光栅'};
d_values = [d_measured, d_unknown];
theta_values = [theta_green_known, theta_green_unknown];

subplot(1, 2, 1);
bar(d_values, 'FaceColor', [0.2 0.4 0.6]);
set(gca, 'XTickLabel', gratings, 'FontSize', 11);
ylabel('光栅常数 d (nm)', 'FontSize', 12, 'FontWeight', 'bold');
title('两种光栅的光栅常数对比', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
for i = 1:length(d_values)
    text(i, d_values(i) + 200, sprintf('%.0f nm\n(%.0f 线/mm)', d_values(i), 1e6/d_values(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

subplot(1, 2, 2);
bar(theta_values, 'FaceColor', [0.6 0.2 0.2]);
set(gca, 'XTickLabel', gratings, 'FontSize', 11);
ylabel('绿光二级衍射角 θ (°)', 'FontSize', 12, 'FontWeight', 'bold');
title('相同波长在两种光栅的衍射角对比', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
for i = 1:length(theta_values)
    text(i, theta_values(i) + 0.5, sprintf('%.2f°', theta_values(i)), ...
        'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

saveas(gcf, 'assets/grating_comparison.png');
fprintf('图表已保存: assets/grating_comparison.png\n');

%% 保存结果到文件供LaTeX使用
fid = fopen('results.txt', 'w');
fprintf(fid, 'theta_green_known=%.4f\n', theta_green_known);
fprintf(fid, 'std_green_known=%.4f\n', std_green_known);
fprintf(fid, 'theta_yellow1_known=%.4f\n', theta_yellow1_known);
fprintf(fid, 'std_yellow1_known=%.4f\n', std_yellow1_known);
fprintf(fid, 'theta_yellow2_known=%.4f\n', theta_yellow2_known);
fprintf(fid, 'std_yellow2_known=%.4f\n', std_yellow2_known);
fprintf(fid, 'lambda_yellow1=%.2f\n', lambda_yellow1);
fprintf(fid, 'delta_lambda_yellow1=%.2f\n', delta_lambda_yellow1);
fprintf(fid, 'lambda_yellow2=%.2f\n', lambda_yellow2);
fprintf(fid, 'delta_lambda_yellow2=%.2f\n', delta_lambda_yellow2);
fprintf(fid, 'd_unknown=%.2f\n', d_unknown);
fprintf(fid, 'delta_d_unknown=%.2f\n', delta_d_unknown);
fprintf(fid, 'n_unknown=%.0f\n', 1e6/d_unknown);
fprintf(fid, 'theta_green_unknown=%.4f\n', theta_green_unknown);
fprintf(fid, 'std_green_unknown=%.4f\n', std_green_unknown);
fprintf(fid, 'R_measured=%.0f\n', R_measured);
fprintf(fid, 'D_yellow=%.4f\n', D_yellow);
fprintf(fid, 'd_measured=%.2f\n', d_measured);
fprintf(fid, 'delta_d=%.2f\n', delta_d);
fclose(fid);

fprintf('\n========== 数据处理完成 ==========\n');
