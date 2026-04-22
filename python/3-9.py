n=input('input word:')
ln=len(n)
flag=0
word=n.split()
most=0

for i in range(0,len(word)):
  if len(word[i])>len(word[most]):
    most=i

print(f'largest word is:{word[most]}')
