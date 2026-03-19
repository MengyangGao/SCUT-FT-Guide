import cv2

image = cv2.imread("1.jpg", cv2.IMREAD_COLOR)

scale_up = 2.0   
scale_down = 0.5 

zoom_nn = cv2.resize(image, (0, 0), fx=scale_up, fy=scale_up, interpolation=cv2.INTER_NEAREST)
shrink_nn = cv2.resize(image, (0, 0), fx=scale_down, fy=scale_down, interpolation=cv2.INTER_NEAREST)

zoom_bilinear = cv2.resize(image, (0, 0), fx=scale_up, fy=scale_up, interpolation=cv2.INTER_LINEAR)
shrink_bilinear = cv2.resize(image, (0, 0), fx=scale_down, fy=scale_down, interpolation=cv2.INTER_LINEAR)

cv2.imwrite("zoom_nearest.jpg", zoom_nn)       
cv2.imwrite("shrink_nearest.jpg", shrink_nn)   
cv2.imwrite("zoom_bilinear.jpg", zoom_bilinear) 
cv2.imwrite("shrink_bilinear.jpg", shrink_bilinear) 
