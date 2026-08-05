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
data = np.loadtxt("data.csv", delimiter=",")
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
# （未完成）
    
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
