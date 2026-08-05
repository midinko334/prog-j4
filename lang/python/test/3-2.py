n=input('input word:')
ln=len(n)
s=''
for i in range(0,ln):
  if 'A'<=n[i] and n[i]<='Z':
    s=s+chr(ord(n[i])-ord('A')+ord('a'))
  else :
    s=s+n[i]

print(s)
