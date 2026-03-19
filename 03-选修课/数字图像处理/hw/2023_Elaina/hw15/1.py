import cv2
import numpy as np

img_rgb = cv2.imread('1.png')
img_rgb = cv2.cvtColor(img_rgb, cv2.COLOR_BGR2RGB)
img_hsv = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2HSV)

# 天空分割
lower_sky = np.array([90, 50, 100])
upper_sky = np.array([130, 255, 255])
sky_mask = cv2.inRange(img_hsv, lower_sky, upper_sky)
sky_result = np.zeros_like(img_rgb)
sky_result[sky_mask > 0] = img_rgb[sky_mask > 0]

# 花朵增强：红色区间（包括低H值和高H值两个区间）
lower_red1 = np.array([0, 100, 100])
upper_red1 = np.array([10, 255, 255])
lower_red2 = np.array([160, 100, 100])
upper_red2 = np.array([180, 255, 255])

mask1 = cv2.inRange(img_hsv, lower_red1, upper_red1)
mask2 = cv2.inRange(img_hsv, lower_red2, upper_red2)
flower_mask = cv2.bitwise_or(mask1, mask2)

h, s, v = cv2.split(img_hsv)
s_enhanced = s.copy()
s_enhanced[flower_mask > 0] = np.clip(s[flower_mask > 0] * 1.3, 0, 255).astype(np.uint8)

hsv_enhanced = cv2.merge([h, s_enhanced, v])
img_flower_enhanced = cv2.cvtColor(hsv_enhanced, cv2.COLOR_HSV2RGB)

# 绿色背景融合
green_background = np.full_like(img_rgb, (0, 255, 0))
sky_combined = green_background.copy()
sky_combined[sky_mask > 0] = img_rgb[sky_mask > 0]

# 保存结果
cv2.imwrite('output_hsv.jpg', img_hsv)
cv2.imwrite('output_sky_segmented.jpg', cv2.cvtColor(sky_result, cv2.COLOR_RGB2BGR))
cv2.imwrite('output_flower_enhanced.jpg', cv2.cvtColor(img_flower_enhanced, cv2.COLOR_RGB2BGR))
cv2.imwrite('output_sky_green_combined.jpg', cv2.cvtColor(sky_combined, cv2.COLOR_RGB2BGR))
