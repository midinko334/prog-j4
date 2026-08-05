# 多次元CSVデータに対応したk-means法によるクラスタリング
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# ========= 設定（ここを書き換えて使う） =========
CSV_PATH = "pokemon_kmeans_gen.csv"     # 読み込むCSVファイル
LABEL_COL = None          # 名前など、ラベルとして使う列（クラスタリングには使わない）。無ければ None
FEATURE_COLS = None       # クラスタリングに使う列名のリスト。None なら数値列を自動選択
NUM = 3                   # クラスタ数
STANDARDIZE = True        # 標準化するか（列ごとに値のスケールが違う場合は True 推奨）
MAX_ITER = 100            # 反復回数の上限
RANDOM_SEED = 0           # 初期重心を選ぶ際の乱数シード
# ===============================================


# 2点間距離を測る関数（何次元でもそのまま使える）
def distance(a, b):
    dist = 0.0
    for i in range(len(a)):
        dist += (a[i] - b[i])**2
    dist = np.sqrt(dist)

    return dist


# ---------- データを読み込む ----------
# encoding="utf-8-sig" で先頭のBOM付きCSVにも対応
df = pd.read_csv(CSV_PATH, encoding="utf-8-sig")

if FEATURE_COLS is None:
    # 数値列だけを自動でクラスタリング対象にする
    feature_cols = df.select_dtypes(include=[np.number]).columns.tolist()
    # "No" や "ID" のような通し番号列は特徴量から除外する
    feature_cols = [c for c in feature_cols if c.lower() not in ("no", "id")]
else:
    feature_cols = FEATURE_COLS

print("Using column for clustering:", feature_cols)

labels = df[LABEL_COL].values if LABEL_COL else None
data_raw = df[feature_cols].values.astype(float)

# ---------- 標準化 ----------
# 列ごとに値の大きさが全然違う（例：人口 vs 高齢化率）と
# 大きい値の列にクラスタリングが引っ張られてしまうため、平均0・標準偏差1にそろえる
if STANDARDIZE:
    mean = data_raw.mean(axis=0)
    std = data_raw.std(axis=0)
    std[std == 0] = 1  # ゼロ割り防止
    data = (data_raw - mean) / std
else:
    data = data_raw.copy()

N = len(data)
cluster = [0] * N

# ---------- クラスターの重心を決定する ----------
# データの中からランダムにNUM個選ぶ（RANDOM_SEEDで再現可能）
rng = np.random.default_rng(RANDOM_SEED)
init_idx = rng.choice(N, NUM, replace=False)
center = [data[i] for i in init_idx]

# ---------- k-means本体 ----------
for it in range(MAX_ITER):

    # データ毎に各クラスタとの距離を求め、一番近い重心のクラスタに割り当てる
    for i in range(N):
        mindist = 99999
        for j in range(NUM):
            dist = distance(center[j], data[i])
            if dist < mindist:
                mindist = dist
                index = j
        cluster[i] = index

    # 重心を計算する
    new_center = []
    for j in range(NUM):
        points = [data[i] for i in range(N) if cluster[i] == j]
        if len(points) == 0:
            # 属するデータが無いクラスタは重心を変えない
            new_center.append(center[j])
        else:
            new_center.append(np.mean(points, axis=0))

    # 重心の移動量を確認し、ほぼ動かなくなったら収束とみなす
    diff = sum(distance(center[j], new_center[j]) for j in range(NUM))
    center = new_center

    if diff < 1e-6:
#        print(f"{it + 1} count")
        break

cluster = np.array(cluster)

# ---------- プロット用の2次元データを作る ----------
if data.shape[1] == 2:
    # 元々2次元ならそのまま（見やすいよう標準化前の値で表示）
    plot_data = data_raw
    xlabel, ylabel = feature_cols
else:
    # 3次元以上の場合はPCA（主成分分析）で2次元に圧縮して可視化する
    data_c = data - data.mean(axis=0)
    cov = np.cov(data_c, rowvar=False)
    eigvals, eigvecs = np.linalg.eigh(cov)
    order = np.argsort(eigvals)[::-1]
    top2 = eigvecs[:, order[:2]]
    plot_data = data_c @ top2
    xlabel, ylabel = "PC1（第1主成分）", "PC2（第2主成分）"

# ---------- プロットする ----------
colors = plt.cm.tab10(np.linspace(0, 1, NUM))

for j in range(NUM):
    idx = (cluster == j)
    plt.scatter(plot_data[idx, 0], plot_data[idx, 1],
                color=colors[j], marker='o', s=20, label=f"cluster {j}")

plt.xlabel(xlabel)
plt.ylabel(ylabel)
plt.legend()

# グリッド表示
plt.grid(True)

# 表示
plt.show()
