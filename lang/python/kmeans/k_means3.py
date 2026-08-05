# 2次元プロットデータ（3クラス）のデータを読み込んで，k-means法でクラスタリングする
import numpy as np

# 2点間距離を測る関数
def distance(a, b):
    dist = 0.0
    for i in range(len(a)):
        dist += (a[i] - b[i])**2
    dist = np.sqrt(dist)
    
    return dist


# データを読み込む
data = np.loadtxt("data2.csv", delimiter=",")
cluster = []
for i in (range(len(data))):
    cluster.append(0)

# クラスターサイズを決定する
NUM = 3

# クラスターの重心をランダムに決定する
# (本当はデータの中からランダムに3つ選ぶけど、最初の3個でよくね？)
center = []
center.append(data[0])
center.append(data[1])
center.append(data[2])

# k-meansの反復回数
MAX_ITER = 100
 
for it in range(MAX_ITER):
 
    # データ毎に各クラスタとの距離を求める
    for i in range(len(data)):
 
        mindist = 99999
        for j in range(0, NUM):
            dist = distance(center[j], data[i])
            if dist<mindist:
                mindist = dist
                index = j
        cluster[i] = index
 
    # 重心を計算する
    new_center = []
    for j in range(NUM):
        # クラスタjに属するデータだけを集める
        points = []
        for i in range(len(data)):
            if cluster[i] == j:
                points.append(data[i])
 
        if len(points) == 0:
            # そのクラスタに属するデータが1つもない場合は、重心を変えない
            new_center.append(center[j])
        else:
            # クラスタに属する点の平均座標を新しい重心にする
            points = np.array(points)
            new_center.append(points.mean(axis=0))
 
    # 重心が変化しなくなったら収束したとみなして終了
    diff = 0.0
    for j in range(NUM):
        diff += distance(center[j], new_center[j])
 
    center = new_center
 
    if diff < 1e-6:
#        print(f"{it+1} count")
        break
    
# プロットする
import matplotlib.pyplot as plt

for i in range(len(data)):
    if cluster[i]==0:
        plt.scatter(data[i,0], data[i,1], color='r', marker='o', s=20)
    elif cluster[i]==1:
        plt.scatter(data[i,0], data[i,1], color='g', marker='o', s=20)
    else:
        plt.scatter(data[i,0], data[i,1], color='b', marker='o', s=20)
        
# グリッド表示
plt.grid(True)

# 表示
plt.show()
