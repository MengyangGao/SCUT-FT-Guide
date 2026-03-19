import cv2
import numpy as np

def add_white_noise(image_path, noise_level=0.5):
    # 读取图像
    image = cv2.imread(image_path, )
    
    if image is None:
        print("Error: Unable to load image.")
        return
    
    # 生成与图像相同大小的白噪声
    noise = np.random.normal(0, noise_level, image.shape).astype(np.uint8)
    
    # 添加噪声并限制像素值范围
    noisy_image = cv2.add(image, noise)
    
    # 显示原始和噪声图像
    cv2.imwrite("noise.jpg", noisy_image)
    cv2.waitKey(0)
    cv2.destroyAllWindows()
    
    return noisy_image

# 示例使用
image_path = "1.jpg"  # 替换为你的图像路径
noisy_img = add_white_noise(image_path)
