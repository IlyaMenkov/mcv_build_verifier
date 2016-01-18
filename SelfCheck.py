__author__ = 'imenkov'
import re

result = re.findall(r'\d+', 'Amit 1-1 1, XYZ 1 2, ABC 1 1')
print result
summ=0
for i in result:
    summ+=int(i)

print summ


print ("qwerty %s && wqerty %s" % ("kek", "s"))