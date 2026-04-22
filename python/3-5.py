n=input('input word:')
ln=len(n)
vow=0
for i in range(0,ln):
  if n[i]=='a' or n[i]=='i' or n[i]=='u' or n[i]=='e' or n[i]=='o' or n[i]=='A' or n[i]=='I' or n[i]=='U' or n[i]=='E' or n[i]=='O':
    print(n[i],end='')
    vow=vow+1
  elif n[i]==' ':
    print(f'→ vowel:{vow}')
    vow=0
  else:
    print(n[i],end='')

print(f'→ vowel:{vow}')
vow=0
