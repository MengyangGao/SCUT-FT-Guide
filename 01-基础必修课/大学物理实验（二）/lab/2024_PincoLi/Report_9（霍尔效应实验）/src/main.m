%% 霍尔效应实验 —— 数据处理与可视化

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

%% ================= 工具函数 =================
% 对称测量两种算法
vh_absavg  = @(V1,V2,V3,V4) (abs(V1)+abs(V2)+abs(V3)+abs(V4))/4;      % 绝对值平均法
vh_formula = @(V1,V2,V3,V4) (V1 - V2 + V3 - V4)/4;                    % (V1-V2+V3-V4)/4

% 一阶线性拟合与 R^2
linfit = @(x,y) deal(polyfit(x,y,1), ...
    1 - sum((y - polyval(polyfit(x,y,1),x)).^2)/sum((y-mean(y)).^2));

% 拟合结果标注文本
annostr = @(k,b,R2,indep,dep) sprintf('拟合：%s = %.4g × %s + %.4g\nR^2 = %.5f', ...
    dep, k, indep, b, R2);

%% ================= 表1：V_H 随 I_S 关系（I_M = 0.500 A） =================
IS_mA = [1.00, 2.00, 3.00, 4.00, 5.00, 6.00]';     % I_S (mA)
V1_1  = [27.2, 54.1, 81.4,108.2,135.3,162.2]';     % mV
V2_1  = [-27.9,-55.7,-83.5,-111.3,-139.0,-166.7]';
V3_1  = [27.9, 55.6, 83.5,111.2,138.9,166.6]';
V4_1  = [-27.1,-54.2,-81.4,-108.3,-135.2,-162.1]';

% 计算 V_H（两种算法）
VH1_abs = vh_absavg(V1_1,V2_1,V3_1,V4_1);
VH1_for = vh_formula(V1_1,V2_1,V3_1,V4_1);

% 两算法差异（
diff1 = VH1_abs - VH1_for;
IM_fixed = 0.500;            % A（励磁电流固定）

% 线性拟合：V_H = k_IS * I_S + b_IS
[p1, R2_1] = linfit(IS_mA, VH1_abs);
k_IS = p1(1); b_IS = p1(2);

%% ================= 表2：V_H 随 I_M 关系（I_S = 5.00 mA） =================
IM_A = [0.100,0.200,0.300,0.400,0.500,0.600]';     % I_M (A)
V1_2 = [26.6, 54.1, 81.5,108.2,135.0,161.0]';      % mV
V2_2 = [-30.4,-58.0,-85.2,-112.1,-139.0,-164.8]';
V3_2 = [30.4, 57.9, 82.5,112.1,138.8,164.7]';
V4_2 = [-26.5,-54.2,-81.4,-108.3,-135.1,-161.0]';

VH2_abs = vh_absavg(V1_2,V2_2,V3_2,V4_2);
VH2_for = vh_formula(V1_2,V2_2,V3_2,V4_2);
diff2   = VH2_abs - VH2_for;
IS_fixed = 5.00;             % mA（工作电流固定）

% 线性拟合：V_H = k_IM * I_M + b_IM
[p2, R2_2] = linfit(IM_A, VH2_abs);
k_IM = p2(1); b_IM = p2(2);

%% ================= 表3：V_H 的空间分布（X 方向） =================
X_mm = [0,5,10,15,20,25,30,35,40]';               % 位置 X (mm)
V1_3 = [23.6, 66.2,135.4,134.4,135.0,135.1,135.0,134.2, 84.0]';
V2_3 = [-27.4,-70.3,-139.2,-138.3,-138.8,-138.8,-138.7,-138.0,-87.8]';
V3_3 = [27.4, 70.2,139.5,138.2,138.8,138.8,138.7,137.9, 87.9]';
V4_3 = [-23.6,-66.6,-135.6,-134.4,-135.1,-135.1,-135.0,-134.2,-84.1]';

VH3_abs = vh_absavg(V1_3,V2_3,V3_3,V4_3);
VH3_for = vh_formula(V1_3,V2_3,V3_3,V4_3);

% 中心区域统计：X=10~35 mm
center_mask = (X_mm>=10 & X_mm<=35);
VH_center_mean = mean(VH3_abs(center_mask));
VH_center_std  = std(VH3_abs(center_mask), 0);   % 样本标准差

%% ================= 灵敏度与激励系数计算 =================
% 理论：V_H = K_H * I_S * K_M * I_M
% 因此：
%   k_IS (mV/mA) = K_H * K_M * I_M (A)
%   k_IM (mV/A)  = K_H * K_M * I_S (mA)
KH_times_KM_from_IS = k_IS / IM_fixed;          % mV/(mA·A)
KH_times_KM_from_IM = k_IM / IS_fixed;          % mV/(mA·A)
KH_times_KM_mean    = mean([KH_times_KM_from_IS, KH_times_KM_from_IM]);

% 若 K_M 已知（例如 0.02 T/A），可求 K_H（mV/(mA·T) 与 V/(A·T)）
KM_assumed = 0.02; % T/A（可按标定值修改）
KH_mV_per_mA_T = KH_times_KM_mean / KM_assumed;      % mV/(mA·T)
KH_V_per_A_T   = KH_mV_per_mA_T / 10;                % 1 mV/mA = 0.01 V/A

%% ================= 关键结果打印（中文） =================
fprintf('=== 线性拟合结果 ===\n');
fprintf('V_H–I_S： 斜率 k_IS = %.4f mV/mA,  截距 b_IS = %.4f mV,  R^2 = %.5f\n', k_IS, b_IS, R2_1);
fprintf('V_H–I_M： 斜率 k_IM = %.4f mV/A ,  截距 b_IM = %.4f mV,  R^2 = %.5f\n', k_IM, b_IM, R2_2);

fprintf('\n=== 对称测量两算法差异（最大绝对差） ===\n');
fprintf('表1：max |Δ(VH_abs - VH_formula)| = %.4g mV\n', max(abs(diff1)));
fprintf('表2：max |Δ(VH_abs - VH_formula)| = %.4g mV\n', max(abs(diff2)));

fprintf('\n=== 灵敏度乘积（K_H · K_M） ===\n');
fprintf('由 k_IS 得：K_H · K_M = %.4f mV/(mA·A)\n', KH_times_KM_from_IS);
fprintf('由 k_IM 得：K_H · K_M = %.4f mV/(mA·A)\n', KH_times_KM_from_IM);
fprintf('平均值      ：K_H · K_M = %.4f mV/(mA·A)\n', KH_times_KM_mean);

fprintf('\n假设 K_M = %.4f T/A：\n', KM_assumed);
fprintf('K_H ≈ %.4f mV/(mA·T)  （%.4f V/(A·T)）\n', KH_mV_per_mA_T, KH_V_per_A_T);

%% ================= 绘图1：V_H–I_S（I_M = 0.500 A） =================
figure('Name','V_H–I_S','Color','w');
scatter(IS_mA, VH1_abs, 40, 'filled'); hold on;
xx = linspace(min(IS_mA), max(IS_mA), 200);
plot(xx, polyval(p1,xx), '-');
grid on; box on;
title('霍尔电压随工作电流的变化（I_M = 0.500 A）');
xlabel('工作电流 I_S（mA）');
ylabel('霍尔电压 V_H（mV）');
txt1 = annostr(k_IS, b_IS, R2_1, 'I_S', 'V_H');
text(min(IS_mA)+0.2, max(VH1_abs)-0.08*(range(VH1_abs)), txt1, 'Interpreter','none');
legend({'实验数据','线性拟合'}, 'Location','best');

%% ================= 绘图2：V_H–I_M（I_S = 5.00 mA） =================
figure('Name','V_H–I_M','Color','w');
scatter(IM_A, VH2_abs, 40, 'filled'); hold on;
xx = linspace(min(IM_A), max(IM_A), 200);
plot(xx, polyval(p2,xx), '-');
grid on; box on;
title('霍尔电压随励磁电流的变化（I_S = 5.00 mA）');
xlabel('励磁电流 I_M（A）');
ylabel('霍尔电压 V_H（mV）');
txt2 = annostr(k_IM, b_IM, R2_2, 'I_M', 'V_H');
text(min(IM_A)+0.02, max(VH2_abs)-0.08*(range(VH2_abs)), txt2, 'Interpreter','none');
legend({'实验数据','线性拟合'}, 'Location','best');

%% ================= 绘图3：V_H–X 空间分布 =================
figure('Name','V_H–X','Color','w');
plot(X_mm, VH3_abs, 'o-'); grid on; box on;
title('霍尔电压的空间分布（I_M = 0.500 A，I_S = 5.00 mA）');
xlabel('位置 X（mm）');
ylabel('霍尔电压 V_H（mV）');

% 高亮中心区域（X=10~35 mm）
yl = ylim;
p = patch([10 35 35 10], [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], ...
      'EdgeColor','none','FaceAlpha',0.3);
uistack(p,'bottom');
legend({'V_H（绝对值平均法）','中心区域（10–35 mm）'}, 'Location','best');

% 在图中标注中心区统计量
text(12, yl(1)+0.85*range(yl), sprintf('中心区均值 = %.2f mV\n中心区标准差 = %.2f mV', ...
     VH_center_mean, VH_center_std), 'Interpreter','none');

% %% ================= 可选：保存图片（按需开启） =================
% print('-dpng','-r300','图1_VH_vs_IS.png');
% print('-dpng','-r300','图2_VH_vs_IM.png');
% print('-dpng','-r300','图3_VH_vs_X.png');

