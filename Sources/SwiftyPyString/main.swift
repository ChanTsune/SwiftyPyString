import UnicodeDB
import Dispatch

// print("Hello, world!")
// print(UnicodeDB.adjustIndex(start:0,end:100,len:10))
// print(UnicodeDB.adjustIndex(start:-1,end:nil,len:10))
// print(UnicodeDB.adjustIndex(start:-20,end:-38,len:10))
// print(UnicodeDB.adjustIndex(start:nil,end:100,len:10))

// let bb = "bbbabbbbbbb"

// print(bb.find("b"))
// print(bb.find("bb"))

// print(bb.count("bb"))


// let i = -1

// print(type(of:i))



for i in 65297..<(65297+10) {
    let c = Character(i)
    print(i,c,c.isNumber,c.isWholeNumber)
    print(UnicodeDB.isDigit(ch: Py_UCS4(i) ))
}
