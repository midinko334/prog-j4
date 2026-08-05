n=input('input word:')
ln=len(n)
word=''
flag=0
time=[]

for i in range(0,ln):
  if n[i]!=' ':
    flag=1
    lw=len(word)
    for j in range(0,lw):
      if word[j]==n[i]:
        time[j]=time[j]+1
        flag=0
    if flag==1:
      word=word+n[i]
      time.append(1)

most=0
for i in range(0,len(word)):
  if time[i]>time[most]:
    most=i

print(f'most appearancing:{word[most]}/{time[most]} times')
