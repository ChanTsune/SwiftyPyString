public let PYTHON_VERSION = "3.7.2"

public class Slice {
    var start:Int?
    var end:Int?
    var step:Int?

    init(end:Int?){
        self.start = nil
        self.end = end
        self.step = nil
    }
    init(start:Int?,end:Int?,step:Int?=nil){
        self.start = start
        self.end = end
        self.step = nil
    }
}

func backIndex(i:Int,l:Int) -> Int{
    return i < 0 ? l + i : i
}
func overIndex(i:Int,l:Int) -> Int{
    return l < i ? l : i
}
func underIndex(i:Int,l:Int) -> Int{
    return i < 0 ? 0 : i
}

public func adjustIndex(start:Int?,end:Int?,len:Int) -> (Int,Int) {
    return (underIndex(i: overIndex(i: backIndex(i: start ?? 0, l: len), l: len), l: len), 
            underIndex(i: overIndex(i: backIndex(i: end ?? len, l: len), l: len), l: len))
}

public class BaseException : Error {
    
}

public class Exception : BaseException {

}

public class ValueError : Exception {

}
extension String {

    public subscript (_ i: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: backIndex(i: i, l: self.count))]
    }
    public subscript (_ start:Int?,end:Int?,step:Int?) -> String {
        let step_:Int = step ?? 1
        if step_ == 1 {
            return self[start,end]
        }
        let (start_,end_) = adjustIndex(start: start, end: end, len: self.count)
        var str:String = ""
        var index = start_
        if step_ < 0 {
            let revself = String(self.reversed())
            if step_ == -1 {
                return revself
            }
            while index < end_ {
                str.append(revself[index])
                index -= step_
            }
            return str
        }
        while index < end_ {
            str.append(self[index])
            index += step_
        }
        return str
    }
    public subscript (_ start:Int?,end:Int?) -> String {
        let (s,e) = adjustIndex(start: start, end: end, len: self.count)
        return String(self.prefix(e).dropFirst(s))
    }
    public subscript (_ slice:Slice) -> String {
        return self[slice.start,slice.end,slice.step]
    }
    public func capitalize() -> String {
        return self.prefix(1).uppercased() + self.dropFirst(1).lowercased();
    }
    public func casefold() -> String {
        // TODO:Impl
        return ""
    }
    public func center(_ width:Int,fillchar:Character=" ") -> String {
        if self.count >= width{
            return self
        }
        let left = width - self.count
        let right = left/2 + left % 2
        return String(repeating: fillchar, count: left-right) + self + String(repeating: fillchar, count: right)
    }
    public func count(_ sub:String, start:Int?=nil,end:Int?=nil) -> Int {
        // TODO:Impl
        var n = self.find(sub,start: start,end: end)
        var c = 0
        while n != -1 {
            c += 1
            n = self.find(sub,start: n + sub.count, end:end)
        }
        return c
    }
    /*
    public func encode() -> String {
        return ""
    }
    */
    public func endswith(_ suffix:String,start:Int?,end:Int?) -> Bool {
        return self[start, end].hasSuffix(suffix)
    }
    public func endswith(_ suffix:[String],start:Int?,end:Int?) -> Bool {
        let str = self[start,end]
        for s in suffix {
            if str.hasSuffix(s){
                return true
            }
        }
        return false
    }
    public func expandtabs(_ tabsize:Int=8) -> String {
        return self.replace("\t", new:String(repeating: " ", count:tabsize ))
    }
    static public func make_table(_ pattern:String) -> [Character:Int] {
        var table:[Character:Int] = [:]
        let len = pattern.count - 1
        for i in 0..<(len) {
            table[pattern[i]] = len - i
        }
        return table
    }

    public func find(_ sub:String, start:Int?=nil,end:Int?=nil) -> Int {
        // BMH algorithm

        let (s, e) = adjustIndex(start: start, end: end, len: self.count)
        var i = s
        let fin = e - sub.count
        while i <= fin {
            if self[i,i + sub.count] == sub {
                return i
            }
            i += 1
        }

        // let table = String.make_table(sub)
        // print("table:",table)
        
        // func skip_table(_ c:Character) -> Int {
        //     return table[c,default: sub.count]
        // }
        // var skip = s
        // while self.count - skip >= sub.count {
        //     var i = sub.count - 1
        //     while self[skip + i] == sub[i] {
        //         if i == 0 {
        //             return skip
        //         }
        //         i = i - 1
        //     }
        //     skip = skip + skip_table(self[skip + sub.count - 1])
        // }
        return -1
    }

    public func format(_ args:Any?,kwargs:[String:Any?]) -> String {
        // TODO:Impl
        return ""
    }

    public func format_map(_mapping:[String:Any?]) -> String {
        // TODO:Impl
        return ""
    }

    public func index(_ sub:String,start:Int?=nil,end:Int?=nil) throws -> Int {
        let i = self.find(sub,start: start,end: end)
        if i == -1 {
            throw ValueError()
        }
        return i
    }
    public func isalpha() -> Bool {
        // TODO:Impl
        return false
    }

    public func isascii() -> Bool {
        // TODO:Impl
        return false
    }

    public func isdecimal() -> Bool {
        // TODO:Impl
        return false
    }

    public func isdigit() -> Bool {
        // TODO:Impl
        return false
    }
    /*
    public func isidentifier() -> Bool {
        return false
    }
    */
    public func islower() -> Bool {
        // TODO:Impl
        return false
    }

    public func isnumeric() -> Bool {
        // TODO:Impl
        return false
    }

    public func isprintable() -> Bool {
        // TODO:Impl
        return false
    }

    public func isspace() -> Bool {
        // TODO:Impl
        return false
    }
    public func istitle() -> Bool {
        // TODO:Impl
        return false
    }
    public func join(_ iterable:[String]) -> String {
        var str = ""
        for item in iterable {
            str += item
            str += self
        }
        return String(str.dropLast(self.count))
    }
    public func join(_ iterable:[Character]) -> String {
        var str = ""
        for item in iterable {
            str.append(item)
            str += self
        }
        return String(str.dropLast(self.count))
    }
    public func ljust(_ width:Int,fillchar:Character=" ") -> String {
        if self.count >= width {
            return self
        }
        let w = width - self.count
        return String(repeating: fillchar, count: w) + self
    }
    public func lower() -> String {
        // TODO:Impl
        return ""
    }
    public func lstrip(_ chars:String?=nil) -> String {
        // TODO:Impl
        return ""
    }
    static public func maketrans() -> [String:String] {
        // TODO:Impl
        return [:]
    }

    public func partition(_ sep:String) -> (String, String, String) {
        // TODO:Impl
        return ("","","")
    }

    public func replace(_ old:String,new:String,count:Int=Int.max) -> String {
        // TODO:Impl
        return ""
    }
    public func rfind(_ sub:String,start:Int?=nil,end:Int?=nil) -> Int {
        // TODO:Impl
        return -1;
    }
    public func rindex(_ sub:String,start:Int?=nil,end:Int?=nil) throws -> Int {
        let i = self.rfind(sub,start: start,end:end)
        if i == -1 {
            throw ValueError()
        }
        return i;
    }
    public func rjust(_ width:Int,fillchar:Character=" ") -> String {
        if self.count >= width {
            return self
        }
        let w = width - self.count
        return self + String(repeating: fillchar, count: w)
    }

    public func rpartition(_ sep:String) -> (String, String, String) {
        // TODO:Impl
        return ("","","")
    }
    public func rsplit(_ sep:String?=nil, maxsplit:Int=(-1)) -> [String] {
        // TODO:Impl
        if self.isEmpty {
            return [""]
        }
        return []
    }
    public func rstrip(_ chars:String?=nil) -> String {
        // TODO:Impl
        return ""
    }
    public func split(_ sep:String?=nil,maxsplit:Int=(-1)) -> [String] {
        // TODO:Impl
        if self.isEmpty {
            return [""]
        }
        return []
    }
    public func splitlines(_ keepends:Bool=false) -> [String] {
        // TODO:Impl
        return []
    }
    public func startswith(_ prefix:String,start:Int?=nil,end:Int?=nil) -> Bool {
        return self[start,end].hasPrefix(prefix)
    }
    public func startswith(_ prefix:[String],start:Int?=nil,end:Int?=nil) -> Bool {
        let str = self[start,end]
        for s in prefix {
            if str.hasPrefix(s){
                return true
            }
        }
        return false
    }

    public func strip(_ chars:String?=nil) -> String {
        return self.lstrip(chars).lstrip(chars)
    }
    public func swapcase() -> String {
        // TODO:Impl
        return ""
    }
    public func title() -> String {
        // TODO:Impl
        return ""
    }
    public func transerate(_ table:[String:String]) -> String {
        // TODO:Impl
        return ""
    }
    public func upper() -> String {
        // TODO:Impl
        return ""
    }
    public func zfill(_ width:Int) -> String {
        if !self.isEmpty {
            let h = self[0, 1]
            if h == "+" || h == "-" {
                return h + self[1, nil].ljust(width - 1,fillchar: "0")
            }
        }
        return self.ljust(width,fillchar: "0")
    }
}

