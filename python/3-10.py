sname=input('file name:')
with open(sname, 'r', encoding='utf-8') as f:
  s = f.read()
ln=len(s)
n=''
for i in range(0,ln):
  if 'A'<=s[i] and s[i]<='Z':
    n=n+chr(ord(s[i])-ord('A')+ord('a'))
  else :
    n=n+s[i]


num=int(input('input num:'))
if num>10 or num<3:
  print('error')
  exit()
word=[]
flag=0
time=[]

for i in range(0,ln):
  flag=1
  lw=len(word)
  for j in range(0,lw):
    if word[j]==n[i:i+num]:
      time[j]=time[j]+1
      flag=0
  if flag==1:
    word.append(n[i:i+num])
    time.append(1)

most=0
for i in range(0,len(word)):
  if time[i]>time[most]:
    most=i

print(f'most appearancing:{word[most]}/{time[most]} times')
