%% 迈克尔逊干涉仪 —— 干涉图样模拟

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

%% ================= 参数设置 =================
lambda = 632.8e-9; % He-Ne激光波长 (m)
d0 = 10e-6;        % 空气层厚度 (m)，约10微米

% 网格大小
N = 800;
x = linspace(-1, 1, N);
y = linspace(-1, 1, N);
[X, Y] = meshgrid(x, y);

%% ================= 等倾干涉（同心圆环）=================
% 当M1、M2平行时
% 光程差 δ = 2*d*cos(i)
% 其中 i 是入射角，与距离中心的半径相关

% 距离中心的半径
R = sqrt(X.^2 + Y.^2);

% 入射角（小角度近似）
theta_max = 0.1; % 最大入射角约5.7度
theta = theta_max * R; % 入射角随半径线性增加

% 光程差
delta_equal_incline = 2 * d0 * cos(theta);

% 相位差
phi_equal_incline = 2 * pi * delta_equal_incline / lambda;

% 光强分布（余弦平方）
I_equal_incline = cos(phi_equal_incline / 2).^2;

% 创建圆形遮罩
mask = R <= 1;
I_equal_incline = I_equal_incline .* mask;

%% ================= 等厚干涉（平行条纹）=================
% 当M1、M2有微小倾角时
% 空气层厚度沿x方向线性变化

% 倾角（弧度）
alpha = 5e-4; % 很小的倾角

% 空气层厚度沿x方向变化
d_wedge = d0 + alpha * X * 1e-3; % 楔形空气层

% 光程差（垂直入射，i≈0）
delta_equal_thick = 2 * d_wedge;

% 相位差
phi_equal_thick = 2 * pi * delta_equal_thick / lambda;

% 光强分布
I_equal_thick = cos(phi_equal_thick / 2).^2;

% 应用圆形遮罩
I_equal_thick = I_equal_thick .* mask;

%% ================= 绘图：等倾干涉 =================
figure('Name','等倾干涉','Color','w','Position',[100 100 900 700]);

subplot(1,2,1);
imagesc(x, y, I_equal_incline);
axis equal tight;
colormap(hot);
colorbar;
title('等倾干涉图样（M_1 // M_2）', 'FontSize', 14);
xlabel('x (相对位置)', 'FontSize', 12);
ylabel('y (相对位置)', 'FontSize', 12);
set(gca, 'YDir', 'normal');

% 添加说明文本
dim = [.15 .72 .2 .15];
str = {sprintf('空气层厚度：d = %.1f μm', d0*1e6), ...
       sprintf('波长：λ = %.1f nm', lambda*1e9), ...
       '特征：同心圆环'};
annotation('textbox',dim,'String',str,'FitBoxToText','on',...
           'BackgroundColor','w','EdgeColor','k','FontSize',10);

% 3D视图
subplot(1,2,2);
surf(X, Y, I_equal_incline, 'EdgeColor', 'none');
view(45, 60);
colormap(hot);
colorbar;
title('等倾干涉光强分布（3D）', 'FontSize', 14);
xlabel('x', 'FontSize', 12);
ylabel('y', 'FontSize', 12);
zlabel('归一化光强', 'FontSize', 12);
xlim([-1 1]); ylim([-1 1]);
lighting gouraud;
camlight;

% 保存
saveas(gcf, 'assets/图3_等倾干涉模拟.png');

%% ================= 绘图：等厚干涉 =================
figure('Name','等厚干涉','Color','w','Position',[150 150 900 700]);

subplot(1,2,1);
imagesc(x, y, I_equal_thick);
axis equal tight;
colormap(hot);
colorbar;
title('等厚干涉图样（M_1与M_2有微小夹角）', 'FontSize', 14);
xlabel('x (相对位置)', 'FontSize', 12);
ylabel('y (相对位置)', 'FontSize', 12);
set(gca, 'YDir', 'normal');

% 添加说明文本
dim = [.15 .72 .2 .15];
str = {sprintf('初始厚度：d_0 = %.1f μm', d0*1e6), ...
       sprintf('楔角：α = %.1e rad', alpha), ...
       '特征：平行直条纹'};
annotation('textbox',dim,'String',str,'FitBoxToText','on',...
           'BackgroundColor','w','EdgeColor','k','FontSize',10);

% 3D视图
subplot(1,2,2);
surf(X, Y, I_equal_thick, 'EdgeColor', 'none');
view(45, 60);
colormap(hot);
colorbar;
title('等厚干涉光强分布（3D）', 'FontSize', 14);
xlabel('x', 'FontSize', 12);
ylabel('y', 'FontSize', 12);
zlabel('归一化光强', 'FontSize', 12);
xlim([-1 1]); ylim([-1 1]);
lighting gouraud;
camlight;

% 保存
saveas(gcf, 'assets/图4_等厚干涉模拟.png');

%% ================= 综合对比图 =================
figure('Name','干涉类型对比','Color','w','Position',[200 200 1200 500]);

subplot(1,2,1);
imagesc(x, y, I_equal_incline);
axis equal tight;
colormap(hot);
title('(a) 等倾干涉', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('x', 'FontSize', 12);
ylabel('y', 'FontSize', 12);
set(gca, 'YDir', 'normal');
text(0, -1.15, 'M_1 // M_2，形成同心圆环', ...
     'HorizontalAlignment', 'center', 'FontSize', 11);

subplot(1,2,2);
imagesc(x, y, I_equal_thick);
axis equal tight;
colormap(hot);
title('(b) 等厚干涉', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('x', 'FontSize', 12);
ylabel('y', 'FontSize', 12);
set(gca, 'YDir', 'normal');
text(0, -1.15, 'M_1与M_2有微小夹角，形成平行条纹', ...
     'HorizontalAlignment', 'center', 'FontSize', 11);

% 保存
saveas(gcf, 'assets/图5_干涉类型对比.png');

fprintf('\n干涉图样模拟完成！\n');
fprintf('已生成以下图片：\n');
fprintf('  - assets/图3_等倾干涉模拟.png\n');
fprintf('  - assets/图4_等厚干涉模拟.png\n');
fprintf('  - assets/图5_干涉类型对比.png\n\n');
