import UnicodeDB
import Dispatch

print("Hello, world!")
print(UnicodeDB.UnicodeArray)
print(UnicodeDB.adjustIndex(start:0,end:100,len:10))
print(UnicodeDB.adjustIndex(start:-1,end:nil,len:10))
print(UnicodeDB.adjustIndex(start:-20,end:-38,len:10))
print(UnicodeDB.adjustIndex(start:nil,end:100,len:10))

let s = "0123456789"
print(s[0])
print(s[-1])
print(s[0,nil])
print(s[0,nil,2])


let i = -1

print(type(of:i))



