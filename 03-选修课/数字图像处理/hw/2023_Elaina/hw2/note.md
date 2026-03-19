# HW2

## 代码

本代码使用 OpenCV 中的 Haar 特征分类器进行人脸识别，代码如下

```Python
import cv2

face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

image = cv2.imread('1.jpg')  

gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))

for (x, y, w, h) in faces:
    cv2.rectangle(image, (x, y), (x+w, y+h), (255, 0, 0), 2) 

cv2.imwrite("result.jpg", image)
```

## 结果

识别结果如下：

<img src="./result.JPG" style="zoom:50%;" />