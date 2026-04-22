n=input('input word:')
ln=len(n)
flag=0
time=[0,0,0,0,0]
bl=0

for i in range(0,ln):
  if n[i]=='a':
    time[0]+=1
  if n[i]=='i':
    time[1]+=1
  if n[i]=='u':
    time[2]+=1
  if n[i]=='e':
    time[3]+=1
  if n[i]=='o':
    time[4]+=1
  if n[i]==' ':
    bl+=1


leng=ln-bl
print(f'a:{time[0]/leng*100}')
print(f'i:{time[1]/leng*100}')
print(f'u:{time[2]/leng*100}')
print(f'e:{time[3]/leng*100}')
print(f'o:{time[4]/leng*100}')
