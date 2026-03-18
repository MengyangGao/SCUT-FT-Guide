% 马吕斯定律实验数据拟合程序
% 定义实验数据
theta_degrees = [90, 80, 70, 60, 50, 40, 30, 20, 10, 0]; % 夹角θ(度)
I_measured = [0.01, 0.25, 0.81, 1.92, 3.02, 4.21, 4.87, 5.81, 6.92, 7.18]; % 光电流值(×10^-7 A)

% 计算cos^2(θ)
cos2_theta = cosd(theta_degrees).^2;

% 最小二乘法拟合 I = I0*cos^2(θ) + b
X = [cos2_theta', ones(length(cos2_theta), 1)];
coeffs = X\I_measured';
I0 = coeffs(1);
b = coeffs(2);

% 计算拟合值
I_fitted = I0 * cos2_theta + b;

% 计算相关系数 R^2
SS_total = sum((I_measured - mean(I_measured)).^2);
SS_residual = sum((I_measured - I_fitted).^2);
R_squared = 1 - SS_residual/SS_total;

% 创建拟合曲线的平滑版本(用于绘图)
theta_smooth = linspace(0, 90, 100);
cos2_theta_smooth = cosd(theta_smooth).^2;
I_fitted_smooth = I0 * cos2_theta_smooth + b;

% 绘图
figure('Position', [100, 100, 800, 600]);

% 绘制实验数据点和拟合曲线
plot(cos2_theta, I_measured, 'ro', 'MarkerSize', 8, 'LineWidth', 1.5, 'DisplayName', '实验数据');
hold on;
plot(cos2_theta_smooth, I_fitted_smooth, 'b-', 'LineWidth', 2, 'DisplayName', '拟合曲线');

% 添加网格和图例
grid on;
legend('Location', 'northwest');

% 设置坐标轴标签和标题
xlabel('cos^2\theta', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('光强 I (×10^{-7} A)', 'FontSize', 12, 'FontWeight', 'bold');
title('光强 I 与 cos^2\theta 的关系 - 马吕斯定律验证', 'FontSize', 14, 'FontWeight', 'bold');

% 添加拟合方程和相关系数的文本说明
equation = sprintf('I = %.2f·cos^2\\theta + %.2f', I0, b);
r2_text = sprintf('R^2 = %.4f', R_squared);
text(0.1, 0.8*max(I_measured), equation, 'FontSize', 12);
text(0.1, 0.7*max(I_measured), r2_text, 'FontSize', 12);

% 输出拟合结果
fprintf('拟合结果:\n');
fprintf('I0 = %.4f (×10^-7 A)\n', I0);
fprintf('b = %.4f (×10^-7 A)\n', b);
fprintf('R^2 = %.4f\n', R_squared);

% 保存图像
saveas(gcf, 'malus_law_fitting.png');
saveas(gcf, 'malus_law_fitting.fig');

% 计算数据表格并显示
disp('数据比较表:');
disp('角度(θ) | 实测光强(I) | cos^2(θ) | 拟合光强 | 相对误差(%)');
disp('---------------------------------------------------------');
for i = 1:length(theta_degrees)
    relative_error = abs(I_fitted(i) - I_measured(i))/I_measured(i) * 100;
    if isinf(relative_error)
        error_str = 'N/A';
    else
        error_str = sprintf('%.2f%%', relative_error);
    end
    fprintf('%6.1f° | %10.2f | %8.3f | %9.2f | %s\n', ...
        theta_degrees(i), I_measured(i), cos2_theta(i), I_fitted(i), error_str);
end

% 也可以计算葡萄糖溶液的旋光率
% 下面是葡萄糖旋光率计算的代码（按照报告中的数据）
fprintf('\n葡萄糖溶液旋光率计算:\n');

% 角度数据（度-分格式）
rotation_data = [
    12 + 8/60;  % 12°8'
    10 + 20/60; % 10°20'
    11 + 28/60; % 11°28'
    12 + 16/60; % 12°16'
    11 + 44/60  % 11°44'
];

% 计算平均旋光角
avg_rotation = mean(rotation_data);
avg_rotation_deg = floor(avg_rotation);
avg_rotation_min = round((avg_rotation - avg_rotation_deg) * 60);

fprintf('平均旋光角: %.3f° = %d°%d\n', avg_rotation, avg_rotation_deg, avg_rotation_min);

% 计算旋光率
length_cm = 15.0;
concentration = 0.25; % g/ml
specific_rotation = avg_rotation / (length_cm * concentration);
specific_rotation_dm = specific_rotation * 10; % 转换为 °·dm^-1·(g/ml)^-1

fprintf('旋光率: %.3f °·cm^-1·(g/ml)^-1 = %.1f °·dm^-1·(g/ml)^-1\n', ...
    specific_rotation, specific_rotation_dm);