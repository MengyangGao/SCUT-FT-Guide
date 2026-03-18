clear; clc; close all;

%% 第一组数据：改变Rw时的输出电压和纹波
Rw = [0, 30, 60, 90, 100, 200, 400, 600]; % 欧姆
Uo = [5.04, 6.64, 8.27, 9.85, 10.3, 13.4, 13.8, 14.0]; % V
Vpp = [40.0, 80.0, 80.0, 80.0, 160, 2320, 1840, 1440]; % mV

%% 第二组数据：初始输入正弦波
U_input = 12.8; % V
Vpp_input = 36.0; % V

%% 第三组数据：滤波后电压
U_filter = 15.0; % V
Vpp_filter = 2.60; % V (转换为mV: 2600 mV)

%% 第四组数据：输出电阻计算
Rw_test = 90; % 欧姆
U_no_load = 9.87; % V
U_with_load = 9.86; % V
R_load = 200; % 欧姆
R_output = (U_no_load / U_with_load - 1) * R_load;

fprintf('========== 计算结果 ==========\n');
fprintf('输出电阻 Ro = %.4f Ω\n\n', R_output);

%% 计算纹波抑制比（以Rw=90欧为例）
idx_90 = find(Rw == 90);
Vpp_output_90 = Vpp(idx_90); % mV
Vpp_filter_mV = 2600; % mV
Sinp = 20 * log10(Vpp_filter_mV / Vpp_output_90);
fprintf('纹波抑制比 (Rw=90Ω): Sinp = %.2f dB\n', Sinp);
fprintf('输入纹波 Vpp = %.2f mV\n', Vpp_filter_mV);
fprintf('输出纹波 Vpp = %.2f mV\n\n', Vpp_output_90);

%% 绘图1：输出电压与Rw的关系
figure('Color','w', 'Position', [100, 100, 800, 600]);
plot(Rw, Uo, 'ro-', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'LineWidth', 2);
grid on;
xlabel('调节电阻 R_w (\Omega)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('输出电压 U_o (V)', 'FontSize', 14, 'FontWeight', 'bold');
title('输出电压与调节电阻的关系', 'FontSize', 16, 'FontWeight', 'bold');
xlim([0, 650]);
ylim([4, 15]);

% 标注关键点
text(90, 9.85+0.5, sprintf('(90Ω, %.2fV)', 9.85), 'FontSize', 11, ...
    'HorizontalAlignment', 'center', 'BackgroundColor', 'w', 'EdgeColor', 'k');

%% 绘图2：输出纹波与Rw的关系
figure('Color','w', 'Position', [150, 150, 800, 600]);
semilogy(Rw, Vpp, 'bs-', 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'LineWidth', 2);
grid on;
xlabel('调节电阻 R_w (\Omega)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('输出纹波峰峰值 V_{pp} (mV)', 'FontSize', 14, 'FontWeight', 'bold');
title('输出纹波与调节电阻的关系', 'FontSize', 16, 'FontWeight', 'bold');
xlim([0, 650]);

% 标注关键点
text(90, 80*1.5, sprintf('(90Ω, %.1fmV)', 80.0), 'FontSize', 11, ...
    'HorizontalAlignment', 'center', 'BackgroundColor', 'w', 'EdgeColor', 'k');

%% 计算不同Rw下的纹波抑制比
fprintf('不同Rw下的纹波抑制比：\n');
fprintf('Rw(Ω)\tUo(V)\tVpp(mV)\tSinp(dB)\n');
fprintf('----------------------------------------\n');
for i = 1:length(Rw)
    Sinp_i = 20 * log10(Vpp_filter_mV / Vpp(i));
    fprintf('%d\t%.2f\t%.1f\t%.2f\n', Rw(i), Uo(i), Vpp(i), Sinp_i);
end

%% 保存图片
print(gcf, 'assets/fig_vpp_rw.png', '-dpng', '-r300');
figure(1);
print(gcf, 'assets/fig_uo_rw.png', '-dpng', '-r300');

fprintf('\n图片已保存到 assets/ 目录\n');
