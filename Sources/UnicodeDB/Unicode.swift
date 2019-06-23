public struct Unicode {
    var a:Int
}

public let UnicodeArray = [
    Unicode(a: 1)
]

public class Slice {
    var start:Int?
    var end:Int?
    var step:Int?

    init(end:Int?){
        self.start = nil
        self.end = end
        self.step = nil
    }
    init(start:Int?,end:Int?){
        self.start = start
        self.end = end
        self.step = nil
    }
    init(start:Int?,end:Int?,step:Int?){
        self.start = start
        self.end = end
        self.step = step
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

extension String {

    public subscript (_ i: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: backIndex(i: i, l: self.count))]
    }
    public subscript (_ start:Int?,end:Int?,step:Int?) -> String {
        let step_:Int = step ?? 1
        if step_ == 1{
            return self[start,end]
        }
        let (start_,end_) = adjustIndex(start: start, end: end, len: self.count)
        var str:String = ""
        var index = start_
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
    public func capitalize_() -> String {
        return ""
    }
}

