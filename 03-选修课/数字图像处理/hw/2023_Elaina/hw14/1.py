import cv2
import numpy as np

img_rgb = cv2.imread('1.jpg')
img_rgb = cv2.cvtColor(img_rgb, cv2.COLOR_BGR2RGB)
img_hsv = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2HSV)

lower_sky = np.array([90, 50, 100])
upper_sky = np.array([130, 255, 255])
sky_mask = cv2.inRange(img_hsv, lower_sky, upper_sky)
sky_result = np.zeros_like(img_rgb)
sky_result[sky_mask > 0] = img_rgb[sky_mask > 0]

lower_flower = np.array([0, 100, 100])
upper_flower = np.array([10, 255, 255])
flower_mask = cv2.inRange(img_hsv, lower_flower, upper_flower)
enhanced_hsv = img_hsv.copy()
s_channel = enhanced_hsv[:, :, 1]
s_channel[flower_mask > 0] = np.clip(s_channel[flower_mask > 0] * 1.3, 0, 255)
enhanced_hsv[:, :, 1] = s_channel
img_flower_enhanced = cv2.cvtColor(enhanced_hsv, cv2.COLOR_HSV2RGB)

green_background = np.full_like(img_rgb, (0, 255, 0))
sky_combined = green_background.copy()
sky_combined[sky_mask > 0] = img_rgb[sky_mask > 0]

sky_result_bgr = cv2.cvtColor(sky_result, cv2.COLOR_RGB2BGR)
flower_enhanced_bgr = cv2.cvtColor(img_flower_enhanced, cv2.COLOR_RGB2BGR)
sky_combined_bgr = cv2.cvtColor(sky_combined, cv2.COLOR_RGB2BGR)

cv2.imwrite('output_sky_segmented.jpg', sky_result_bgr)
cv2.imwrite('output_flower_enhanced.jpg', flower_enhanced_bgr)
cv2.imwrite('output_sky_green_combined.jpg', sky_combined_bgr)
