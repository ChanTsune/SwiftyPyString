# SwiftyPyString  

[![Build Status](https://travis-ci.org/ChanTsune/SwiftyPyString.svg?branch=master)](https://travis-ci.org/ChanTsune/SwiftyPyString)
![Cocoapods](https://img.shields.io/cocoapods/l/SwiftyPyString)
![carthage](https://img.shields.io/badge/carthage-compatible-brightgreen.svg)
![GitHub release](https://img.shields.io/github/release/ChanTsune/SwiftyPyString)
![Cocoapods platforms](https://img.shields.io/cocoapods/p/SwiftyPyString)
![Swift Version](https://img.shields.io/badge/Swift-5-blue.svg)
  
SwiftyPyString is a string extension for Swift.  
This library provide Python compliant String operation methods.  

## Installation  

### Cocoapods  

```ruby
pod 'SwiftyPyString'
```

### Carthage  

```bash
github 'ChanTsune/SwiftyPyString'
```

### Swift Package Manager  

```swift
import PackageDescription

let package = Package(
    name: "YourProject",
    dependencies: [
        .Package(url: "https://github.com/ChanTsune/SwiftyPyString.git", from: "1.1.2")
    ]
)
```

## Usage  

```swift
import SwiftyPyString
```

### String extension

#### String sliceing subscript  

```swift
let str = "0123456789"
str[0]
// 0
str[-1]
// 9
```

#### Slice String

```swift
let str = "0123456789"

str[0,5]
// 01234
str[0,8,2]
// 0246
str[nil,nil,-1]
// 9876543210
```

Use Slice object case  

```swift
let str = "0123456789"
var slice = Slice(start:0, stop:5)
var sliceStep = Slice(start:0, stop:8, step:2)

str[slice]
// 01234
str[sliceStep]
// 0246
```

#### String Multiplication  

```swift
var s = "Hello World! " * 2

// "Hello World! Hello World! "
```

### Methods  

#### capitalize()  

```swift
"hello world!".capitalize() // "Hello world!"
```

#### casefold()  

```swift
"ß".casefold() // "ss"
```

#### center(width [,fillchar])  

```swift
"1234".center(10) // "   1234   "
"123"center(10) // "   123    "
"1234".center(10,fillchar:"0") // "0001234000"
"123"center(10,fillchar:"0") // "0001230000"
```

#### count(sub [,start [,end]])  

```swift
"abc abc abc".count("abc") // 3
"aaaaaaaaaa".count("a", start:2) // 8
"bbbbbbbbbb".count("bb", end:8) // 4
```

#### endswith(suffix [,start [,end]])  

```swift
"hello world!".endswith("!") // true
"hello world!".endswith("world!")  // true
"hello".endswith("world") // false
"hello".endswith(["hello","world","!"]) // true
```

#### expandtabs(tabsize=8)  

```swift
"abc\tabc\t".expandtabs() // "abc        abc        "
"abc\tabc\t".expandtabs(4) // "abc    abc    "
```

#### find(sub [,start [,end]])  

```swift
"123412312312345".find("123") // 0
"123412312312345".find("12345") // 10
"123412312312345".find("5") // 14
"123412312312345".find("31") // 6
"123412312312345".find("0") // -1
```

#### index(sub [,start [,end]]) throws  

```swift
"123412312312345".index("123") // 0
"123412312312345".index("12345") // 10
"123412312312345".index("5") // 14
"123412312312345".index("31") // 6
"123412312312345".index("0") // throw PyException.ValueError
```

#### isalnum()  

```swift
"123abc".isalnum() // true
"１０００A".isalnum() // true
"日本語".isalnum() // true
"abc 123".isalnum() // false
```

#### isalpha()  

```swift
"I have pen.".isalpha() // false
"qwerty".isalpha() // true
"日本語".isalpha() // true
"123".isalpha() // false
"".isalpha() // false
```

#### isascii()  

```swift
"I have pen.".isascii() // trur
"qwerty".isascii() // true
"123".isascii() // true
"".isascii() // true
"非ASCII文字列".isascii() // false
```

#### isdecimal()  

```swift
"123".isdecimal() // true
"１２３４５".isdecimal() // true
"一".isdecimal() // false
"".isdecimal() // false
```

#### isdigit()  

```swift
"123".isdigit() // true
"１２３４５".isdigit() // true
"一".isdigit() // true
"".isdigit() // true
```

#### islower()  

```swift
"lower case string".islower() // true
"Lower case string".islower() // false
"lower case String".islower() // false
"lower Case string".islower() // false
"小文字では無い".islower() // false
```

#### isnumeric()  

```swift
"123".isnumeric() // true
"１２３４５".isnumeric() // true
"一".isnumeric() // true
"".isnumeric() // false
```

#### isprintable()  

```swift
"".isprintable() // true
"abc".isprintable() // true
"\u{060D}".isprintable() // false
```

#### isspace()  

```swift
" ".isspace() // true
"".isspace() // false
"Speace".isspace() // false
```

#### istitle()  

```swift
"Title Case String".istitle() // true
"Title_Case_String".istitle() // true
"Title__Case  String".istitle() // true
"not Title Case String".istitle() // false
"NotTitleCaseString".istitle() // false
"Not Title case String".istitle() // false
```

#### isupper()  

```swift
"UPPER CASE STRING".isupper() // true
"Upper Case String".isupper() // false
"大文字では無い".isupper() // false
```

#### join(iterable)  

```swift
let array = ["abc","def","ghi"]
"".join(array) // "abcdefghi"
"-".join(array) // "abc-def-ghi"
"++".join(array) // "abc++def++ghi"
```

#### ljust(width [,fillchar])  

```swift
"abc".ljust(1) // "abc"
"abc".ljust(5) // "  abc"
"abc".ljust(5, fillchar:"$") // "$$abc"
```

#### lower()  

```swift
"ABCDE".lower() // "abcde"
"あいうえお".lower() // "あいうえお"
```

#### lstrip(chars=nil)  

```swift
"  lstrip sample".lstrip() // "lstrip sample"
"  lstrip sample".lstrip(" ls") // "trip sample"
"lstrip sample".lstrip() // "lstrip sample"
```

#### maketrans(x [,y [,x]])  

```swift
String.maketrans([97:"A",98:nil,99:"String"]) // ["a":"A","b":"","c":"String"]
String.maketrans(["a":"A","b":nil,"c":"String"]) // ["a":"A","b":"","c":"String"]
String.maketrans("abc",y: "ABC") // ["a":"A","b":"B","c":"C"]
String.maketrans("abc", y: "ABC", z: "xyz") // ["a":"A","b":"B","c":"C","x":"","y":"","z":""]
```

#### partition(sep)  

```swift
"a,b,c".partition(",") // ("a",",","b,c")
"a,b,c".partition("x") // ("a,b,c","","")
```

#### replace(old, new [,count])  

```swift
"abc".replace("bc", new: "bcd") // "abcd"
"Python python python python".replace("python", new: "Swift", count: 2) // "Python Swift Swift python"
```

#### rfind(sub [,start [,end]])  

```swift
"0123456789".rfind("0") // 0
"0123456789".rfind("02") // -1
"0123454321".rfind("2") // 8
"0123454321".rfind("1", end: -1) // 1
```

#### rindex(sub [,start [,end]]) throws  

```swift
"0123456789".rindex("0") // 0
"0123456789".rindex("02") // throw PyException.ValueError
"0123454321".rindex("2") // 8
"0123454321".rindex("1", end: -1) // 1
```

#### rjust(width [,fillchar])  

```swift
"abc".rjust(1) // "abc"
"abc".rjust(5) // "abc  "
"abc"rjust(5,fillchar:"z") // "abczz"
```

#### rpartition(sep)  

```swift
"a,b,c".rpartition(",") // ("a,b", ",", "c")
"a,b,c".rpartition("x") // ("", "", "a,b,c")
```

#### rsplit(sep=nil [,maxsplit])  

```swift
"a,b,c,d,".rsplit(",") // ["a", "b", "c", "d", ""]
"a,b,c,d,".rsplit() // ["a,b,c,d,"]
"a,b,c,d,".rsplit(",", maxsplit: 2) // ["a,b,c","d", ""]
"a,b,c,d,".rsplit(",", maxsplit: 0) // ["a,b,c,d,"]
"aabbxxaabbaaddbb".rsplit("aa", maxsplit: 2) // ["aabbxx", "bb", "ddbb"]
```

#### rstrip(chars=nil)  

```swift
"rstrip sample   ".rstrip() // "rstrip sample"
"rstrip sample   ".rstrip("sample ") // "rstri"
"  rstrip sample".rstrip() // "  rstrip sample"
```

#### split(sep=nil [,maxsplit])  

```swift
"a,b,c,d,".split(",") // ["a", "b", "c", "d", ""]
"a,b,c,d,".split() // ["a,b,c,d,"]
"a,b,c,d,".split(",", maxsplit: 2) // ["a", "b", "c,d,"]
"a,b,c,d,".split(",", maxsplit: 0) // ["a,b,c,d,"]
"aabbxxaabbaaddbb".split("aa", maxsplit: 2) // ["", "bbxx", "bbaaddbb"]
```

#### splitlines([keepends])  

```swift
"abc\nabc".splitlines() // ["abc", "abc"]
"abc\nabc\r".splitlines(true) // ["abc\n", "abc\r"]
"abc\r\nabc\n".splitlines() // ["abc", "abc"]
"abc\r\nabc\n".splitlines(true) // ["abc\r\n", "abc\n"]
```

#### startswith(prefix [,start [,end]])  

```swift
"hello world!".startswith("hello") // true
"hello world!".startswith("h") // true
"hello".startswith("world") // flase
"hello".startswith(["hello", "world", "!"]) // true
```

#### strip(chars=nil)  

```swift
"   spacious   ".strip() // "spacious"
"www.example.com".strip("cmowz.") // "example"
```

#### swapcase()  

```swift
"aBcDe".swapcase() // "AbCdE"
"AbC dEf".swapcase() // "aBc DeF"
"あいうえお".swapcase() // "あいうえお"
```

#### title()  

```swift
"Title letter".title() // "Title Letter"
"title Letter".title() // "Title Letter"
"abc  abC _ aBC".title() // "Abc  Abc _ Abc"
```

#### translate(transtable)  

```swift
let table = String.maketrans("", y: "", z: "swift")

"I will make Python like string operation library".translate(table)
// "I ll make Pyhon lke rng operaon lbrary"
```

#### upper()  

```swift
"abcde".upper() // "ABCDE"
"あいうえお".upper() // "あいうえお"
```

#### zfill()  

```swift
"abc".zfill(1) // "abc"
"abc".zfill(5) // "00abc"
"+12".zfill(5) // "+0012"
"-3".zfill(5) // "-0003"
"+12".zfill(2) // "+12"
```

For more detail please refer below link  
[https://docs.python.org/3/library/stdtypes.html#string-methods](https://docs.python.org/3/library/stdtypes.html#string-methods)  

### Sliceable protocol  

```swift
protocol Sliceable : Collection {
    init() /* Required. */
    subscript (_ start: Int?, _ stop: Int?, _ step: Int?) -> Self { get }
    subscript (_ start: Int?, _ end: Int?) -> Self { get }
    subscript (_ i:Int) -> Self.Element { get } /* Required. */
    subscript (_ slice: Slice) -> Self { get }
    mutating func append(_ newElement: Self.Element) /* Required. */
}
```

With the introduction of `SwiftyPyString`, `String` conforms to the `Sliceable` protocol.  

By conforming to `Sliceable` protocol, it can get partial sequences as introduced in [Slice String](#Slice-String).  


If the type you want to conform to `Sliceable` is conforms to `RangeReplaceableCollection`, it can be used simply by defining `subscript (_ i:Int) -> Self.Element { get }`.  

In addition, if `associatedtype Index` of `Collection` is `Int`, you can conform to `Sliceable` with a very short code as follows, like `Array`.  

```swift
extension Array : Sliceable { }
```

```swift
let arr = [1, 2, 3, 4, 5]

arr[0, 3]
// [0, 1, 2]

let slice = Slice(step:2)

arr[slice]
// [1, 3, 5]

```
## License

SwiftPyString is available under the MIT license. See the LICENSE file for more information.  
