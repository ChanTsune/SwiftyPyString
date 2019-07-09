import XCTest
@testable import SwiftyPyString

final class SwiftyPyStringTests: XCTestCase {
    // func testExample() throws {
    //     // This is an example of a functional test case.
    //     // Use XCTAssert and related functions to verify your tests produce the correct
    //     // results.

    //     // Some of the APIs that we use below are available in macOS 10.13 and above.
    //     guard #available(macOS 10.13, *) else {
    //         return
    //     }

    //     let fooBinary = productsDirectory.appendingPathComponent("SwiftyPyString")

    //     let process = Process()
    //     process.executableURL = fooBinary

    //     let pipe = Pipe()
    //     process.standardOutput = pipe

    //     try process.run()
    //     process.waitUntilExit()

    //     let data = pipe.fileHandleForReading.readDataToEndOfFile()
    //     let output = String(data: data, encoding: .utf8)

    //     XCTAssertEqual(output, "Hello, world!\n")
    // }
    func test_CompileTime() throws {}
    func testSlice() throws {
        let str = "0123456789"
        XCTAssertEqual(str[1,1],"")
        XCTAssertEqual(str[1,2],"1")
        XCTAssertEqual(str[0,20],"0123456789")
        XCTAssertEqual(str[0,10,2],"02468")
        XCTAssertEqual(str[0,10,3],"0369")
    }
    func testSliceNil() throws {
        let str = "0123456789"
        XCTAssertEqual(str[1,nil],"123456789")
        XCTAssertEqual(str[nil,nil,2],"02468")
        XCTAssertEqual(str[nil,5],"01234")
        XCTAssertEqual(str[nil,nil,nil],"0123456789")
    }
    func testSliceNegate() throws {
        let str = "0123456789"
        XCTAssertEqual(str[-5,-1],"5678")
        XCTAssertEqual(str[-5,-20],"")
        XCTAssertEqual(str[nil,nil,-1],"9876543210")
        XCTAssertEqual(str[nil,nil,-2],"97531")
    }
    func testCapitalize() throws {
        let case1 = "hello world!"
        let case2 = "Hello World!"
        XCTAssertEqual(case1.capitalize(),"Hello world!")
        XCTAssertEqual(case2.capitalize(),"Hello world!")
    }
    func testCasefold() throws {
        /* code */
    }
    func testCenter() throws {
        let even = "1234"
        let odd = "123"
        XCTAssertEqual(even.center(10),"   1234   ")
        XCTAssertEqual(odd.center(10),"   123    ")
        XCTAssertEqual(even.center(10,fillchar:"0"),"0001234000")
        XCTAssertEqual(odd.center(10,fillchar:"0"),"0001230000")
    }
    func testCount() throws {
        let a = "aaaaaaaaaa"
        let bb = "bbbbbbbbbb"
        let words = "abc abc abc"
        XCTAssertEqual(a.count("a"),10)
        XCTAssertEqual(bb.count("bb"),5)
        XCTAssertEqual(words.count("abc"),3)
    }
    func testEndswith() throws {
        let s1:String = "hello"
        let s2:String = "hello world!"
        let pos:[String] = ["hello","world","!"]

        XCTAssertTrue(s1.endswith(pos))
        XCTAssertFalse(s1.endswith("world"))
        XCTAssertTrue(s2.endswith("world!"))
        XCTAssertTrue(s2.endswith("!"))
    }
    func testExpandtabs() throws {
        /* code */
    }

    func testFind() throws {
        let str = "0123456789"
        let str2 = "123412312312345"
        XCTAssertEqual(str.find("0"),0)
        XCTAssertEqual(str.find("5"),5)
        XCTAssertEqual(str.find("9"),9)
        XCTAssertEqual(str.find("789"),7)
        XCTAssertEqual(str.find("79"),-1)

        XCTAssertEqual(str2.find("0"),-1)
        XCTAssertEqual(str2.find("5"),14)
        XCTAssertEqual(str2.find("123"),0)
        XCTAssertEqual(str2.find("12345"),10)
        XCTAssertEqual(str2.find("31"),6)
    }
    func testMakeTable() throws {
        let p = "qwertyuiop"
        for _ in 0...10000 {
            String.make_table(p)
        }
    }
    func testIsAlnum() throws {
        XCTAssertTrue("123abc".isalnum())
        XCTAssertTrue("１０００A".isalnum())
        XCTAssertTrue("日本語".isalnum())
        XCTAssertFalse("abc 123".isalnum())
    }
    func testIsAlpha() throws {
        XCTAssertFalse("I have pen.".isalpha())
        XCTAssertTrue("qwerty".isalpha())
        XCTAssertFalse("123".isalpha())
        XCTAssertFalse("".isalpha())
    }
    func testIsAscii() throws {
        XCTAssertTrue("I have pen.".isascii())
        XCTAssertTrue("qwerty".isascii())
        XCTAssertTrue("123".isascii())
        XCTAssertTrue("".isascii())
        XCTAssertFalse("非ASCII文字列".isascii())
    }
    func testIsDecimal() throws {
        XCTAssertTrue("123".isdecimal())
        XCTAssertTrue("１２３４５".isdecimal())
        XCTAssertFalse("一".isdecimal())
        XCTAssertFalse("".isdecimal())
    }
    func testIsDigit() throws {
        XCTAssertTrue("123".isdigit())
        XCTAssertTrue("１２３４５".isdigit())
        XCTAssertFalse("一".isdigit())
        XCTAssertFalse("".isdigit())
    }
    func testIsLower() throws {
        XCTAssertTrue("lower case string".islower())
        XCTAssertFalse("Lower case string".islower())
        XCTAssertFalse("lower case String".islower())
        XCTAssertFalse("lower Case string".islower())
        XCTAssertFalse("小文字では無い".islower())
    }
    func testIsNumeric() throws {
        XCTAssertTrue("123".isnumeric())
        XCTAssertTrue("１２３４５".isnumeric())
        XCTAssertTrue("一".isnumeric())
        XCTAssertFalse("".isnumeric())
    }
    func testIsTitle() throws {
        XCTAssertTrue("Title Case String".istitle())
        XCTAssertTrue("Title_Case_String".istitle())
        XCTAssertTrue("Title__Case  String".istitle())
        XCTAssertFalse("not Title Case String".istitle())
        XCTAssertFalse("NotTitleCaseString".istitle())
        XCTAssertFalse("Not Title case String".istitle())
    }
    func testJoin() throws {
        let arry = ["abc","def","ghi"]
        let carry:[Character] = ["a","b","c"]
        XCTAssertEqual("".join(arry),"abcdefghi")
        XCTAssertEqual("-".join(arry),"abc-def-ghi")
        XCTAssertEqual("-".join(carry),"a-b-c")
    }
    func testLjust() throws {
        let str = "abc"
        XCTAssertEqual(str.ljust(1),"abc")
        XCTAssertEqual(str.ljust(5),"  abc")
        XCTAssertEqual(str.ljust(5,fillchar:"z"),"zzabc")
    }
    func testLower() throws {
        XCTAssertEqual("ABCDE".lower(), "abcde")
        XCTAssertEqual("あいうえお".lower(), "あいうえお")
    }
    func testLstrip() throws {
        XCTAssertEqual("  lstrip sample".lstrip(), "lstrip sample")
        XCTAssertEqual("  lstrip sample".lstrip(" ls"), "trip sample")
        XCTAssertEqual("lstrip sample".lstrip(), "lstrip sample")
    }
    func testMaketrans() throws {
        XCTAssertEqual(String.maketrans([97:"A",98:nil,99:"String"]), ["a":"A","b":"","c":"String"])
        XCTAssertEqual(String.maketrans(["a":"A","b":nil,"c":"String"]), ["a":"A","b":"","c":"String"])
        XCTAssertEqual(String.maketrans("abc",y: "ABC"),["a":"A","b":"B","c":"C"])
        XCTAssertEqual(String.maketrans("abc", y: "ABC", z: "xyz"), ["a":"A","b":"B","c":"C","x":"","y":"","z":""])
    }
    func test() throws {
        
    }
    func testRjust() throws {
        let str = "abc"
        XCTAssertEqual(str.rjust(1),"abc")
        XCTAssertEqual(str.rjust(5),"abc  ")
        XCTAssertEqual(str.rjust(5,fillchar:"z"),"abczz")
    }
    func testRstrip() throws {
        XCTAssertEqual("rstrip sample   ".rstrip(), "rstrip sample")
        XCTAssertEqual("rstrip sample   ".rstrip("sample "), "rstri")
        XCTAssertEqual("  rstrip sample".rstrip(), "  rstrip sample")
    }
    func testSplit() throws {
        XCTAssertEqual("a,b,c,d,".split(","), ["a","b","c","d",""])
        XCTAssertEqual("a,b,c,d,".split(), ["a,b,c,d,"])
        XCTAssertEqual("a,b,c,d,".split(",",maxsplit: 2), ["a","b","c,d,"])
        XCTAssertEqual("a,b,c,d,".split(",",maxsplit: 0), ["a,b,c,d,"])
    }
    func testStartswith() throws {
        let s1 = "hello"
        let s2 = "hello world!"
        let pos:[String] = ["hello","world","!"]

        XCTAssertTrue(s1.startswith(pos))
        XCTAssertFalse(s1.startswith("world"))
        XCTAssertTrue(s2.startswith("hello"))
        XCTAssertTrue(s2.startswith("h"))
    }
    func testStrip() throws {
        XCTAssertEqual("   spacious   ".strip(), "spacious")
        XCTAssertEqual("www.example.com".strip("cmowz."), "example")
    }
    func testSwapcase() throws {
        XCTAssertEqual("aBcDe".swapcase(), "AbCdE")
        XCTAssertEqual("AbC dEf".swapcase(), "aBc DeF")
        XCTAssertEqual("あいうえお".swapcase(), "あいうえお")
    }
    func testTitle() throws {
        XCTAssertEqual("Title letter".title(), "Title Letter")
        XCTAssertEqual("title Letter".title(), "Title Letter")
        XCTAssertEqual("abc  abC _ aBC".title(), "Abc  Abc _ Abc")
    }
    func testTransrate() throws {
        let table1 = String.maketrans("", y: "", z: "swift")
        
        XCTAssertEqual("I will make Python like string operation library".translate(table1), "I ll make Pyhon lke rng operaon lbrary")
    }
    func testUpper() throws {
        XCTAssertEqual("abcde".upper(), "ABCDE")
        XCTAssertEqual("あいうえお".upper(), "あいうえお")
    }
    func testZfill() throws {
        let str = "abc"
        let plus = "+12"
        let minus = "-3"
        XCTAssertEqual(str.zfill(1),"abc")
        XCTAssertEqual(str.zfill(5),"00abc")
        XCTAssertEqual(plus.zfill(5),"+0012")
        XCTAssertEqual(minus.zfill(5),"-0003")
        XCTAssertEqual(plus.zfill(2),"+12")
    }

    /// Returns path to the built products directory.
    var productsDirectory: URL {
      #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("couldn't find the products directory")
      #else
        return Bundle.main.bundleURL
      #endif
    }
}
