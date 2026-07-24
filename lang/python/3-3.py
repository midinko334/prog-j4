n=input('input word:')
ln=len(n)
rev=''
for i in range(0,ln):
  rev=rev+n[ln-1-i]

if n==rev:
  print('it is palindrome')
else:
  print('it isn\'t palindrome')
