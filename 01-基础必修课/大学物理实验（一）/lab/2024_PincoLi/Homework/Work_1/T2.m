%% 清空环境
clear; clc;

%% 1. 原始测量数据
I_data = [9.58, 9.56, 9.50, 9.53, 9.60, 9.40, 9.57, 9.62, 9.32, 9.56]; 
n = length(I_data);

%% 2. 计算算术平均值（临时变量）
I_mean_initial = mean(I_data);

%% 7. 改进的Grubbs检验（α=0.1，持续剔除）%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
current_data = I_data; % 初始化当前数据集
outliers = [];         % 存储被剔除的异常值

% Grubbs临界值表（α=0.1，双侧检验）
grubbs_table = [
    4, 1.49;
    5, 1.75;
    6, 1.94;
    7, 2.10;
    8, 2.22;
    9, 2.32;
    10, 2.41;
    11, 2.48;
    12, 2.55;
];

while true
    current_n = length(current_data);
    if current_n < 3  % Grubbs检验要求n≥3
        fprintf('样本量不足，终止检验。\n');
        break;
    end
    
    % 计算当前统计量
    current_mean = mean(current_data);
    current_std  = std(current_data);
    [max_diff, idx] = max(abs(current_data - current_mean));
    G_value = max_diff / current_std;
    
    % 获取临界值
    idx_table = find(grubbs_table(:,1) == current_n, 1);
    if isempty(idx_table)
        error('n=%d 的Grubbs临界值未定义，请补充表格。', current_n);
    end
    G_crit = grubbs_table(idx_table, 2);
    
    % 判断是否剔除
    if G_value > G_crit
        outliers = [outliers, current_data(idx)]; % 记录异常值
        current_data(idx) = [];                   % 剔除异常值
        fprintf('剔除异常值 %.2f mA (n=%d → %d)\n', outliers(end), current_n, current_n-1);
    else
        fprintf('Grubbs检验通过，无异常值。\n');
        break;
    end
end

% 更新数据集
I_data = current_data;
n = length(I_data);
fprintf('最终保留数据量: %d\n', n);
if ~isempty(outliers)
    fprintf('已剔除异常值: ');
    fprintf('%.2f ', outliers);
    fprintf('mA\n');
end

%% 重新计算剔除后的指标%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if n < 2
    error('数据量不足，无法计算不确定度。');
end

%% 2. 计算算术平均值（更新后）
I_mean = mean(I_data);

%% 3. 计算样本标准差与A类不确定度
s = std(I_data);
u_A = s / sqrt(n);

%% 4. B类不确定度（保持不变）
u_B = 0.05 / sqrt(3);

%% 5. 合成不确定度
u_C = sqrt(u_A^2 + u_B^2);

%% 6. 3σ检查（基于新数据）
threshold_3sigma = 3 * s;
maxDiff = max(abs(I_data - I_mean));
fprintf('\n3σ阈值 = %.3f mA, 最大偏差 = %.3f mA\n', threshold_3sigma, maxDiff);
if maxDiff > threshold_3sigma
    fprintf('警告：存在超过3σ的可疑值，但Grubbs检验已通过。\n');
end

%% 8. 最终结果
I_mean_rounded = round(I_mean, 2);
u_C_rounded = round(u_C, 2);
fprintf('\n===== 测量结果 =====\n');
fprintf('I = (%.2f ± %.2f) mA (k=1)\n', I_mean_rounded, u_C_rounded);
fprintf('=========================\n');