import cv2
import numpy as np

image = cv2.imread("1.jpg", cv2.IMREAD_COLOR)

scale_factor = 0.1  
small_img = cv2.resize(image, (0, 0), fx=scale_factor, fy=scale_factor, interpolation=cv2.INTER_NEAREST)
restored_img = cv2.resize(small_img, (image.shape[1], image.shape[0]), interpolation=cv2.INTER_NEAREST)
cv2.imwrite("output_lowres.jpg", restored_img)  

image = cv2.imread("1.jpg", cv2.IMREAD_GRAYSCALE)

levels = 4 
quantized_img = (image // (256 // levels)) * (256 // levels)
cv2.imwrite("output_quantized.jpg", quantized_img)  
