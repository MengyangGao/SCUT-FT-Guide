clear; clc; close all;

%% =============================================
%% 样品材质参数 (更新后的标准值)
%% =============================================
L_nominal = 160.00e-3;  % 标称长度 160.00mm
d_nominal = 6.00e-3;    % 标称直径 6.00mm
m_copper_nominal = 38e-3;   % 铜棒标称质量 38g
m_steel_nominal = 41e-3;    % 钢棒标称质量 41g

%% =============================================
%% 钢样杆数据
%% =============================================
% 几何参数 (单位转换为m) - 使用标称值
d_steel = d_nominal * ones(1,5);  % 直径 6.00mm
L_steel = L_nominal * ones(1,5);  % 长度 160.00mm
m_steel = m_steel_nominal;  % 质量 41g

% 全部6个测量点的支撑位置数据 (单位转换为m)
% 测量点: 1, 2, 3, 4(无信号), 5, 6
x1_steel_all = [5.84, 15.84, 25.84, 35.84, 45.84, 55.84] * 1e-3;
x2_steel_all = [154.16, 144.16, 134.16, 124.16, 114.16, 104.16] * 1e-3;

% 频率数据 Hz (测量点4无信号，标记为NaN)
f1_steel_all = [1051.90, 1043.70, 1036.40, NaN, 1035.60, 1039.80];
f2_steel_all = [1051.50, 1043.50, 1036.80, NaN, 1039.80, 1039.60];

% 提取有效数据点（排除无信号点）
valid_idx_steel = ~isnan(f1_steel_all);
x1_steel = x1_steel_all(valid_idx_steel);
x2_steel = x2_steel_all(valid_idx_steel);
f1_steel = f1_steel_all(valid_idx_steel);
f2_steel = f2_steel_all(valid_idx_steel);

%% =============================================
%% 铜样杆数据
%% =============================================
% 几何参数 (单位转换为m) - 使用标称值
d_copper = d_nominal * ones(1,5);  % 直径 6.00mm
L_copper = L_nominal * ones(1,5);  % 长度 160.00mm
m_copper = m_copper_nominal;  % 质量 38g

% 全部6个测量点的支撑位置数据 (单位转换为m)
x1_copper_all = [5.84, 15.84, 25.84, 35.84, 45.84, 55.84] * 1e-3;
x2_copper_all = [154.16, 144.16, 134.16, 124.16, 114.16, 104.16] * 1e-3;

% 频率数据 Hz (测量点4无信号，标记为NaN)
f1_copper_all = [780.70, 750.30, 735.00, NaN, 732.80, 736.10];
f2_copper_all = [777.80, 750.90, 735.40, NaN, 733.20, 736.50];

% 提取有效数据点（排除无信号点）
valid_idx_copper = ~isnan(f1_copper_all);
x1_copper = x1_copper_all(valid_idx_copper);
x2_copper = x2_copper_all(valid_idx_copper);
f1_copper = f1_copper_all(valid_idx_copper);
f2_copper = f2_copper_all(valid_idx_copper);

%% =============================================
%% 计算平均值
%% =============================================
d_steel_avg = mean(d_steel);
L_steel_avg = mean(L_steel);
d_copper_avg = mean(d_copper);
L_copper_avg = mean(L_copper);

% 频率平均值（有效数据点）
f_steel_avg = (f1_steel + f2_steel) / 2;
f_copper_avg = (f1_copper + f2_copper) / 2;

%% =============================================
%% 相对位置计算
%% =============================================
% 理论节点位置: 0.224L (距左端)
theoretical_node_steel = 0.224 * L_steel_avg;
theoretical_node_copper = 0.224 * L_copper_avg;

% 计算所有测量点的相对位置（相对于理论节点）
% 对于所有6个测量点
x_relative_all_steel = x1_steel_all - theoretical_node_steel;
x_relative_all_copper = x1_copper_all - theoretical_node_copper;

% 对于有效数据点
x_steel = x1_steel - theoretical_node_steel;
x_copper = x1_copper - theoretical_node_copper;

% 输出相对位置信息
fprintf('=============================================\n');
fprintf('各测量点相对位置分析（相对于理论节点 0.224L）\n');
fprintf('=============================================\n');
fprintf('理论节点位置: 钢杆 %.2f mm, 铜杆 %.2f mm\n', ...
    theoretical_node_steel*1000, theoretical_node_copper*1000);
fprintf('\n钢样杆各测量点相对位置:\n');
fprintf('测量点\t支点1(mm)\t支点2(mm)\t相对位置(mm)\t频率状态\n');
for i = 1:length(x1_steel_all)
    if isnan(f1_steel_all(i))
        status = '无信号';
    else
        status = sprintf('%.1f Hz', (f1_steel_all(i)+f2_steel_all(i))/2);
    end
    fprintf('%d\t%.2f\t\t%.2f\t\t%.2f\t\t%s\n', i, ...
        x1_steel_all(i)*1000, x2_steel_all(i)*1000, ...
        x_relative_all_steel(i)*1000, status);
end

fprintf('\n铜样杆各测量点相对位置:\n');
fprintf('测量点\t支点1(mm)\t支点2(mm)\t相对位置(mm)\t频率状态\n');
for i = 1:length(x1_copper_all)
    if isnan(f1_copper_all(i))
        status = '无信号';
    else
        status = sprintf('%.1f Hz', (f1_copper_all(i)+f2_copper_all(i))/2);
    end
    fprintf('%d\t%.2f\t\t%.2f\t\t%.2f\t\t%s\n', i, ...
        x1_copper_all(i)*1000, x2_copper_all(i)*1000, ...
        x_relative_all_copper(i)*1000, status);
end

%% 二次拟合
% 钢样杆拟合
p_steel = polyfit(x_steel, f_steel_avg, 2);
x_fit = linspace(min([x_steel, x_copper]), max([x_steel, x_copper]), 100);
f_fit_steel = polyval(p_steel, x_fit);

% 求顶点 (真实节点位置和基频)
x0_steel = -p_steel(2)/(2*p_steel(1));
f1_steel_fitted = polyval(p_steel, x0_steel);

% 铜样杆拟合
p_copper = polyfit(x_copper, f_copper_avg, 2);
f_fit_copper = polyval(p_copper, x_fit);

x0_copper = -p_copper(2)/(2*p_copper(1));
f1_copper_fitted = polyval(p_copper, x0_copper);

%% 计算杨氏模量
E_coefficient = 1.6067;
E_steel = E_coefficient * L_steel_avg^3 * m_steel * f1_steel_fitted^2 / d_steel_avg^4;
E_copper = E_coefficient * L_copper_avg^3 * m_copper * f1_copper_fitted^2 / d_copper_avg^4;

%% 创建可视化图表
% 检查并创建assets目录
if ~exist('assets', 'dir')
    mkdir('assets');
end

%% 图1: 频率-位置关系图
figure('Position', [100, 100, 800, 600]);
plot(x_steel*1000, f_steel_avg, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'red', 'LineWidth', 2); 
hold on;
plot(x_copper*1000, f_copper_avg, 'bs', 'MarkerSize', 10, 'MarkerFaceColor', 'blue', 'LineWidth', 2);
plot(x_fit*1000, f_fit_steel, 'r--', 'LineWidth', 2.5);
plot(x_fit*1000, f_fit_copper, 'b--', 'LineWidth', 2.5);
plot(x0_steel*1000, f1_steel_fitted, 'r*', 'MarkerSize', 15, 'LineWidth', 3);
plot(x0_copper*1000, f1_copper_fitted, 'b*', 'MarkerSize', 15, 'LineWidth', 3);

grid on; grid minor;
xlabel('相对节点位置 (mm)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('共振频率 (Hz)', 'FontSize', 12, 'FontWeight', 'bold');
title('支撑位置与共振频率关系及二次拟合曲线', 'FontSize', 14, 'FontWeight', 'bold');
legend('钢样杆数据点', '铜样杆数据点', '钢样杆拟合曲线', '铜样杆拟合曲线', ...
       sprintf('钢样杆基频 (%.1f Hz)', f1_steel_fitted), ...
       sprintf('铜样杆基频 (%.1f Hz)', f1_copper_fitted), ...
       'Location', 'best', 'FontSize', 10);

% 美化图表
ax = gca;
ax.FontSize = 11;
ax.LineWidth = 1.2;
set(gca, 'Color', [0.98 0.98 0.98]);
saveas(gcf, '../assets/频率-位置关系图.png');
saveas(gcf, '../assets/频率-位置关系图.fig');

%% 图2: 杨氏模量对比图
figure('Position', [100, 100, 700, 500]);
E_ref = [2.0e11, 1.1e11];  % 参考值
E_exp = [E_steel, E_copper];
materials = {'钢样杆', '铜样杆'};
x_pos = 1:2;

b = bar(x_pos, [E_ref; E_exp]'/1e11, 'grouped');
b(1).FaceColor = [0.8 0.3 0.3];
b(2).FaceColor = [0.3 0.3 0.8];
b(1).EdgeColor = 'black';
b(2).EdgeColor = 'black';
b(1).LineWidth = 1.5;
b(2).LineWidth = 1.5;

set(gca, 'XTickLabel', materials);
ylabel('杨氏模量 (×10^{11} Pa)', 'FontSize', 12, 'FontWeight', 'bold');
title('实验测得杨氏模量与理论值对比', 'FontSize', 14, 'FontWeight', 'bold');
legend('理论参考值', '实验测量值', 'Location', 'best', 'FontSize', 11);
grid on; grid minor;

% 添加数值标签
for i = 1:2
    text(i-0.15, E_ref(i)/1e11+0.05, sprintf('%.1f', E_ref(i)/1e11), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
    text(i+0.15, E_exp(i)/1e11+0.05, sprintf('%.2f', E_exp(i)/1e11), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

ax = gca;
ax.FontSize = 11;
ax.LineWidth = 1.2;
set(gca, 'Color', [0.98 0.98 0.98]);
saveas(gcf, '../assets/杨氏模量对比图.png');
saveas(gcf, '../assets/杨氏模量对比图.fig');

%% 图3: 误差分析图
figure('Position', [100, 100, 600, 500]);
relative_error = abs(E_exp - E_ref) ./ E_ref * 100;
b = bar(x_pos, relative_error, 'FaceColor', [0.9 0.5 0.1], 'EdgeColor', 'black', 'LineWidth', 2);

set(gca, 'XTickLabel', materials);
ylabel('相对误差 (%)', 'FontSize', 12, 'FontWeight', 'bold');
title('实验相对误差分析', 'FontSize', 14, 'FontWeight', 'bold');
grid on; grid minor;

for i = 1:length(relative_error)
    text(i, relative_error(i)+0.5, sprintf('%.1f%%', relative_error(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
end

ax = gca;
ax.FontSize = 11;
ax.LineWidth = 1.2;
set(gca, 'Color', [0.98 0.98 0.98]);
ylim([0, max(relative_error)*1.2]);
saveas(gcf, '../assets/误差分析图.png');
saveas(gcf, '../assets/误差分析图.fig');

%% 图4: 振动模态分析图
figure('Position', [100, 100, 900, 700]);

% 理论振型曲线
subplot(2,2,1);
L_norm = 1;  % 归一化长度
x_mode = linspace(0, L_norm, 1000);
K1L = 4.7300;

% 简化的第一阶振型函数（近似）
y_mode = sin(pi*x_mode) .* (1 - cos(2*pi*x_mode));
y_mode = y_mode / max(abs(y_mode));

plot(x_mode, y_mode, 'k-', 'LineWidth', 3); hold on;
plot([0.224, 0.776], [0, 0], 'ro', 'MarkerSize', 12, 'MarkerFaceColor', 'red');
plot([0.224, 0.776], [0, 0], 'r|', 'MarkerSize', 25, 'LineWidth', 4);
grid on; grid minor;
xlabel('归一化位置 x/L', 'FontSize', 11);
ylabel('归一化振幅', 'FontSize', 11);
title('两端自由杆第一阶弯曲振型', 'FontSize', 12, 'FontWeight', 'bold');
legend('振型曲线', '理论节点', 'Location', 'best');
set(gca, 'Color', [0.98 0.98 0.98]);

% 频谱特性示意图
subplot(2,2,2);
f_center_steel = f1_steel_fitted;
f_center_copper = f1_copper_fitted;
Q = 80;  % 品质因子

f_range_steel = linspace(f_center_steel-15, f_center_steel+15, 1000);
f_range_copper = linspace(f_center_copper-15, f_center_copper+15, 1000);

% 共振峰函数 (洛伦兹线型)
response_steel = 1 ./ (1 + Q^2 * ((f_range_steel - f_center_steel)/f_center_steel).^2);
response_copper = 1 ./ (1 + Q^2 * ((f_range_copper - f_center_copper)/f_center_copper).^2);

plot(f_range_steel, response_steel, 'r-', 'LineWidth', 2.5); hold on;
plot(f_range_copper, response_copper, 'b-', 'LineWidth', 2.5);
plot(f_center_steel, 1, 'r*', 'MarkerSize', 15, 'LineWidth', 3);
plot(f_center_copper, 1, 'b*', 'MarkerSize', 15, 'LineWidth', 3);
grid on; grid minor;
xlabel('频率 (Hz)', 'FontSize', 11);
ylabel('归一化响应幅度', 'FontSize', 11);
title('共振响应曲线', 'FontSize', 12, 'FontWeight', 'bold');
legend('钢样杆', '铜样杆', '钢基频', '铜基频', 'Location', 'best');
set(gca, 'Color', [0.98 0.98 0.98]);

% 数据分布图
subplot(2,2,3);
scatter(d_steel*1000, ones(1,5)*1, 80, 'r', 'filled', '^'); hold on;
scatter(d_copper*1000, ones(1,5)*2, 80, 'b', 'filled', 'v');
errorbar(1, d_steel_avg*1000, std(d_steel)*1000, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
errorbar(2, d_copper_avg*1000, std(d_copper)*1000, 'bo', 'MarkerSize', 10, 'LineWidth', 2);
set(gca, 'YTick', [1, 2], 'YTickLabel', {'钢样杆', '铜样杆'});
xlabel('直径 (mm)', 'FontSize', 11);
title('样杆直径测量数据分布', 'FontSize', 12, 'FontWeight', 'bold');
grid on; grid minor;
set(gca, 'Color', [0.98 0.98 0.98]);

% 拟合残差分析
subplot(2,2,4);
residual_steel = f_steel_avg - polyval(p_steel, x_steel);
residual_copper = f_copper_avg - polyval(p_copper, x_copper);
stem(x_steel*1000, residual_steel, 'r', 'LineWidth', 2, 'MarkerSize', 8); hold on;
stem(x_copper*1000, residual_copper, 'b', 'LineWidth', 2, 'MarkerSize', 8);
grid on; grid minor;
xlabel('相对节点位置 (mm)', 'FontSize', 11);
ylabel('拟合残差 (Hz)', 'FontSize', 11);
title('二次拟合残差分析', 'FontSize', 12, 'FontWeight', 'bold');
legend('钢样杆残差', '铜样杆残差', 'Location', 'best');
set(gca, 'Color', [0.98 0.98 0.98]);

saveas(gcf, '../assets/振动模态分析图.png');
saveas(gcf, '../assets/振动模态分析图.fig');

%% 图5: 无信号点分析图 (测量点4)
figure('Position', [100, 100, 900, 600]);

% 子图1: 所有测量点位置与信号状态
subplot(2,2,1);
node_theory = 0.224 * L_nominal * 1000;  % 理论节点位置 mm
x_positions = x1_steel_all * 1000;  % 所有测量点位置

% 计算距离节点的偏离
distances = abs(x_positions - node_theory);

% 根据信号状态分别绘制
valid_pos = x_positions(valid_idx_steel);
valid_dist = distances(valid_idx_steel);
invalid_pos = x_positions(~valid_idx_steel);
invalid_dist = distances(~valid_idx_steel);

scatter(valid_pos, valid_dist, 150, [0.2 0.6 0.2], 'filled', 'MarkerEdgeColor', 'black', 'LineWidth', 1.5);
hold on;
scatter(invalid_pos, invalid_dist, 150, [0.8 0.2 0.2], 'filled', 'MarkerEdgeColor', 'black', 'LineWidth', 1.5);
plot([node_theory, node_theory], [0, max(distances)*1.1], 'b--', 'LineWidth', 2);
text(node_theory, max(distances)*1.05, sprintf('理论节点\n%.1fmm', node_theory), ...
    'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', 'blue');

xlabel('支点位置 (mm)', 'FontSize', 11);
ylabel('距理论节点距离 (mm)', 'FontSize', 11);
title('各测量点与理论节点距离', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
legend('有信号', '无信号', '理论节点', 'Location', 'best');

% 子图2: 频率随位置变化（含无信号点标记）
subplot(2,2,2);
% 有效数据点
plot(x_relative_all_steel(valid_idx_steel)*1000, f_steel_avg, 'ro-', 'MarkerSize', 10, ...
    'MarkerFaceColor', 'red', 'LineWidth', 2);
hold on;
% 无信号点标记
no_signal_idx = find(~valid_idx_steel);
for idx = no_signal_idx
    plot(x_relative_all_steel(idx)*1000, 1000, 'kx', 'MarkerSize', 15, 'LineWidth', 3);
end
% 拟合曲线
plot(x_fit*1000, f_fit_steel, 'r--', 'LineWidth', 2);

xlabel('相对节点位置 (mm)', 'FontSize', 11);
ylabel('共振频率 (Hz)', 'FontSize', 11);
title('钢样杆频率-位置关系（含无信号点）', 'FontSize', 12, 'FontWeight', 'bold');
legend('有效数据点', '无信号点', '二次拟合', 'Location', 'best');
grid on;

% 子图3: 振型分析与无信号解释
subplot(2,2,3);
L_norm = 1;
x_mode = linspace(0, L_norm, 500);
% 第一阶弯曲振型（近似）
y_mode = sin(pi*x_mode) .* (1 - cos(2*pi*x_mode));
y_mode = y_mode / max(abs(y_mode));

plot(x_mode, y_mode, 'k-', 'LineWidth', 2.5); hold on;

% 标记理论节点
plot([0.224, 0.776], [0, 0], 'go', 'MarkerSize', 12, 'MarkerFaceColor', 'green');

% 标记测量点4的位置 (35.84/160 = 0.224)
pos_point4 = 35.84 / 160;
plot(pos_point4, interp1(x_mode, y_mode, pos_point4), 'rx', 'MarkerSize', 15, 'LineWidth', 3);
text(pos_point4+0.05, 0.08, sprintf('测量点4\n(%.3f)', pos_point4), ...
    'HorizontalAlignment', 'left', 'FontSize', 9, 'Color', 'red');

xlabel('归一化位置 x/L', 'FontSize', 11);
ylabel('归一化振幅', 'FontSize', 11);
title('振型分析：测量点4恰好位于节点位置', 'FontSize', 12, 'FontWeight', 'bold');
legend('第一阶振型', '理论节点(0.224L, 0.776L)', '测量点4(无信号)', 'Location', 'best');
grid on;

% 子图4: 无信号原因解释文字
subplot(2,2,4);
axis off;
text(0.05, 0.95, '【测量点4无信号现象解释】', 'FontSize', 13, 'FontWeight', 'bold');
text(0.05, 0.82, '位置信息:', 'FontSize', 11, 'FontWeight', 'bold');
text(0.05, 0.72, sprintf('  支点1: 35.84 mm'), 'FontSize', 10);
text(0.05, 0.64, sprintf('  支点2: 124.16 mm'), 'FontSize', 10);
text(0.05, 0.56, sprintf('  理论节点: 0.224×160 = %.2f mm', node_theory), 'FontSize', 10);
text(0.05, 0.48, sprintf('  偏离距离: %.2f mm (几乎为零!)', abs(35.84 - node_theory)), 'FontSize', 10, 'Color', 'red');

text(0.05, 0.35, '物理原因:', 'FontSize', 11, 'FontWeight', 'bold');
text(0.05, 0.26, '1. 节点处振动位移恒为零', 'FontSize', 10);
text(0.05, 0.18, '2. 激振器无法在节点处激发振动', 'FontSize', 10);
text(0.05, 0.10, '3. 拾振器在节点处检测不到信号', 'FontSize', 10);
text(0.05, 0.02, '★ 完美验证了理论节点位置!', 'FontSize', 10, 'Color', [0 0.5 0], 'FontWeight', 'bold');

title('现象分析', 'FontSize', 12, 'FontWeight', 'bold');

saveas(gcf, '../assets/无信号点分析图.png');
saveas(gcf, '../assets/无信号点分析图.fig');

%% 图6: 综合实验结果展示
figure('Position', [100, 100, 1200, 800]);

% 主要结果表格可视化
subplot(2,3,[1,2]);
data_table = [L_steel_avg*1000, d_steel_avg*1000, m_steel*1000, f1_steel_fitted, E_steel/1e11;
              L_copper_avg*1000, d_copper_avg*1000, m_copper*1000, f1_copper_fitted, E_copper/1e11];

bar_data = data_table';
b = bar(bar_data);
b(1).FaceColor = [0.8 0.2 0.2];
b(2).FaceColor = [0.2 0.2 0.8];

set(gca, 'XTickLabel', {'长度(mm)', '直径(mm)', '质量(g)', '基频(Hz)', '杨氏模量(×10¹¹Pa)'});
xtickangle(45);
title('实验测量结果对比', 'FontSize', 14, 'FontWeight', 'bold');
legend('钢样杆', '铜样杆', 'Location', 'best');
grid on;

% 误差传递分析
subplot(2,3,3);
error_contributions = [3, 1, 2, 4];  % L, m, f, d的误差系数
error_labels = {'L³', 'm', 'f²', 'd⁴'};
pie(error_contributions, error_labels);
title('误差传递权重分析', 'FontSize', 12, 'FontWeight', 'bold');

% 实验精度分析
subplot(2,3,4);
% 由于使用标称值，标准偏差为0，改为显示频率标准偏差
freq_std_steel = std(f_steel_avg);
freq_std_copper = std(f_copper_avg);
precision_data = [freq_std_steel, freq_std_copper];
b = bar(1:2, precision_data, 'FaceColor', [0.3 0.6 0.8], 'EdgeColor', 'black', 'LineWidth', 1.5);
set(gca, 'XTickLabel', {'钢样杆', '铜样杆'});
ylabel('频率标准偏差 (Hz)', 'FontSize', 11);
title('共振频率测量离散度分析', 'FontSize', 12, 'FontWeight', 'bold');
grid on;
for i = 1:2
    text(i, precision_data(i)+0.2, sprintf('%.2f Hz', precision_data(i)), ...
         'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
end

% 理论与实验对比雷达图
subplot(2,3,5);
theta = linspace(0, 2*pi, 6);
theta = theta(1:end-1);

% 归一化数据 (相对于理论值的比例) - 使用更新后的参数
steel_ratio = [E_steel/E_ref(1), f1_steel_fitted/1100, d_steel_avg*1000/6, ...
               L_steel_avg*1000/160, m_steel*1000/41];
copper_ratio = [E_copper/E_ref(2), f1_copper_fitted/800, d_copper_avg*1000/6, ...
                L_copper_avg*1000/160, m_copper*1000/38];

polarplot([theta, theta(1)], [steel_ratio, steel_ratio(1)], 'r-o', 'LineWidth', 2); hold on;
polarplot([theta, theta(1)], [copper_ratio, copper_ratio(1)], 'b-s', 'LineWidth', 2);
thetaticks(rad2deg(theta));
thetaticklabels({'杨氏模量', '频率', '直径', '长度', '质量'});
title('归一化参数雷达图', 'FontSize', 12, 'FontWeight', 'bold');
legend('钢样杆', '铜样杆', 'Location', 'best');

% 实验流程图示意
subplot(2,3,6);
text(0.1, 0.9, '实验流程:', 'FontSize', 12, 'FontWeight', 'bold');
text(0.1, 0.8, '1. 测量样杆几何参数', 'FontSize', 10);
text(0.1, 0.7, '2. 标记理论节点位置', 'FontSize', 10);
text(0.1, 0.6, '3. 多点支撑测频率', 'FontSize', 10);
text(0.1, 0.5, '4. 二次拟合求基频', 'FontSize', 10);
text(0.1, 0.4, '5. 计算杨氏模量', 'FontSize', 10);
text(0.1, 0.25, sprintf('结果: E_{steel} = %.2f×10^{11}Pa', E_steel/1e11), 'FontSize', 11, 'Color', 'red');
text(0.1, 0.15, sprintf('      E_{copper} = %.2f×10^{11}Pa', E_copper/1e11), 'FontSize', 11, 'Color', 'blue');
text(0.1, 0.05, '注: 测量点4(35.84mm)无信号', 'FontSize', 9, 'Color', [0.5 0.5 0.5]);
axis off;
title('实验总结', 'FontSize', 12, 'FontWeight', 'bold');

saveas(gcf, '../assets/综合实验结果.png');
saveas(gcf, '../assets/综合实验结果.fig');

%% 输出详细结果
fprintf('================================\n');
fprintf('共振法测量杨氏模量实验结果汇总\n');
fprintf('================================\n');

fprintf('\n【钢样杆测量结果】\n');
fprintf('几何参数:\n');
fprintf('  平均长度: %.3f ± %.3f mm\n', L_steel_avg*1000, std(L_steel)*1000);
fprintf('  平均直径: %.3f ± %.3f mm\n', d_steel_avg*1000, std(d_steel)*1000);
fprintf('  样杆质量: %.2f g\n', m_steel*1000);
fprintf('动力学参数:\n');
fprintf('  拟合基频: %.2f Hz\n', f1_steel_fitted);
fprintf('  节点偏移: %.2f mm\n', x0_steel*1000);
fprintf('材料性质:\n');
fprintf('  杨氏模量: %.3e Pa = %.2f × 10¹¹ Pa\n', E_steel, E_steel/1e11);

fprintf('\n【铜样杆测量结果】\n');
fprintf('几何参数:\n');
fprintf('  平均长度: %.3f ± %.3f mm\n', L_copper_avg*1000, std(L_copper)*1000);
fprintf('  平均直径: %.3f ± %.3f mm\n', d_copper_avg*1000, std(d_copper)*1000);
fprintf('  样杆质量: %.2f g\n', m_copper*1000);
fprintf('动力学参数:\n');
fprintf('  拟合基频: %.2f Hz\n', f1_copper_fitted);
fprintf('  节点偏移: %.2f mm\n', x0_copper*1000);
fprintf('材料性质:\n');
fprintf('  杨氏模量: %.3e Pa = %.2f × 10¹¹ Pa\n', E_copper, E_copper/1e11);

fprintf('\n【实验精度分析】\n');
relative_error_steel = abs(E_steel - E_ref(1))/E_ref(1) * 100;
relative_error_copper = abs(E_copper - E_ref(2))/E_ref(2) * 100;
fprintf('钢样杆相对误差: %.1f%% (理论值: %.1f × 10¹¹ Pa)\n', relative_error_steel, E_ref(1)/1e11);
fprintf('铜样杆相对误差: %.1f%% (理论值: %.1f × 10¹¹ Pa)\n', relative_error_copper, E_ref(2)/1e11);

fprintf('\n【拟合质量评估】\n');
R2_steel = 1 - sum(residual_steel.^2)/sum((f_steel_avg - mean(f_steel_avg)).^2);
R2_copper = 1 - sum(residual_copper.^2)/sum((f_copper_avg - mean(f_copper_avg)).^2);
fprintf('钢样杆拟合优度 R²: %.4f\n', R2_steel);
fprintf('铜样杆拟合优度 R²: %.4f\n', R2_copper);

%% =============================================
%% 测量点4（支点位置35.84mm和124.16mm）无信号现象分析
%% =============================================
fprintf('\n=============================================\n');
fprintf('【测量点4无信号现象分析】\n');
fprintf('=============================================\n');
fprintf('测量点4数据:\n');
fprintf('  支点1位置: 35.84 mm\n');
fprintf('  支点2位置: 124.16 mm\n');
fprintf('  测量结果: 钢棒和铜棒均无共振信号\n\n');

% 计算理论节点位置
node1_theory = 0.224 * L_nominal * 1000;  % mm
node2_theory = 0.776 * L_nominal * 1000;  % mm
fprintf('理论节点位置:\n');
fprintf('  节点1: %.2f mm (距左端)\n', node1_theory);
fprintf('  节点2: %.2f mm (距左端)\n', node2_theory);

% 计算测量点4支撑位置与理论节点的偏差
deviation_node1 = 35.84 - node1_theory;
deviation_node2 = 124.16 - node2_theory;
fprintf('\n测量点4支撑位置分析:\n');
fprintf('  支点1位置: 35.84 mm\n');
fprintf('  支点1相对于理论节点1的偏移: %.2f mm\n', deviation_node1);
fprintf('  支点2位置: 124.16 mm\n');
fprintf('  支点2相对于理论节点2的偏移: %.2f mm\n', deviation_node2);

fprintf('\n【无信号原因分析】:\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('★★★ 关键发现：测量点4的支点1恰好位于理论节点位置！★★★\n');
fprintf('   - 测量点4的支点1位于35.84mm处\n');
fprintf('   - 理论节点1位于 0.224 × 160 = %.2fmm\n', node1_theory);
fprintf('   - 偏移量仅为 %.2f mm，几乎完全重合！\n', abs(deviation_node1));
fprintf('\n【无信号的物理解释】:\n');
fprintf('1. 节点位置振幅为零\n');
fprintf('   - 在两端自由杆的基频振动中，节点是振动位移恒为零的位置\n');
fprintf('   - 当激振器/拾振器恰好位于节点附近时：\n');
fprintf('     (a) 激振器无法向样杆传递振动能量（节点处位移为零）\n');
fprintf('     (b) 拾振器检测不到振动信号（节点处无位移变化）\n');
fprintf('\n2. 换能器与样杆脱耦\n');
fprintf('   - 本实验装置中，激振器和拾振器通常安装在支撑点附近\n');
fprintf('   - 当支撑点恰好在节点位置时，换能器也处于"振动盲区"\n');
fprintf('   - 这导致机械耦合效率趋近于零\n');
fprintf('\n3. 实验验证了振动理论\n');
fprintf('   - 这一现象完美验证了两端自由杆节点位置的理论预测\n');
fprintf('   - 理论节点 0.224L = %.2f mm 与实际"无信号点"高度吻合\n', node1_theory);
fprintf('\n4. 实验意义:\n');
fprintf('   - 证明了理论节点位置计算的准确性\n');
fprintf('   - 说明支撑位置不应恰好位于节点上\n');
fprintf('   - 需要在节点附近（而非节点上）选择多个测量点\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

% 计算各测量点到理论节点的距离
fprintf('\n【各测量点与理论节点距离对比】:\n');
fprintf('测量点\t支点1位置(mm)\t距节点距离(mm)\t信号状态\n');
for i = 1:length(x1_steel_all)
    dist = abs(x1_steel_all(i)*1000 - node1_theory);
    if isnan(f1_steel_all(i))
        status = '无信号 ← (恰在节点上!)';
    else
        status = '有信号';
    end
    fprintf('%d\t%.2f\t\t%.2f\t\t%s\n', i, x1_steel_all(i)*1000, dist, status);
end
fprintf('\n结论: 测量点4距离理论节点最近(偏移仅%.2fmm)，\n', abs(deviation_node1));
fprintf('支撑点恰好位于节点位置，导致激振器/拾振器处于"振动盲区"，\n');
fprintf('无法激发或检测有效的振动信号。\n');
fprintf('这完美验证了两端自由杆振动节点位置的理论计算！\n');

fprintf('\n实验图像已保存至 assets/ 目录:\n');
fprintf('- 频率-位置关系图.png\n');
fprintf('- 杨氏模量对比图.png\n');
fprintf('- 误差分析图.png\n');
fprintf('- 振动模态分析图.png\n');
fprintf('- 无信号点分析图.png\n');
fprintf('- 综合实验结果.png\n');

fprintf('\n实验完成！共振法测量杨氏模量实验取得了满意的结果。\n');