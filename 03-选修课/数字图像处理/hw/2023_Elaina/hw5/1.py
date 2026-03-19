import cv2
import numpy as np

# 读取图像
image = cv2.imread("1.jpg")

# 负片变换
negative_image = 255 - image

# Log 变换
c = 255 / np.log(1 + np.max(image))  # 计算缩放因子
log_transformed = c * np.log(1 + image.astype(np.float32))
log_transformed = np.clip(log_transformed, 0, 255).astype(np.uint8)

# Nth-Power 变换
gamma_r_greater = 2.0  # r > 1 时的 gamma 值
gamma_r_smaller = 0.5  # r < 1 时的 gamma 值
image_float = image.astype(np.float32) / 255  # 归一化到 [0,1]

# r > 1 情况
power_transformed_greater = np.power(image_float, gamma_r_greater) * 255
power_transformed_greater = np.clip(power_transformed_greater, 0, 255).astype(np.uint8)

# r < 1 情况
power_transformed_smaller = np.power(image_float, gamma_r_smaller) * 255
power_transformed_smaller = np.clip(power_transformed_smaller, 0, 255).astype(np.uint8)

# 分段线性变换 (Piecewise-Linear Transformation)
# 设定两个控制点 P1=(a, b), P2=(c, d)
a, b = 50, 30   # 输入 a 映射到 b
c, d = 200, 220 # 输入 c 映射到 d

piecewise_transformed = np.zeros_like(image, dtype=np.uint8)

# 计算变换
mask1 = (image <= a)
mask2 = (image > a) & (image <= c)
mask3 = (image > c)

piecewise_transformed[mask1] = (b / a) * image[mask1]
piecewise_transformed[mask2] = ((d - b) / (c - a)) * (image[mask2] - a) + b
piecewise_transformed[mask3] = ((255 - d) / (255 - c)) * (image[mask3] - c) + d

# 保存所有处理后的图像
cv2.imwrite("negative_1.jpg", negative_image)
cv2.imwrite("log_transformed_1.jpg", log_transformed)
cv2.imwrite("power_transformed_greater.jpg", power_transformed_greater)
cv2.imwrite("power_transformed_smaller.jpg", power_transformed_smaller)
cv2.imwrite("piecewise_transformed.jpg", piecewise_transformed)
