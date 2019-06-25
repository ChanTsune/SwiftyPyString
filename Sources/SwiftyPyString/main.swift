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

let capital = "string String string"

print(capital.capitalize())

print(String(repeating: "ab", count:10))

let cent = "12345"
print(cent.center(10))
print(cent.center(10,fillchar:"0"))




let i = -1

print(type(of:i))



