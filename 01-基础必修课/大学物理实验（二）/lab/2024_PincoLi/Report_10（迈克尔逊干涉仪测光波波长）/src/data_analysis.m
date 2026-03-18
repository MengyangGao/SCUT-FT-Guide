%% 迈克尔逊干涉仪实验 —— 数据处理与可视化

clear; clc; close all;
try
    set(0,'DefaultAxesFontName','Microsoft YaHei');
    set(0,'DefaultTextFontName','Microsoft YaHei');
catch
end
if ~strcmp(get(0,'DefaultAxesFontName'),'Microsoft YaHei')
    try
        set(0,'DefaultAxesFontName','SimHei');
        set(0,'DefaultTextFontName','SimHei');
    catch
    end
end
set(0,'DefaultLineLineWidth',1.6);
set(0,'DefaultAxesFontSize',12);

%% ================= 实验数据 =================
% 初始位置（读数）
d0_reading = 5.000;

% 条纹数与对应位置读数
N_fringes = (50:50:600)';  % 条纹数
d_position_reading = [6.370; 7.763; 9.405; 11.378; 12.968; 14.482; ...
                      15.979; 17.475; 18.978; 20.538; 22.018; 23.510];

% 读数单位转换系数（每格 = 0.01 mm）
scale_factor = 0.01; % mm/reading

% 计算实际位置（mm）
d0 = d0_reading * scale_factor; % mm
d_position = d_position_reading * scale_factor; % mm

% 计算位移
Delta_d = d_position - d0; % mm

%% ================= 线性拟合 =================
% 位移 vs 条纹数的线性拟合
% Delta_d = k * N_fringes + b
p = polyfit(N_fringes, Delta_d, 1);
k = p(1);  % mm/fringe
b = p(2);  % mm

% 计算拟合值
Delta_d_fit = polyval(p, N_fringes);

% 计算R^2
SS_res = sum((Delta_d - Delta_d_fit).^2);
SS_tot = sum((Delta_d - mean(Delta_d)).^2);
R2 = 1 - SS_res/SS_tot;

%% ================= 波长计算 =================
% 理论：λ = 2*Δd/N
% 从线性拟合斜率：k = Δd/N，所以 λ = 2*k
lambda_nm = 2 * k * 1e6; % 转换为纳米 (mm -> nm)

% 对每组数据单独计算波长
lambda_each = 2 * Delta_d ./ N_fringes * 1e6; % nm
lambda_mean = mean(lambda_each);
lambda_std = std(lambda_each, 1); % 样本标准差

%% ================= 不确定度分析 =================
% 斜率的不确定度（最小二乘法）
n = length(N_fringes);
s = sqrt(SS_res / (n-2)); % 残差标准差
sx = sqrt(sum((N_fringes - mean(N_fringes)).^2));
u_k = s / sx; % 斜率不确定度

% 波长的不确定度
u_lambda = 2 * u_k * 1e6; % nm

%% ================= 结果输出 =================
fprintf('========================================\n');
fprintf('迈克尔逊干涉仪实验数据处理结果\n');
fprintf('========================================\n\n');

fprintf('线性拟合结果：\n');
fprintf('  斜率 k = %.6f mm/条纹\n', k);
fprintf('  截距 b = %.6f mm\n', b);
fprintf('  相关系数 R² = %.6f\n\n', R2);

fprintf('波长测量结果：\n');
fprintf('  从拟合斜率：λ = %.2f nm\n', lambda_nm);
fprintf('  各组平均值：λ = %.2f ± %.2f nm\n', lambda_mean, lambda_std);
fprintf('  斜率不确定度：u(k) = %.6f mm/条纹\n', u_k);
fprintf('  波长不确定度：u(λ) = %.2f nm\n\n', u_lambda);

fprintf('理论值对比：\n');
fprintf('  He-Ne激光波长标准值：632.8 nm\n');
fprintf('  相对误差：%.2f%%\n', abs(lambda_nm - 632.8) / 632.8 * 100);
fprintf('========================================\n');

%% ================= 绘图1：位移-条纹数关系 =================
figure('Name','位移-条纹数关系','Color','w','Position',[100 100 800 600]);
scatter(N_fringes, Delta_d, 60, 'filled', 'MarkerFaceColor', [0.2 0.4 0.8]);
hold on;
xx = linspace(min(N_fringes), max(N_fringes), 200);
plot(xx, polyval(p,xx), '-', 'Color', [0.8 0.2 0.2], 'LineWidth', 2);
grid on; box on;
title('迈克尔逊干涉仪：动镜位移与条纹数的关系');
xlabel('条纹数 N');
ylabel('动镜位移 Δd (mm)');

% 添加拟合结果文本
txt = sprintf('线性拟合：Δd = %.4f × N + %.4f\nR² = %.6f\n\n测得波长：λ = %.2f nm', ...
              k, b, R2, lambda_nm);
text(100, max(Delta_d)*0.85, txt, 'Interpreter','none', ...
     'FontSize', 11, 'BackgroundColor', 'w', 'EdgeColor', 'k');
legend({'实验数据','线性拟合'}, 'Location','southeast');

% 保存图片
saveas(gcf, 'assets/图1_位移条纹关系.png');

%% ================= 绘图2：残差分析 =================
figure('Name','残差分析','Color','w','Position',[150 150 800 600]);

subplot(2,1,1);
residuals = Delta_d - Delta_d_fit;
plot(N_fringes, residuals, 'o-', 'MarkerSize', 8, 'LineWidth', 1.5, ...
     'Color', [0.2 0.6 0.4], 'MarkerFaceColor', [0.2 0.6 0.4]);
hold on;
plot([min(N_fringes) max(N_fringes)], [0 0], 'k--', 'LineWidth', 1);
grid on; box on;
title('拟合残差分析');
xlabel('条纹数 N');
ylabel('残差 (mm)');

subplot(2,1,2);
bar(1:length(lambda_each), lambda_each, 'FaceColor', [0.4 0.6 0.8]);
hold on;
plot([0 length(lambda_each)+1], [632.8 632.8], 'r--', 'LineWidth', 2);
plot([0 length(lambda_each)+1], [lambda_mean lambda_mean], 'g-', 'LineWidth', 2);
grid on; box on;
title('各组测量波长分布');
xlabel('测量组号');
ylabel('波长 (nm)');
legend({'各组测量值', '理论值 (632.8 nm)', sprintf('平均值 (%.2f nm)', lambda_mean)}, ...
       'Location','best');
xlim([0 length(lambda_each)+1]);

% 保存图片
saveas(gcf, 'assets/图2_残差与波长分布.png');

fprintf('\n图片已保存到 assets/ 目录\n');
