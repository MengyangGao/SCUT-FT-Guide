import cv2
import numpy as np

image = cv2.imread("1.jpg", cv2.IMREAD_COLOR)

levels_4bit = 16
image_4bit = (image // (256 // levels_4bit)) * (256 // levels_4bit)
cv2.imwrite("output_4bit.jpg", image_4bit)

gray_image = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
_, image_1bit = cv2.threshold(gray_image, 128, 255, cv2.THRESH_BINARY)  
cv2.imwrite("output_1bit.jpg", image_1bit)
