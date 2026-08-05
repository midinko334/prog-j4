import numpy as np

def distance(a, b):
    dist=0.0
    for i in range(len(a)):
	dist+=(a[i]-b[i])**2
    dist=np.sqrt(dist)
    return dist

data=np.loadtxt("data.csv", delimiter=",")

val=np.array([2,3])
dist=distance(val,data[0])
print(dist)
