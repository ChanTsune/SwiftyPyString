import XCTest
@testable import SwiftyPyString

final class SwiftyPyStringTests: XCTestCase {
    func testMultiplication() throws {
        XCTAssertEqual("a" * 0, "")
        XCTAssertEqual(0 * "a", "")
        XCTAssertEqual("a" * 2, "aa")
        XCTAssertEqual("a" * -1, "")
    }

    func testCapitalize() throws {
        let case1 = "hello world!"
        let case2 = "Hello World!"
        XCTAssertEqual(case1.capitalize(), "Hello world!")
        XCTAssertEqual(case2.capitalize(), "Hello world!")
    }
    func testCasefold() throws {
        XCTAssertEqual("ß".casefold(), "ss")
        XCTAssertEqual("A".casefold(), "a")
    }
    func testCenter() throws {
        let even = "1234"
        let odd = "123"
        XCTAssertEqual(even.center(10), "   1234   ")
        XCTAssertEqual(odd.center(10), "   123    ")
        XCTAssertEqual(even.center(10, fillchar: "0"), "0001234000")
        XCTAssertEqual(odd.center(10, fillchar: "0"), "0001230000")
    }
    func testCount() throws {
        let a = "aaaaaaaaaa"
        let bb = "bbbbbbbbbb"
        let words = "abc abc abc"
        XCTAssertEqual(a.count("a"), 10)
        XCTAssertEqual(bb.count("bb"), 5)
        XCTAssertEqual(words.count("abc"), 3)
        XCTAssertEqual("".count(""), 1)
        XCTAssertEqual("abc".count(""), 4)
        let b = "mississippi"
        let i = "i"
        let p = "p"
        let w = "w"
        XCTAssertEqual(b.count("i"), 4)
        XCTAssertEqual(b.count("ss"), 2)
        XCTAssertEqual(b.count("w"), 0)
        XCTAssertEqual(b.count(i), 4)
        XCTAssertEqual(b.count(w), 0)
        XCTAssertEqual(b.count("i", start: 6), 2)
        XCTAssertEqual(b.count("p", start: 6), 2)
        XCTAssertEqual(b.count("i", start: 1, end: 3), 1)
        XCTAssertEqual(b.count("p", start: 7, end: 9), 1)
        XCTAssertEqual(b.count(i, start: 6), 2)
        XCTAssertEqual(b.count(p, start: 6), 2)
        XCTAssertEqual(b.count(i, start: 1, end: 3), 1)
        XCTAssertEqual(b.count(p, start: 7, end: 9), 1)
    }
    func testEndswith() throws {
        let s1: String = "hello"
        let s2: String = "hello world!"
        let pos: [String] = ["hello", "world", "!"]

        XCTAssertTrue(s1.endswith(pos))
        XCTAssertFalse(s1.endswith("world"))
        XCTAssertTrue(s2.endswith("world!"))
        XCTAssertTrue(s2.endswith("!"))
    }
    func testExpandtabs() throws {
        XCTAssertEqual("abc\tabc\t".expandtabs(), "abc        abc        ")
        XCTAssertEqual("abc\tabc".expandtabs(0), "abcabc")
    }

    func testFind() throws {
        let str = "0123456789"
        let str2 = "123412312312345"
        XCTAssertEqual(str.find("0"), 0)
        XCTAssertEqual(str.find("5"), 5)
        XCTAssertEqual(str.find("9"), 9)
        XCTAssertEqual(str.find("789"), 7)
        XCTAssertEqual(str.find("79"), -1)

        XCTAssertEqual(str2.find("0"), -1)
        XCTAssertEqual(str2.find("5"), 14)
        XCTAssertEqual(str2.find("123"), 0)
        XCTAssertEqual(str2.find("12345"), 10)
        XCTAssertEqual(str2.find("31"), 6)

        XCTAssertEqual(str2.find(""), 0)
    }
    func testIndex() throws {
        let s = "0123456789"
        XCTAssertEqual(try! s.index("0"), 0)
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
    func testIsPrintable() throws {
        XCTAssertTrue("".isprintable())
        XCTAssertTrue("abc".isprintable())
        XCTAssertFalse("\u{060D}".isprintable())
    }
    func testIsSpace() throws {
        XCTAssertTrue(" ".isspace())
        XCTAssertFalse("".isspace())
        XCTAssertFalse("Speace".isspace())
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
    func testIsUpper() throws {
        XCTAssertTrue("UPPER CASE STRING".isupper())
        XCTAssertFalse("Upper Case String".isupper())
        XCTAssertFalse("大文字では無い".isupper())
    }
    func testJoin() throws {
        let arry = ["abc", "def", "ghi"]
        let carry: [Character] = ["a", "b", "c"]
        XCTAssertEqual("".join(arry), "abcdefghi")
        XCTAssertEqual("-".join(arry), "abc-def-ghi")
        XCTAssertEqual("-".join(carry), "a-b-c")
    }
    func testLjust() throws {
        let str = "abc"
        XCTAssertEqual(str.ljust(1), "abc")
        XCTAssertEqual(str.ljust(5), "abc  ")
        XCTAssertEqual(str.ljust(5, fillchar: "z"), "abczz")
    }
    func testLower() throws {
        XCTAssertEqual("ABCDE".lower(), "abcde")
        XCTAssertEqual("あいうえお".lower(), "あいうえお")
    }
    func testLstrip() throws {
        XCTAssertEqual("".lstrip(), "")
        XCTAssertEqual("  lstrip sample".lstrip(), "lstrip sample")
        XCTAssertEqual("  lstrip sample".lstrip(" ls"), "trip sample")
        XCTAssertEqual("lstrip sample".lstrip(), "lstrip sample")
    }
    func testMaketrans() throws {
        XCTAssertEqual(String.maketrans([97: "A", 98: nil, 99: "String"]), ["a": "A", "b": "", "c": "String"])
        XCTAssertEqual(String.maketrans(["a": "A", "b": nil, "c": "String"]), ["a": "A", "b": "", "c": "String"])
        XCTAssertEqual(String.maketrans("abc", y: "ABC"), ["a": "A", "b": "B", "c": "C"])
        XCTAssertEqual(String.maketrans("abc", y: "ABC", z: "xyz"), ["a": "A", "b": "B", "c": "C", "x": "", "y": "", "z": ""])
    }
    func testPartition() throws {
        XCTAssert("a,b,c".partition(",") == ("a", ",", "b,c"))
        XCTAssert("a,b,c".partition("x") == ("a,b,c", "", ""))
    }
    func testRindex() throws {
        let s = "0123456789"
        XCTAssertEqual(try! s.rindex("0"), 0)
    }
    func testReplace() throws {
        XCTAssertEqual("abc".replace("bc", new: "bcd"), "abcd")
        XCTAssertEqual("Python python python python".replace("python", new: "Swift", count: 2), "Python Swift Swift python")
    }
    func testRfind() throws {
        let s = "0123456789"
        XCTAssertEqual(s.rfind("0"), 0)
        XCTAssertEqual(s.rfind("02"), -1)
        XCTAssertEqual(s.rfind("23"), 2)
        XCTAssertEqual(s.rfind("0", start: 1), -1)
        XCTAssertEqual(s.rfind(""), s.count)
        let b = "mississippi"
        let i = "i"
        let w = "w"
        XCTAssertEqual(b.rfind("ss"), 5)
        XCTAssertEqual(b.rfind("w"), -1)
        XCTAssertEqual(b.rfind("mississippian"), -1)
        XCTAssertEqual(b.rfind(i), 10)
        XCTAssertEqual(b.rfind(w), -1)
        XCTAssertEqual(b.rfind("ss", start: 3), 5)
        XCTAssertEqual(b.rfind("ss", start: 0, end: 6), 2)
        XCTAssertEqual(b.rfind(i, start: 1, end: 3), 1)
        XCTAssertEqual(b.rfind(i, start: 3, end: 9), 7)
        XCTAssertEqual(b.rfind(w, start: 1, end: 3), -1)
    }
    func testRjust() throws {
        let str = "abc"
        XCTAssertEqual(str.rjust(1), "abc")
        XCTAssertEqual(str.rjust(5), "  abc")
        XCTAssertEqual(str.rjust(5, fillchar: "z"), "zzabc")
    }
    func testRpartition() throws {
        XCTAssert("a,b,c".rpartition(",") == ("a,b", ",", "c"))
        XCTAssert("a,b,c".rpartition("x") == ("", "", "a,b,c"))
    }
    func testRsplit() throws {
        XCTAssertEqual("a,b,c,d,".rsplit(","), ["a", "b", "c", "d", ""])
        XCTAssertEqual("a,b,c,d,".rsplit(), ["a,b,c,d,"])
        XCTAssertEqual("a,b,c,d,".rsplit(",", maxsplit: 2), ["a,b,c", "d", ""])
        XCTAssertEqual("a,b,c,d,".rsplit(",", maxsplit: 0), ["a,b,c,d,"])
        XCTAssertEqual("aabbxxaabbaaddbb".rsplit("aa", maxsplit: 2), ["aabbxx", "bb", "ddbb"])
    }
    func testRstrip() throws {
        XCTAssertEqual("".rstrip(), "")
        XCTAssertEqual("rstrip sample   ".rstrip(), "rstrip sample")
        XCTAssertEqual("rstrip sample   ".rstrip("sample "), "rstri")
        XCTAssertEqual("  rstrip sample".rstrip(), "  rstrip sample")
    }
    func testSplit() throws {
        XCTAssertEqual("a,b,c,d,".split(","), ["a", "b", "c", "d", ""])
        XCTAssertEqual("a,b,c,d,".split(), ["a,b,c,d,"])
        XCTAssertEqual("a,b,c,d,".split(",", maxsplit: 2), ["a", "b", "c,d,"])
        XCTAssertEqual("a,b,c,d,".split(",", maxsplit: 0), ["a,b,c,d,"])
        XCTAssertEqual("aabbxxaabbaaddbb".split("aa", maxsplit: 2), ["", "bbxx", "bbaaddbb"])
    }
    func testSplitlines() throws {
        XCTAssertEqual("abc\nabc".splitlines(), ["abc", "abc"])
        XCTAssertEqual("abc\nabc\r".splitlines(true), ["abc\n", "abc\r"])
        XCTAssertEqual("abc\r\nabc\n".splitlines(), ["abc", "abc"])
        XCTAssertEqual("abc\r\nabc\n".splitlines(true), ["abc\r\n", "abc\n"])
    }
    func testStartswith() throws {
        let s1 = "hello"
        let s2 = "hello world!"
        let pos: [String] = ["hello", "world", "!"]

        XCTAssertTrue(s1.startswith(pos))
        XCTAssertFalse(s1.startswith("world"))
        XCTAssertTrue(s2.startswith("hello"))
        XCTAssertTrue(s2.startswith("h"))
    }
    func testStrip() throws {
        XCTAssertEqual("".strip(), "")
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
        XCTAssertEqual(str.zfill(1), "abc")
        XCTAssertEqual(str.zfill(5), "00abc")
        XCTAssertEqual(plus.zfill(5), "+0012")
        XCTAssertEqual(minus.zfill(5), "-0003")
        XCTAssertEqual(plus.zfill(2), "+12")
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
