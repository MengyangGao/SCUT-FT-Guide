import cv2
import numpy as np

image = cv2.imread("1.jpg")
if image is None:
    raise ValueError("Image not found. Make sure '1.jpg' exists in the directory.")

grayscale_img = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

cv2.imwrite("grayscale_image.jpg", grayscale_img)

# Problem 1
_, binary_img = cv2.threshold(grayscale_img, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
cv2.imwrite("binary_image.jpg", binary_img)

np.savetxt("binary_values.txt", binary_img, fmt="%d")
np.savetxt("grayscale_values.txt", grayscale_img, fmt="%d")
np.savetxt("rgb_values.txt", image.reshape(-1, 3), fmt="%d")

# Problem 2
def convert_to_4bit(img):
    return np.round(img / 255 * 15).astype(np.uint8) * (255 / 15)

def convert_to_1bit(img):
    _, binary = cv2.threshold(img, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return binary

gray_8bit = grayscale_img 
gray_4bit = convert_to_4bit(grayscale_img)
gray_1bit = convert_to_1bit(grayscale_img)

cv2.imwrite("gray_8bit.jpg", gray_8bit)
cv2.imwrite("gray_4bit.jpg", gray_4bit)
cv2.imwrite("gray_1bit.jpg", gray_1bit)

# Problem 3
binary_inverted = cv2.bitwise_not(binary_img)
cv2.imwrite("binary_inverted.jpg", binary_inverted)

# Problem 4
def merge_images(binary_img, gray_4bit):
    binary_mask = binary_img > 0  
    
    merged_img = np.zeros_like(gray_4bit) 
    merged_img[binary_mask] = gray_4bit[binary_mask] 
   
    merged_img = cv2.GaussianBlur(merged_img, (5, 5), 0)  
    merged_img[binary_mask] = gray_4bit[binary_mask]  
    
    return merged_img

merged_image = merge_images(gray_1bit, gray_4bit)

cv2.imwrite("merged_image.jpg", merged_image)

