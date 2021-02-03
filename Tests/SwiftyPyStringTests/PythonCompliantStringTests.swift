import XCTest
import Foundation
@testable import SwiftyPyString

func XCTAssertEqual(_ expression1: (String, String, String), _ expression2: (String, String, String)) {
    let (e11, e12, e13) = expression1
    let (e21, e22, e23) = expression2
    XCTAssertEqual(e11, e21)
    XCTAssertEqual(e12, e22)
    XCTAssertEqual(e13, e23)
}
extension String {
    static var ASCII_LETTERS: String { "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" }
    static var DIGITS: String { "0123456789" }
}

func * (_ s: [String], n: Int) -> [String] {
    var l: [String] = []
    for _ in 0..<n {
        l.append(contentsOf: s)
    }
    return l
}

func % (_ s: String, v: Any) -> String { return "" }

class PythonCompliantStringTests: XCTestCase {
    func range(_ s: Int, _ e: Int) -> Range<Int> {
        return s..<e
    }
    func range(_ e: Int) -> Range<Int> {
        return 0..<e
    }
    func pow(_ x: Int, _ y: Int) -> Int {
        return Int(Foundation.pow(Double(x), Double(y)))
    }
    func divmod(_ x: Int, _ y: Int) -> (Int, Int) {
        return (x / y, x % y)
    }

    func test_count() throws {
        XCTAssertEqual("aaa".count("a"), 3)
        XCTAssertEqual("aaa".count("b"), 0)
        XCTAssertEqual("aaa".count("a"), 3)
        XCTAssertEqual("aaa".count("b"), 0)
        XCTAssertEqual("aaa".count("a"), 3)
        XCTAssertEqual("aaa".count("b"), 0)
        XCTAssertEqual("aaa".count("b"), 0)
        XCTAssertEqual("aaa".count("a", start: 1), 2)
        XCTAssertEqual("aaa".count("a", start: 10), 0)
        XCTAssertEqual("aaa".count("a", start: -1), 1)
        XCTAssertEqual("aaa".count("a", start: -10), 3)
        XCTAssertEqual("aaa".count("a", start: 0, end: 1), 1)
        XCTAssertEqual("aaa".count("a", start: 0, end: 10), 3)
        XCTAssertEqual("aaa".count("a", start: 0, end: -1), 2)
        XCTAssertEqual("aaa".count("a", start: 0, end: -10), 0)
        XCTAssertEqual("aaa".count("", start: 1), 3)
        XCTAssertEqual("aaa".count("", start: 3), 1)
        XCTAssertEqual("aaa".count("", start: 10), 0)
        XCTAssertEqual("aaa".count("", start: -1), 2)
        XCTAssertEqual("aaa".count("", start: -10), 4)
        XCTAssertEqual("".count(""), 1)
        XCTAssertEqual("".count("", start: 1, end: 1), 0)
        XCTAssertEqual("".count("", start: .max, end: 0), 0)
        XCTAssertEqual("".count("xx"), 0)
        XCTAssertEqual("".count("xx", start: 1, end: 1), 0)
        XCTAssertEqual("".count("xx", start: .max, end: 0), 0)
    }
    func test_find() throws {
        XCTAssertEqual("abcdefghiabc".find("abc"), 0)
        XCTAssertEqual("abcdefghiabc".find("abc", start: 1), 9)
        XCTAssertEqual("abcdefghiabc".find("def", start: 4), -1)
        XCTAssertEqual("abc".find("", start: 0), 0)
        XCTAssertEqual("abc".find("", start: 3), 3)
        XCTAssertEqual("abc".find("", start: 4), -1)
        XCTAssertEqual("rrarrrrrrrrra".find("a"), 2)
        XCTAssertEqual("rrarrrrrrrrra".find("a", start: 4), 12)
        XCTAssertEqual("rrarrrrrrrrra".find("a", start: 4, end: 6), -1)
        XCTAssertEqual("rrarrrrrrrrra".find("a", start: 4, end: nil), 12)
        XCTAssertEqual("rrarrrrrrrrra".find("a", start: nil, end: 6), 2)
        XCTAssertEqual("".find(""), 0)
        XCTAssertEqual("".find("", start: 1, end: 1), -1)
        XCTAssertEqual("".find("", start: .max, end: 0), -1)
        XCTAssertEqual("".find("xx"), -1)
        XCTAssertEqual("".find("xx", start: 1, end: 1), -1)
        XCTAssertEqual("".find("xx", start: .max, end: 0), -1)
//        XCTAssertEqual("ab".find("xxx", start: Int.max + 1, end: 0), -1)
    }
    func test_rfind() throws {
        XCTAssertEqual("abcdefghiabc".rfind("abc"), 9)
        XCTAssertEqual("abcdefghiabc".rfind(""), 12)
        XCTAssertEqual("abcdefghiabc".rfind("abcd"), 0)
        XCTAssertEqual("abcdefghiabc".rfind("abcz"), -1)
        XCTAssertEqual("abc".rfind("", start: 0), 3)
        XCTAssertEqual("abc".rfind("", start: 3), 3)
        XCTAssertEqual("abc".rfind("", start: 4), -1)
        XCTAssertEqual("rrarrrrrrrrra".rfind("a"), 12)
        XCTAssertEqual("rrarrrrrrrrra".rfind("a", start: 4), 12)
        XCTAssertEqual("rrarrrrrrrrra".rfind("a", start: 4, end: 6), -1)
        XCTAssertEqual("rrarrrrrrrrra".rfind("a", start: 4, end: nil), 12)
        XCTAssertEqual("rrarrrrrrrrra".rfind("a", start: nil, end: 6), 2)
//        XCTAssertEqual("ab".rfind("xxx", start: Int.max + 1, end: 0), -1)
        XCTAssertEqual("<......м...".rfind("<"), 0)
    }
    func test_index() throws {
        XCTAssertEqual(try "abcdefghiabc".index(""), 0)
        XCTAssertEqual(try "abcdefghiabc".index("def"), 3)
        XCTAssertEqual(try "abcdefghiabc".index("abc"), 0)
        XCTAssertEqual(try "abcdefghiabc".index("abc", start: 1), 9)
        XCTAssertThrowsError(try "abcdefghiabc".index("hib"))
        XCTAssertThrowsError(try "abcdefghiab".index("abc", start: 1))
        XCTAssertThrowsError(try "abcdefghi".index("ghi", start: 8))
        XCTAssertThrowsError(try "abcdefghi".index("ghi", start: -1))
        XCTAssertEqual(try "rrarrrrrrrrra".index("a"), 2)
        XCTAssertEqual(try "rrarrrrrrrrra".index("a", start: 4), 12)
        XCTAssertThrowsError(try "rrarrrrrrrrra".index("a", start: 4, end: 6))
        XCTAssertEqual(try "rrarrrrrrrrra".index("a", start: 4, end: nil), 12)
        XCTAssertEqual(try "rrarrrrrrrrra".index("a", start: nil, end: 6), 2)
    }
    func test_rindex() throws {
        XCTAssertEqual(try "abcdefghiabc".rindex(""), 12)
        XCTAssertEqual(try "abcdefghiabc".rindex("def"), 3)
        XCTAssertEqual(try "abcdefghiabc".rindex("abc"), 9)
        XCTAssertEqual(try "abcdefghiabc".rindex("abc", start: 0, end: -1), 0)
        XCTAssertThrowsError(try "abcdefghiabc".rindex("hib"))
        XCTAssertThrowsError(try "defghiabc".rindex("def", start: 1))
        XCTAssertThrowsError(try "defghiabc".rindex("abc", start: 0, end: -1))
        XCTAssertThrowsError(try "abcdefghi".rindex("ghi", start: 0, end: 8))
        XCTAssertThrowsError(try "abcdefghi".rindex("ghi", start: 0, end: -1))
        XCTAssertEqual(try "rrarrrrrrrrra".rindex("a"), 12)
        XCTAssertEqual(try "rrarrrrrrrrra".rindex("a", start: 4), 12)
        XCTAssertThrowsError(try "rrarrrrrrrrra".rindex("a", start: 4, end: 6))
        XCTAssertEqual(try "rrarrrrrrrrra".rindex("a", start: 4, end: nil), 12)
        XCTAssertEqual(try "rrarrrrrrrrra".rindex("a", start: nil, end: 6), 2)
    }
    func test_lower() throws {
        XCTAssertEqual("HeLLo".lower(), "hello")
        XCTAssertEqual("hello".lower(), "hello")
    }
    func test_upper() throws {
        XCTAssertEqual("HeLLo".upper(), "HELLO")
        XCTAssertEqual("HELLO".upper(), "HELLO")
    }
    func test_expandtabs() throws {
        XCTAssertEqual("abc\rab\tdef\ng\thi".expandtabs(), "abc\rab      def\ng       hi")
        XCTAssertEqual("abc\rab\tdef\ng\thi".expandtabs(8), "abc\rab      def\ng       hi")
        XCTAssertEqual("abc\rab\tdef\ng\thi".expandtabs(4), "abc\rab  def\ng   hi")
        XCTAssertEqual("abc\r\nab\tdef\ng\thi".expandtabs(), "abc\r\nab      def\ng       hi")
        XCTAssertEqual("abc\r\nab\tdef\ng\thi".expandtabs(8), "abc\r\nab      def\ng       hi")
        XCTAssertEqual("abc\r\nab\tdef\ng\thi".expandtabs(4), "abc\r\nab  def\ng   hi")
        XCTAssertEqual("abc\r\nab\r\ndef\ng\r\nhi".expandtabs(4), "abc\r\nab\r\ndef\ng\r\nhi")
        XCTAssertEqual("abc\rab\tdef\ng\thi".expandtabs(8), "abc\rab      def\ng       hi")
        XCTAssertEqual("abc\rab\tdef\ng\thi".expandtabs(4), "abc\rab  def\ng   hi")
        XCTAssertEqual(" \ta\n\tb".expandtabs(1), "  a\n b")
    }
    func test_split() throws {
        XCTAssertEqual("a|b|c|d".split("|"), ["a", "b", "c", "d"])
        XCTAssertEqual("a|b|c|d".split("|", maxsplit: 0), ["a|b|c|d"])
        XCTAssertEqual("a|b|c|d".split("|", maxsplit: 1), ["a", "b|c|d"])
        XCTAssertEqual("a|b|c|d".split("|", maxsplit: 2), ["a", "b", "c|d"])
        XCTAssertEqual("a|b|c|d".split("|", maxsplit: 3), ["a", "b", "c", "d"])
        XCTAssertEqual("a|b|c|d".split("|", maxsplit: 4), ["a", "b", "c", "d"])
        XCTAssertEqual(
            "a|b|c|d".split("|", maxsplit: Int.max - 2), ["a", "b", "c", "d"])
        XCTAssertEqual("a|b|c|d".split("|", maxsplit: 0), ["a|b|c|d"])
        XCTAssertEqual("a||b||c||d".split("|", maxsplit: 2), ["a", "", "b||c||d"])
        XCTAssertEqual("abcd".split("|"), ["abcd"])
        XCTAssertEqual("".split("|"), [""])
        XCTAssertEqual("endcase |".split("|"), ["endcase ", ""])
        XCTAssertEqual("| startcase".split("|"), ["", " startcase"])
        XCTAssertEqual("|bothcase|".split("|"), ["", "bothcase", ""])
        XCTAssertEqual("a\0\0b\0c\0d".split("\0", maxsplit: 2), ["a", "", "b\0c\0d"])
        XCTAssertEqual(("a|" * 20)[Slice(start: nil, stop: -1, step: nil)].split("|"), ["a"] * 20)
        XCTAssertEqual(("a|" * 20)[Slice(start: nil, stop: -1, step: nil)].split("|", maxsplit: 15), ["a"] * 15 + ["a|a|a|a|a"])
        XCTAssertEqual("a//b//c//d".split("//"), ["a", "b", "c", "d"])
        XCTAssertEqual("a//b//c//d".split("//", maxsplit: 1), ["a", "b//c//d"])
        XCTAssertEqual("a//b//c//d".split("//", maxsplit: 2), ["a", "b", "c//d"])
        XCTAssertEqual("a//b//c//d".split("//", maxsplit: 3), ["a", "b", "c", "d"])
        XCTAssertEqual("a//b//c//d".split("//", maxsplit: 4), ["a", "b", "c", "d"])
        XCTAssertEqual("a//b//c//d".split("//", maxsplit: Int.max - 10), ["a", "b", "c", "d"])
        XCTAssertEqual("a//b//c//d".split("//", maxsplit: 0), ["a//b//c//d"])
        XCTAssertEqual("a////b////c////d".split("//", maxsplit: 2), ["a", "", "b////c////d"])
        XCTAssertEqual("endcase test".split("test"), ["endcase ", ""])
        XCTAssertEqual("test begincase".split("test"), ["", " begincase"])
        XCTAssertEqual("test bothcase test".split("test"), ["", " bothcase ", ""])
        XCTAssertEqual("abbbc".split("bb"), ["a", "bc"])
        XCTAssertEqual("aaa".split("aaa"), ["", ""])
        XCTAssertEqual("aaa".split("aaa", maxsplit: 0), ["aaa"])
        XCTAssertEqual("abbaab".split("ba"), ["ab", "ab"])
        XCTAssertEqual("aaaa".split("aab"), ["aaaa"])
        XCTAssertEqual("".split("aaa"), [""])
        XCTAssertEqual("aa".split("aaa"), ["aa"])
        XCTAssertEqual("Abbobbbobb".split("bbobb"), ["A", "bobb"])
        XCTAssertEqual("AbbobbBbbobb".split("bbobb"), ["A", "B", ""])
        XCTAssertEqual(("aBLAH" * 20)[Slice(start: nil, stop: -4, step: nil)].split("BLAH"), ["a"] * 20)
        XCTAssertEqual(("aBLAH" * 20)[Slice(start: nil, stop: -4, step: nil)].split("BLAH", maxsplit: 19), ["a"] * 20)
        XCTAssertEqual(("aBLAH" * 20)[Slice(start: nil, stop: -4, step: nil)].split("BLAH", maxsplit: 18), ["a"] * 18 + ["aBLAHa"])
        XCTAssertEqual("a|b|c|d".split("|"), ["a", "b", "c", "d"])
        XCTAssertEqual("a|b|c|d".split("|", maxsplit: 1), ["a", "b|c|d"])
        XCTAssertEqual("a|b|c|d".split("|", maxsplit: 1), ["a", "b|c|d"])
        XCTAssertEqual("a|b|c|d".split(separator: "|", maxSplits: 1), ["a", "b|c|d"])
        XCTAssertEqual("a b c d".split(maxsplit: 1), ["a", "b c d"])
        XCTAssertThrowsError(try "hello".split(""))
        XCTAssertThrowsError(try "hello".split("", maxsplit: 0))
    }
    func test_rsplit() throws {
        XCTAssertEqual("a|b|c|d".rsplit("|"), ["a", "b", "c", "d"])
        XCTAssertEqual("a|b|c|d".rsplit("|", maxsplit: 1), ["a|b|c", "d"])
        XCTAssertEqual("a|b|c|d".rsplit("|", maxsplit: 2), ["a|b", "c", "d"])
        XCTAssertEqual("a|b|c|d".rsplit("|", maxsplit: 3), ["a", "b", "c", "d"])
        XCTAssertEqual("a|b|c|d".rsplit("|", maxsplit: 4), ["a", "b", "c", "d"])
        XCTAssertEqual("a|b|c|d".rsplit("|", maxsplit: Int.max - 100), ["a", "b", "c", "d"])
        XCTAssertEqual("a|b|c|d".rsplit("|", maxsplit: 0), ["a|b|c|d"])
        XCTAssertEqual("a||b||c||d".rsplit("|", maxsplit: 2), ["a||b||c", "", "d"])
        XCTAssertEqual("abcd".rsplit("|"), ["abcd"])
        XCTAssertEqual("".rsplit("|"), [""])
        XCTAssertEqual("| begincase".rsplit("|"), ["", " begincase"])
        XCTAssertEqual("endcase |".rsplit("|"), ["endcase ", ""])
        XCTAssertEqual("|bothcase|".rsplit("|"), ["", "bothcase", ""])
        XCTAssertEqual("a\0\0b\0c\0d".rsplit("\0", maxsplit: 2), ["a\0\0b", "c", "d"])
        XCTAssertEqual(("a|" * 20)[Slice(start: nil, stop: -1, step: nil)].rsplit("|"), ["a"] * 20)
        XCTAssertEqual(("a|" * 20)[Slice(start: nil, stop: -1, step: nil)].rsplit("|", maxsplit: 15), ["a|a|a|a|a"] + ["a"] * 15)
        XCTAssertEqual("a//b//c//d".rsplit("//"), ["a", "b", "c", "d"])
        XCTAssertEqual("a//b//c//d".rsplit("//", maxsplit: 1), ["a//b//c", "d"])
        XCTAssertEqual("a//b//c//d".rsplit("//", maxsplit: 2), ["a//b", "c", "d"])
        XCTAssertEqual("a//b//c//d".rsplit("//", maxsplit: 3), ["a", "b", "c", "d"])
        XCTAssertEqual("a//b//c//d".rsplit("//", maxsplit: 4), ["a", "b", "c", "d"])
        XCTAssertEqual("a//b//c//d".rsplit("//", maxsplit: Int.max - 5), ["a", "b", "c", "d"])
        XCTAssertEqual("a//b//c//d".rsplit("//", maxsplit: 0), ["a//b//c//d"])
        XCTAssertEqual("a////b////c////d".rsplit("//", maxsplit: 2), ["a////b////c", "", "d"])
        XCTAssertEqual("test begincase".rsplit("test"), ["", " begincase"])
        XCTAssertEqual("endcase test".rsplit("test"), ["endcase ", ""])
        XCTAssertEqual("test bothcase test".rsplit("test"), ["", " bothcase ", ""])
        XCTAssertEqual("abbbc".rsplit("bb"), ["ab", "c"])
        XCTAssertEqual("aaa".rsplit("aaa"), ["", ""])
        XCTAssertEqual("aaa".rsplit("aaa", maxsplit: 0), ["aaa"])
        XCTAssertEqual("abbaab".rsplit("ba"), ["ab", "ab"])
        XCTAssertEqual("aaaa".rsplit("aab"), ["aaaa"])
        XCTAssertEqual("".rsplit("aaa"), [""])
        XCTAssertEqual("aa".rsplit("aaa"), ["aa"])
        XCTAssertEqual("bbobbbobbA".rsplit("bbobb"), ["bbob", "A"])
        XCTAssertEqual("bbobbBbbobbA".rsplit("bbobb"), ["", "B", "A"])
        XCTAssertEqual(("aBLAH" * 20)[Slice(start: nil, stop: -4, step: nil)].rsplit("BLAH"), ["a"] * 20)
        XCTAssertEqual(("aBLAH" * 20)[Slice(start: nil, stop: -4, step: nil)].rsplit("BLAH", maxsplit: 19), ["a"] * 20)
        XCTAssertEqual(("aBLAH" * 20)[Slice(start: nil, stop: -4, step: nil)].rsplit("BLAH", maxsplit: 18), ["aBLAHa"] + ["a"] * 18)
        XCTAssertEqual("a|b|c|d".rsplit("|"), ["a", "b", "c", "d"])
        XCTAssertEqual("a|b|c|d".rsplit("|", maxsplit: 1), ["a|b|c", "d"])
        XCTAssertEqual("a|b|c|d".rsplit("|", maxsplit: 1), ["a|b|c", "d"])
        XCTAssertEqual("a|b|c|d".rsplit("|", maxsplit: 1), ["a|b|c", "d"])
        XCTAssertEqual("a b c d".rsplit(maxsplit: 1), ["a b c", "d"])
        XCTAssertThrowsError(try "hello".rsplit(""))
        XCTAssertThrowsError(try "hello".rsplit("", maxsplit: 0))
    }
    func test_replace() throws {
        XCTAssertEqual("".replace("", new: ""), "")
        XCTAssertEqual("".replace("", new: "A"), "A")
        XCTAssertEqual("".replace("A", new: ""), "")
        XCTAssertEqual("".replace("A", new: "A"), "")
        XCTAssertEqual("".replace("", new: "", count: 100), "")
        XCTAssertEqual("".replace("", new: "A", count: 100), "A")
        XCTAssertEqual("".replace("", new: "", count: .max), "")
        XCTAssertEqual("A".replace("", new: ""), "A")
        XCTAssertEqual("A".replace("", new: "*"), "*A*")
        XCTAssertEqual("A".replace("", new: "*1"), "*1A*1")
        XCTAssertEqual("A".replace("", new: "*-#"), "*-#A*-#")
        XCTAssertEqual("AA".replace("", new: "*-"), "*-A*-A*-")
        XCTAssertEqual("AA".replace("", new: "*-", count: -1), "*-A*-A*-")
        XCTAssertEqual("AA".replace("", new: "*-", count: .max), "*-A*-A*-")
        XCTAssertEqual("AA".replace("", new: "*-", count: 4), "*-A*-A*-")
        XCTAssertEqual("AA".replace("", new: "*-", count: 3), "*-A*-A*-")
        XCTAssertEqual("AA".replace("", new: "*-", count: 2), "*-A*-A")
        XCTAssertEqual("AA".replace("", new: "*-", count: 1), "*-AA")
        XCTAssertEqual("AA".replace("", new: "*-", count: 0), "AA")
        XCTAssertEqual("A".replace("A", new: ""), "")
        XCTAssertEqual("AAA".replace("A", new: ""), "")
        XCTAssertEqual("AAA".replace("A", new: "", count: -1), "")
        XCTAssertEqual("AAA".replace("A", new: "", count: .max), "")
        XCTAssertEqual("AAA".replace("A", new: "", count: 4), "")
        XCTAssertEqual("AAA".replace("A", new: "", count: 3), "")
        XCTAssertEqual("AAA".replace("A", new: "", count: 2), "A")
        XCTAssertEqual("AAA".replace("A", new: "", count: 1), "AA")
        XCTAssertEqual("AAA".replace("A", new: "", count: 0), "AAA")
        XCTAssertEqual("AAAAAAAAAA".replace("A", new: ""), "")
        XCTAssertEqual("ABACADA".replace("A", new: ""), "BCD")
        XCTAssertEqual("ABACADA".replace("A", new: "", count: -1), "BCD")
        XCTAssertEqual("ABACADA".replace("A", new: "", count: .max), "BCD")
        XCTAssertEqual("ABACADA".replace("A", new: "", count: 5), "BCD")
        XCTAssertEqual("ABACADA".replace("A", new: "", count: 4), "BCD")
        XCTAssertEqual("ABACADA".replace("A", new: "", count: 3), "BCDA")
        XCTAssertEqual("ABACADA".replace("A", new: "", count: 2), "BCADA")
        XCTAssertEqual("ABACADA".replace("A", new: "", count: 1), "BACADA")
        XCTAssertEqual("ABACADA".replace("A", new: "", count: 0), "ABACADA")
        XCTAssertEqual("ABCAD".replace("A", new: ""), "BCD")
        XCTAssertEqual("ABCADAA".replace("A", new: ""), "BCD")
        XCTAssertEqual("BCD".replace("A", new: ""), "BCD")
        XCTAssertEqual("*************".replace("A", new: ""), "*************")
        XCTAssertEqual(("^" + "A" * 1000 + "^").replace("A", new: "", count: 999), "^A^")
        XCTAssertEqual("the".replace("the", new: ""), "")
        XCTAssertEqual("theater".replace("the", new: ""), "ater")
        XCTAssertEqual("thethe".replace("the", new: ""), "")
        XCTAssertEqual("thethethethe".replace("the", new: ""), "")
        XCTAssertEqual("theatheatheathea".replace("the", new: ""), "aaaa")
        XCTAssertEqual("that".replace("the", new: ""), "that")
        XCTAssertEqual("thaet".replace("the", new: ""), "thaet")
        XCTAssertEqual("here and there".replace("the", new: ""), "here and re")
        XCTAssertEqual("here and there and there".replace("the", new: "", count: .max), "here and re and re")
        XCTAssertEqual("here and there and there".replace("the", new: "", count: -1), "here and re and re")
        XCTAssertEqual("here and there and there".replace("the", new: "", count: 3), "here and re and re")
        XCTAssertEqual("here and there and there".replace("the", new: "", count: 2), "here and re and re")
        XCTAssertEqual("here and there and there".replace("the", new: "", count: 1), "here and re and there")
        XCTAssertEqual("here and there and there".replace("the", new: "", count: 0), "here and there and there")
        XCTAssertEqual("here and there and there".replace("the", new: ""), "here and re and re")
        XCTAssertEqual("abc".replace("the", new: ""), "abc")
        XCTAssertEqual("abcdefg".replace("the", new: ""), "abcdefg")
        XCTAssertEqual("bbobob".replace("bob", new: ""), "bob")
        XCTAssertEqual("bbobobXbbobob".replace("bob", new: ""), "bobXbob")
        XCTAssertEqual("aaaaaaabob".replace("bob", new: ""), "aaaaaaa")
        XCTAssertEqual("aaaaaaa".replace("bob", new: ""), "aaaaaaa")
        XCTAssertEqual("Who goes there?".replace("o", new: "o"), "Who goes there?")
        XCTAssertEqual("Who goes there?".replace("o", new: "O"), "WhO gOes there?")
        XCTAssertEqual("Who goes there?".replace("o", new: "O", count: .max), "WhO gOes there?")
        XCTAssertEqual("Who goes there?".replace("o", new: "O", count: -1), "WhO gOes there?")
        XCTAssertEqual("Who goes there?".replace("o", new: "O", count: 3), "WhO gOes there?")
        XCTAssertEqual("Who goes there?".replace("o", new: "O", count: 2), "WhO gOes there?")
        XCTAssertEqual("Who goes there?".replace("o", new: "O", count: 1), "WhO goes there?")
        XCTAssertEqual("Who goes there?".replace("o", new: "O", count: 0), "Who goes there?")
        XCTAssertEqual("Who goes there?".replace("a", new: "q"), "Who goes there?")
        XCTAssertEqual("Who goes there?".replace("W", new: "w"), "who goes there?")
        XCTAssertEqual("WWho goes there?WW".replace("W", new: "w"), "wwho goes there?ww")
        XCTAssertEqual("Who goes there?".replace("?", new: "!"), "Who goes there!")
        XCTAssertEqual("Who goes there??".replace("?", new: "!"), "Who goes there!!")
        XCTAssertEqual("Who goes there?".replace(".", new: "!"), "Who goes there?")
        XCTAssertEqual("This is a tissue".replace("is", new: "**"), "Th** ** a t**sue")
        XCTAssertEqual("This is a tissue".replace("is", new: "**", count: .max), "Th** ** a t**sue")
        XCTAssertEqual("This is a tissue".replace("is", new: "**", count: -1), "Th** ** a t**sue")
        XCTAssertEqual("This is a tissue".replace("is", new: "**", count: 4), "Th** ** a t**sue")
        XCTAssertEqual("This is a tissue".replace("is", new: "**", count: 3), "Th** ** a t**sue")
        XCTAssertEqual("This is a tissue".replace("is", new: "**", count: 2), "Th** ** a tissue")
        XCTAssertEqual("This is a tissue".replace("is", new: "**", count: 1), "Th** is a tissue")
        XCTAssertEqual("This is a tissue".replace("is", new: "**", count: 0), "This is a tissue")
        XCTAssertEqual("bobob".replace("bob", new: "cob"), "cobob")
        XCTAssertEqual("bobobXbobobob".replace("bob", new: "cob"), "cobobXcobocob")
        XCTAssertEqual("bobob".replace("bot", new: "bot"), "bobob")
        XCTAssertEqual("Reykjavik".replace("k", new: "KK"), "ReyKKjaviKK")
        XCTAssertEqual("Reykjavik".replace("k", new: "KK", count: -1), "ReyKKjaviKK")
        XCTAssertEqual("Reykjavik".replace("k", new: "KK", count: .max), "ReyKKjaviKK")
        XCTAssertEqual("Reykjavik".replace("k", new: "KK", count: 2), "ReyKKjaviKK")
        XCTAssertEqual("Reykjavik".replace("k", new: "KK", count: 1), "ReyKKjavik")
        XCTAssertEqual("Reykjavik".replace("k", new: "KK", count: 0), "Reykjavik")
        XCTAssertEqual("A.B.C.".replace(".", new: "----"), "A----B----C----")
        XCTAssertEqual("...м......<".replace("<", new: "&lt;"), "...м......&lt;")
        XCTAssertEqual("Reykjavik".replace("q", new: "KK"), "Reykjavik")
        XCTAssertEqual("spam, spam, eggs and spam".replace("spam", new: "ham"), "ham, ham, eggs and ham")
        XCTAssertEqual("spam, spam, eggs and spam".replace("spam", new: "ham", count: .max), "ham, ham, eggs and ham")
        XCTAssertEqual("spam, spam, eggs and spam".replace("spam", new: "ham", count: -1), "ham, ham, eggs and ham")
        XCTAssertEqual("spam, spam, eggs and spam".replace("spam", new: "ham", count: 4), "ham, ham, eggs and ham")
        XCTAssertEqual("spam, spam, eggs and spam".replace("spam", new: "ham", count: 3), "ham, ham, eggs and ham")
        XCTAssertEqual("spam, spam, eggs and spam".replace("spam", new: "ham", count: 2), "ham, ham, eggs and spam")
        XCTAssertEqual("spam, spam, eggs and spam".replace("spam", new: "ham", count: 1), "ham, spam, eggs and spam")
        XCTAssertEqual("spam, spam, eggs and spam".replace("spam", new: "ham", count: 0), "spam, spam, eggs and spam")
        XCTAssertEqual("bobobob".replace("bobob", new: "bob"), "bobob")
        XCTAssertEqual("bobobobXbobobob".replace("bobob", new: "bob"), "bobobXbobob")
        XCTAssertEqual("BOBOBOB".replace("bob", new: "bobby"), "BOBOBOB")
        XCTAssertEqual("one!two!three!".replace("!", new: "@", count: 1), "one@two!three!")
        XCTAssertEqual("one!two!three!".replace("!", new: ""), "onetwothree")
        XCTAssertEqual("one!two!three!".replace("!", new: "@", count: 2), "one@two@three!")
        XCTAssertEqual("one!two!three!".replace("!", new: "@", count: 3), "one@two@three@")
        XCTAssertEqual("one!two!three!".replace("!", new: "@", count: 4), "one@two@three@")
        XCTAssertEqual("one!two!three!".replace("!", new: "@", count: 0), "one!two!three!")
        XCTAssertEqual("one!two!three!".replace("!", new: "@"), "one@two@three@")
        XCTAssertEqual("one!two!three!".replace("x", new: "@"), "one!two!three!")
        XCTAssertEqual("one!two!three!".replace("x", new: "@", count: 2), "one!two!three!")
        XCTAssertEqual("abc".replace("", new: "-"), "-a-b-c-")
        XCTAssertEqual("abc".replace("", new: "-", count: 3), "-a-b-c")
        XCTAssertEqual("abc".replace("", new: "-", count: 0), "abc")
        XCTAssertEqual("".replace("", new: ""), "")
        XCTAssertEqual("abc".replace("ab", new: "--", count: 0), "abc")
        XCTAssertEqual("abc".replace("xy", new: "--"), "abc")
        XCTAssertEqual("123".replace("123", new: ""), "")
        XCTAssertEqual("123123".replace("123", new: ""), "")
        XCTAssertEqual("123x123".replace("123", new: ""), "x")
    }
//    func test_replace_overflow() throws {
//        let A2_16 = "A" * pow(2, 16)
//        XCTAssertThrowsError(try A2_16.replace("", new: A2_16))
//        XCTAssertThrowsError(try A2_16.replace("A", new: A2_16))
//        XCTAssertThrowsError(try A2_16.replace("AA", new: A2_16 + A2_16))
//    }
    func test_removeprefix() throws {
        XCTAssertEqual("spam".removeprefix("sp"), "am")
        XCTAssertEqual("spamspamspam".removeprefix("spam"), "spamspam")
        XCTAssertEqual("spam".removeprefix("python"), "spam")
        XCTAssertEqual("spam".removeprefix("spider"), "spam")
        XCTAssertEqual("spam".removeprefix("spam and eggs"), "spam")
        XCTAssertEqual("".removeprefix(""), "")
        XCTAssertEqual("".removeprefix("abcde"), "")
        XCTAssertEqual("abcde".removeprefix(""), "abcde")
        XCTAssertEqual("abcde".removeprefix("abcde"), "")
    }
    func test_removesuffix() throws {
        XCTAssertEqual("spam".removesuffix("am"), "sp")
        XCTAssertEqual("spamspamspam".removesuffix("spam"), "spamspam")
        XCTAssertEqual("spam".removesuffix("python"), "spam")
        XCTAssertEqual("spam".removesuffix("blam"), "spam")
        XCTAssertEqual("spam".removesuffix("eggs and spam"), "spam")
        XCTAssertEqual("".removesuffix(""), "")
        XCTAssertEqual("".removesuffix("abcde"), "")
        XCTAssertEqual("abcde".removesuffix(""), "abcde")
        XCTAssertEqual("abcde".removesuffix("abcde"), "")
    }
    func test_capitalize() throws {
        XCTAssertEqual(" hello ".capitalize(), " hello ")
        XCTAssertEqual("Hello ".capitalize(), "Hello ")
        XCTAssertEqual("hello ".capitalize(), "Hello ")
        XCTAssertEqual("aaaa".capitalize(), "Aaaa")
        XCTAssertEqual("AaAa".capitalize(), "Aaaa")
    }
    func test_additional_split() throws {
        XCTAssertEqual(
            "this is the split function".split(), ["this", "is", "the", "split", "function"])
        XCTAssertEqual("a b c d ".split(), ["a", "b", "c", "d"])
        XCTAssertEqual("a b c d".split(nil, maxsplit: 1), ["a", "b c d"])
        XCTAssertEqual("a b c d".split(nil, maxsplit: 2), ["a", "b", "c d"])
        XCTAssertEqual("a b c d".split(nil, maxsplit: 3), ["a", "b", "c", "d"])
        XCTAssertEqual("a b c d".split(nil, maxsplit: 4), ["a", "b", "c", "d"])
        XCTAssertEqual("a b c d".split(nil, maxsplit: Int.max - 1), ["a", "b", "c", "d"])
        XCTAssertEqual("a b c d".split(nil, maxsplit: 0), ["a b c d"])
        XCTAssertEqual("  a b c d".split(nil, maxsplit: 0), ["a b c d"])
        XCTAssertEqual("a  b  c  d".split(nil, maxsplit: 2), ["a", "b", "c  d"])
        XCTAssertEqual("         ".split(), [])
        XCTAssertEqual("  a    ".split(), ["a"])
        XCTAssertEqual("  a    b   ".split(), ["a", "b"])
        XCTAssertEqual("  a    b   ".split(nil, maxsplit: 1), ["a", "b   "])
        XCTAssertEqual("  a    b   c   ".split(nil, maxsplit: 0), ["a    b   c   "])
        XCTAssertEqual("  a    b   c   ".split(nil, maxsplit: 1), ["a", "b   c   "])
        XCTAssertEqual("  a    b   c   ".split(nil, maxsplit: 2), ["a", "b", "c   "])
        XCTAssertEqual("  a    b   c   ".split(nil, maxsplit: 3), ["a", "b", "c"])
        XCTAssertEqual("\n\ta \t\r b \u{0B} ".split(), ["a", "b"])
        let aaa = " a " * 20
        XCTAssertEqual(aaa.split(), ["a"] * 20)
        XCTAssertEqual(aaa.split(nil, maxsplit: 1), ["a"] + [aaa[Slice(start: 4, stop: nil, step: nil)]])
        XCTAssertEqual(aaa.split(nil, maxsplit: 19), ["a"] * 19 + ["a "])
        for b in ["arf\tbarf", "arf\nbarf", "arf\rbarf", "arf\u{0C}barf", "arf\u{0B}barf"] {
            XCTAssertEqual(b.split(), ["arf", "barf"])
            XCTAssertEqual(b.split(nil), ["arf", "barf"])
            XCTAssertEqual(b.split(nil, maxsplit: 2), ["arf", "barf"])
        }
    }
    func test_additional_rsplit() throws {
        XCTAssertEqual(
            "this is the rsplit function".rsplit(), ["this", "is", "the", "rsplit", "function"])
        XCTAssertEqual("a b c d ".rsplit(), ["a", "b", "c", "d"])
        XCTAssertEqual("a b c d".rsplit(nil, maxsplit: 1), ["a b c", "d"])
        XCTAssertEqual("a b c d".rsplit(nil, maxsplit: 2), ["a b", "c", "d"])
        XCTAssertEqual("a b c d".rsplit(nil, maxsplit: 3), ["a", "b", "c", "d"])
        XCTAssertEqual("a b c d".rsplit(nil, maxsplit: 4), ["a", "b", "c", "d"])
        XCTAssertEqual("a b c d".rsplit(nil, maxsplit: Int.max - 20), ["a", "b", "c", "d"])
        XCTAssertEqual("a b c d".rsplit(nil, maxsplit: 0), ["a b c d"])
        XCTAssertEqual("a b c d  ".rsplit(nil, maxsplit: 0), ["a b c d"])
        XCTAssertEqual("a  b  c  d".rsplit(nil, maxsplit: 2), ["a  b", "c", "d"])
        XCTAssertEqual("         ".rsplit(), [])
        XCTAssertEqual("  a    ".rsplit(), ["a"])
        XCTAssertEqual("  a    b   ".rsplit(), ["a", "b"])
        XCTAssertEqual("  a    b   ".rsplit(nil, maxsplit: 1), ["  a", "b"])
        XCTAssertEqual("  a    b   c   ".rsplit(nil, maxsplit: 0), ["  a    b   c"])
        XCTAssertEqual("  a    b   c   ".rsplit(nil, maxsplit: 1), ["  a    b", "c"])
        XCTAssertEqual("  a    b   c   ".rsplit(nil, maxsplit: 2), ["  a", "b", "c"])
        XCTAssertEqual("  a    b   c   ".rsplit(nil, maxsplit: 3), ["a", "b", "c"])
        XCTAssertEqual("\n\ta \t\r b \u{0B} ".rsplit(nil, maxsplit: 88), ["a", "b"])
        let aaa = " a " * 20
        XCTAssertEqual(aaa.rsplit(), ["a"] * 20)
        XCTAssertEqual(aaa.rsplit(nil, maxsplit: 1), [aaa[Slice(start: nil, stop: -4, step: nil)]] + ["a"])
        XCTAssertEqual(aaa.rsplit(nil, maxsplit: 18), [" a  a"] + ["a"] * 18)
        for b in ["arf\tbarf", "arf\nbarf", "arf\rbarf", "arf\u{0C}barf", "arf\u{0B}barf"] {
            XCTAssertEqual(b.rsplit(), ["arf", "barf"])
            XCTAssertEqual(b.rsplit(nil), ["arf", "barf"])
            XCTAssertEqual(b.rsplit(nil, maxsplit: 2), ["arf", "barf"])
        }
    }
    func test_strip_whitespace() throws {
        XCTAssertEqual("   hello   ".strip(), "hello")
        XCTAssertEqual("   hello   ".lstrip(), "hello   ")
        XCTAssertEqual("   hello   ".rstrip(), "   hello")
        XCTAssertEqual("hello".strip(), "hello")
        let b = " \t\n\r\u{0C}\u{0B}abc \t\n\r\u{0C}\u{0B}"
        XCTAssertEqual(b.strip(), "abc")
        XCTAssertEqual(b.lstrip(), "abc \t\n\r\u{0C}\u{0B}")
        XCTAssertEqual(b.rstrip(), " \t\n\r\u{0C}\u{0B}abc")
        XCTAssertEqual("   hello   ".strip(nil), "hello")
        XCTAssertEqual("   hello   ".lstrip(nil), "hello   ")
        XCTAssertEqual("   hello   ".rstrip(nil), "   hello")
        XCTAssertEqual("hello".strip(nil), "hello")
    }
    func test_strip() throws {
        XCTAssertEqual("xyzzyhelloxyzzy".strip("xyz"), "hello")
        XCTAssertEqual("xyzzyhelloxyzzy".lstrip("xyz"), "helloxyzzy")
        XCTAssertEqual("xyzzyhelloxyzzy".rstrip("xyz"), "xyzzyhello")
        XCTAssertEqual("hello".strip("xyz"), "hello")
        XCTAssertEqual("mississippi".strip("mississippi"), "")
        XCTAssertEqual("mississippi".strip("i"), "mississipp")
    }
    func test_ljust() throws {
        XCTAssertEqual("abc".ljust(10), "abc       ")
        XCTAssertEqual("abc".ljust(6), "abc   ")
        XCTAssertEqual("abc".ljust(3), "abc")
        XCTAssertEqual("abc".ljust(2), "abc")
        XCTAssertEqual("abc".ljust(10, fillchar: "*"), "abc*******")
    }
    func test_rjust() throws {
        XCTAssertEqual("abc".rjust(10), "       abc")
        XCTAssertEqual("abc".rjust(6), "   abc")
        XCTAssertEqual("abc".rjust(3), "abc")
        XCTAssertEqual("abc".rjust(2), "abc")
        XCTAssertEqual("abc".rjust(10, fillchar: "*"), "*******abc")
    }
    func test_center() throws {
        XCTAssertEqual("abc".center(10), "   abc    ")
        XCTAssertEqual("abc".center(6), " abc  ")
        XCTAssertEqual("abc".center(3), "abc")
        XCTAssertEqual("abc".center(2), "abc")
        XCTAssertEqual("abc".center(10, fillchar: "*"), "***abc****")
    }
    func test_swapcase() throws {
        XCTAssertEqual("HeLLo cOmpUteRs".swapcase(), "hEllO CoMPuTErS")
    }
    func test_zfill() throws {
        XCTAssertEqual("123".zfill(2), "123")
        XCTAssertEqual("123".zfill(3), "123")
        XCTAssertEqual("123".zfill(4), "0123")
        XCTAssertEqual("+123".zfill(3), "+123")
        XCTAssertEqual("+123".zfill(4), "+123")
        XCTAssertEqual("+123".zfill(5), "+0123")
        XCTAssertEqual("-123".zfill(3), "-123")
        XCTAssertEqual("-123".zfill(4), "-123")
        XCTAssertEqual("-123".zfill(5), "-0123")
        XCTAssertEqual("".zfill(3), "000")
        XCTAssertEqual("34".zfill(1), "34")
        XCTAssertEqual("34".zfill(4), "0034")
    }
    func test_islower() throws {
        XCTAssertEqual("".islower(), false)
        XCTAssertEqual("a".islower(), true)
        XCTAssertEqual("A".islower(), false)
        XCTAssertEqual("\n".islower(), false)
        XCTAssertEqual("abc".islower(), true)
        XCTAssertEqual("aBc".islower(), false)
        XCTAssertEqual("abc\n".islower(), true)
    }
    func test_isupper() throws {
        XCTAssertEqual("".isupper(), false)
        XCTAssertEqual("a".isupper(), false)
        XCTAssertEqual("A".isupper(), true)
        XCTAssertEqual("\n".isupper(), false)
        XCTAssertEqual("ABC".isupper(), true)
        XCTAssertEqual("AbC".isupper(), false)
        XCTAssertEqual("ABC\n".isupper(), true)
    }
    func test_istitle() throws {
        XCTAssertEqual("".istitle(), false)
        XCTAssertEqual("a".istitle(), false)
        XCTAssertEqual("A".istitle(), true)
        XCTAssertEqual("\n".istitle(), false)
        XCTAssertEqual("A Titlecased Line".istitle(), true)
        XCTAssertEqual("A\nTitlecased Line".istitle(), true)
        XCTAssertEqual("A Titlecased, Line".istitle(), true)
        XCTAssertEqual("Not a capitalized String".istitle(), false)
        XCTAssertEqual("Not\ta Titlecase String".istitle(), false)
        XCTAssertEqual("Not--a Titlecase String".istitle(), false)
        XCTAssertEqual("NOT".istitle(), false)
    }
    func test_isspace() throws {
        XCTAssertEqual("".isspace(), false)
        XCTAssertEqual("a".isspace(), false)
        XCTAssertEqual(" ".isspace(), true)
        XCTAssertEqual("\t".isspace(), true)
        XCTAssertEqual("\r".isspace(), true)
        XCTAssertEqual("\n".isspace(), true)
        XCTAssertEqual(" \t\r\n".isspace(), true)
        XCTAssertEqual(" \t\r\na".isspace(), false)
    }
    func test_isalpha() throws {
        XCTAssertEqual("".isalpha(), false)
        XCTAssertEqual("a".isalpha(), true)
        XCTAssertEqual("A".isalpha(), true)
        XCTAssertEqual("\n".isalpha(), false)
        XCTAssertEqual("abc".isalpha(), true)
        XCTAssertEqual("aBc123".isalpha(), false)
        XCTAssertEqual("abc\n".isalpha(), false)
    }
    func test_isalnum() throws {
        XCTAssertEqual("".isalnum(), false)
        XCTAssertEqual("a".isalnum(), true)
        XCTAssertEqual("A".isalnum(), true)
        XCTAssertEqual("\n".isalnum(), false)
        XCTAssertEqual("123abc456".isalnum(), true)
        XCTAssertEqual("a1b3c".isalnum(), true)
        XCTAssertEqual("aBc000 ".isalnum(), false)
        XCTAssertEqual("abc\n".isalnum(), false)
    }
    func test_isascii() throws {
        XCTAssertEqual("".isascii(), true)
        XCTAssertEqual("\0".isascii(), true)
        XCTAssertEqual("\u{7F}".isascii(), true)
        XCTAssertEqual("\0\u{7F}".isascii(), true)
        XCTAssertEqual("".isascii(), false)
        XCTAssertEqual("é".isascii(), false)
        for p in range(8) {
            XCTAssertEqual((" " * p + "\u{7F}").isascii(), true)
            XCTAssertEqual((" " * p + "").isascii(), false)
            XCTAssertEqual((" " * p + "\u{7F}" + " " * 8).isascii(), true)
            XCTAssertEqual((" " * p + "" + " " * 8).isascii(), false)
        }
    }
    func test_isdigit() throws {
        XCTAssertEqual("".isdigit(), false)
        XCTAssertEqual("a".isdigit(), false)
        XCTAssertEqual("0".isdigit(), true)
        XCTAssertEqual("0123456789".isdigit(), true)
        XCTAssertEqual("0123456789a".isdigit(), false)
    }
    func test_title() throws {
        XCTAssertEqual(" hello ".title(), " Hello ")
        XCTAssertEqual("hello ".title(), "Hello ")
        XCTAssertEqual("Hello ".title(), "Hello ")
        XCTAssertEqual("fOrMaT thIs aS titLe String".title(), "Format This As Title String")
        XCTAssertEqual("fOrMaT,thIs-aS*titLe;String".title(), "Format,This-As*Title;String")
        XCTAssertEqual("getInt".title(), "Getint")
    }
    func test_splitlines() throws {
        XCTAssertEqual("abc\ndef\n\rghi".splitlines(), ["abc", "def", "", "ghi"])
        XCTAssertEqual("abc\ndef\n\r\nghi".splitlines(), ["abc", "def", "", "ghi"])
        XCTAssertEqual("abc\ndef\r\nghi".splitlines(), ["abc", "def", "ghi"])
        XCTAssertEqual("abc\ndef\r\nghi\n".splitlines(), ["abc", "def", "ghi"])
        XCTAssertEqual("abc\ndef\r\nghi\n\r".splitlines(), ["abc", "def", "ghi", ""])
        XCTAssertEqual("\nabc\ndef\r\nghi\n\r".splitlines(), ["", "abc", "def", "ghi", ""])
        XCTAssertEqual("\nabc\ndef\r\nghi\n\r".splitlines(false), ["", "abc", "def", "ghi", ""])
        XCTAssertEqual("\nabc\ndef\r\nghi\n\r".splitlines(true), ["\n", "abc\n", "def\r\n", "ghi\n", "\r"])
        XCTAssertEqual("\nabc\ndef\r\nghi\n\r".splitlines(false), ["", "abc", "def", "ghi", ""])
        XCTAssertEqual("\nabc\ndef\r\nghi\n\r".splitlines(true), ["\n", "abc\n", "def\r\n", "ghi\n", "\r"])
    }

    func test_capitalize_nonascii() throws {
        XCTAssertEqual("ῳῳῼῼ".capitalize(), "ῼῳῳῳ")
        XCTAssertEqual("ⓅⓎⓉⒽⓄⓃ".capitalize(), "Ⓟⓨⓣⓗⓞⓝ")
        XCTAssertEqual("ⓟⓨⓣⓗⓞⓝ".capitalize(), "Ⓟⓨⓣⓗⓞⓝ")
        XCTAssertEqual("ⅠⅡⅢ".capitalize(), "Ⅰⅱⅲ")
        XCTAssertEqual("ⅰⅱⅲ".capitalize(), "Ⅰⅱⅲ")
        XCTAssertEqual("ƛᴀᶆȡᾷ".capitalize(), "ƛᴀᶆȡᾷ")
    }
    func test_startswith() throws {
        XCTAssertEqual("hello".startswith("he"), true)
        XCTAssertEqual("hello".startswith("hello"), true)
        XCTAssertEqual("hello".startswith("hello world"), false)
        XCTAssertEqual("hello".startswith(""), true)
        XCTAssertEqual("hello".startswith("ello"), false)
        XCTAssertEqual("hello".startswith("ello", start: 1), true)
        XCTAssertEqual("hello".startswith("o", start: 4), true)
        XCTAssertEqual("hello".startswith("o", start: 5), false)
        XCTAssertEqual("hello".startswith("", start: 5), true)
        XCTAssertEqual("hello".startswith("lo", start: 6), false)
        XCTAssertEqual("helloworld".startswith("lowo", start: 3), true)
        XCTAssertEqual("helloworld".startswith("lowo", start: 3, end: 7), true)
        XCTAssertEqual("helloworld".startswith("lowo", start: 3, end: 6), false)
        XCTAssertEqual("".startswith("", start: 0, end: 1), true)
        XCTAssertEqual("".startswith("", start: 0, end: 0), true)
        XCTAssertEqual("".startswith("", start: 1, end: 0), false)
        XCTAssertEqual("hello".startswith("he", start: 0, end: -1), true)
        XCTAssertEqual("hello".startswith("he", start: -53, end: -1), true)
        XCTAssertEqual("hello".startswith("hello", start: 0, end: -1), false)
        XCTAssertEqual("hello".startswith("hello world", start: -1, end: -10), false)
        XCTAssertEqual("hello".startswith("ello", start: -5), false)
        XCTAssertEqual("hello".startswith("ello", start: -4), true)
        XCTAssertEqual("hello".startswith("o", start: -2), false)
        XCTAssertEqual("hello".startswith("o", start: -1), true)
        XCTAssertEqual("hello".startswith("", start: -3, end: -3), true)
        XCTAssertEqual("hello".startswith("lo", start: -9), false)
        XCTAssertEqual("hello".startswith(["he", "ha"]), true)
        XCTAssertEqual("hello".startswith(["lo", "llo"]), false)
        XCTAssertEqual("hello".startswith(["hellox", "hello"]), true)
        XCTAssertEqual("hello".startswith([]), false)
        XCTAssertEqual("helloworld".startswith(["hellowo", "rld", "lowo"], start: 3), true)
        XCTAssertEqual("helloworld".startswith(["hellowo", "ello", "rld"], start: 3), false)
        XCTAssertEqual("hello".startswith(["lo", "he"], start: 0, end: -1), true)
        XCTAssertEqual("hello".startswith(["he", "hel"], start: 0, end: 1), false)
        XCTAssertEqual("hello".startswith(["he", "hel"], start: 0, end: 2), true)
    }
    func test_endswith() throws {
        XCTAssertEqual("hello".endswith("lo"), true)
        XCTAssertEqual("hello".endswith("he"), false)
        XCTAssertEqual("hello".endswith(""), true)
        XCTAssertEqual("hello".endswith("hello world"), false)
        XCTAssertEqual("helloworld".endswith("worl"), false)
        XCTAssertEqual("helloworld".endswith("worl", start: 3, end: 9), true)
        XCTAssertEqual("helloworld".endswith("world", start: 3, end: 12), true)
        XCTAssertEqual("helloworld".endswith("lowo", start: 1, end: 7), true)
        XCTAssertEqual("helloworld".endswith("lowo", start: 2, end: 7), true)
        XCTAssertEqual("helloworld".endswith("lowo", start: 3, end: 7), true)
        XCTAssertEqual("helloworld".endswith("lowo", start: 4, end: 7), false)
        XCTAssertEqual("helloworld".endswith("lowo", start: 3, end: 8), false)
        XCTAssertEqual("ab".endswith("ab", start: 0, end: 1), false)
        XCTAssertEqual("ab".endswith("ab", start: 0, end: 0), false)
        XCTAssertEqual("".endswith("", start: 0, end: 1), true)
        XCTAssertEqual("".endswith("", start: 0, end: 0), true)
        XCTAssertEqual("".endswith("", start: 1, end: 0), false)
        XCTAssertEqual("hello".endswith("lo", start: -2), true)
        XCTAssertEqual("hello".endswith("he", start: -2), false)
        XCTAssertEqual("hello".endswith("", start: -3, end: -3), true)
        XCTAssertEqual("hello".endswith("hello world", start: -10, end: -2), false)
        XCTAssertEqual("helloworld".endswith("worl", start: -6), false)
        XCTAssertEqual("helloworld".endswith("worl", start: -5, end: -1), true)
        XCTAssertEqual("helloworld".endswith("worl", start: -5, end: 9), true)
        XCTAssertEqual("helloworld".endswith("world", start: -7, end: 12), true)
        XCTAssertEqual("helloworld".endswith("lowo", start: -99, end: -3), true)
        XCTAssertEqual("helloworld".endswith("lowo", start: -8, end: -3), true)
        XCTAssertEqual("helloworld".endswith("lowo", start: -7, end: -3), true)
        XCTAssertEqual("helloworld".endswith("lowo", start: 3, end: -4), false)
        XCTAssertEqual("helloworld".endswith("lowo", start: -8, end: -2), false)
        XCTAssertEqual("hello".endswith(["he", "ha"]), false)
        XCTAssertEqual("hello".endswith(["lo", "llo"]), true)
        XCTAssertEqual("hello".endswith(["hellox", "hello"]), true)
        XCTAssertEqual("hello".endswith([]), false)
        XCTAssertEqual("helloworld".endswith(["hellowo", "rld", "lowo"], start: 3), true)
        XCTAssertEqual("helloworld".endswith(["hellowo", "ello", "rld"], start: 3, end: -1), false)
        XCTAssertEqual("hello".endswith(["hell", "ell"], start: 0, end: -1), true)
        XCTAssertEqual("hello".endswith(["he", "hel"], start: 0, end: 1), false)
        XCTAssertEqual("hello".endswith(["he", "hell"], start: 0, end: 4), true)
    }
    func test___contains__() throws {
        // python's in opretor
//        XCTAssertEqual("".contains(""), true)
//        XCTAssertEqual("abc".contains(""), true)
        XCTAssertEqual("abc".contains("\0"), false)
        XCTAssertEqual("\0abc".contains("\0"), true)
        XCTAssertEqual("abc\0".contains("\0"), true)
        XCTAssertEqual("\0abc".contains("a"), true)
        XCTAssertEqual("asdf".contains("asdf"), true)
        XCTAssertEqual("asd".contains("asdf"), false)
        XCTAssertEqual("".contains("asdf"), false)
    }
    func test_subscript() throws {
        XCTAssertEqual("abc"[0], "a")
        XCTAssertEqual("abc"[-1], "c")
        XCTAssertEqual("abc"[0], "a")
        XCTAssertEqual("abc"[Slice(start: 0, stop: 3)], "abc")
        XCTAssertEqual("abc"[Slice(start: 0, stop: 1000)], "abc")
        XCTAssertEqual("abc"[Slice(start: 0, stop: 1)], "a")
        XCTAssertEqual("abc"[Slice(start: 0, stop: 0)], "")
    }
    func test_slice() throws {
        XCTAssertEqual("abc"[Slice(start: 0, stop: 1000)], "abc")
        XCTAssertEqual("abc"[Slice(start: 0, stop: 3)], "abc")
        XCTAssertEqual("abc"[Slice(start: 0, stop: 2)], "ab")
        XCTAssertEqual("abc"[Slice(start: 1, stop: 3)], "bc")
        XCTAssertEqual("abc"[Slice(start: 1, stop: 2)], "b")
        XCTAssertEqual("abc"[Slice(start: 2, stop: 2)], "")
        XCTAssertEqual("abc"[Slice(start: 1000, stop: 1000)], "")
        XCTAssertEqual("abc"[Slice(start: 2000, stop: 1000)], "")
        XCTAssertEqual("abc"[Slice(start: 2, stop: 1)], "")
    }
//    func test_extended_getslice() throws {
//        let s = String.ASCII_LETTERS + String.DIGITS
//        let indices = [0, nil, 1, 3, 41, Int.max, -1, -2, -37]
//        for start in indices {
//            for stop in indices {
//                for step in indices[Slice(start: 1, stop: nil, step: nil)] {
//                    let L = s[Slice(start: start, stop: stop, step: step)].map { $0 }
//                    XCTAssertEqual(s[Slice(start: start, stop: stop, step: step)], "".join(L))
//                }
//            }
//        }
//    }
    func test_mul() throws {
        XCTAssertEqual("abc" * -1, "")
        XCTAssertEqual("abc" * 0, "")
        XCTAssertEqual("abc" * 1, "abc")
        XCTAssertEqual("abc" * 3, "abcabcabc")
    }
    func test_join() throws {
        XCTAssertEqual(" ".join(["a", "b", "c", "d"]), "a b c d")
        XCTAssertEqual("".join(["a", "b", "c", "d"]), "abcd")
        XCTAssertEqual("".join(["", "b", "", "d"]), "bd")
        XCTAssertEqual("".join(["a", "", "c", ""]), "ac")
        XCTAssertEqual(" ".join("wxyz"), "w x y z")
        XCTAssertEqual("a".join(["abc"]), "abc")
        XCTAssertEqual("a".join(["z"]), "z")
        XCTAssertEqual(".".join(["a", "b", "c"]), "a.b.c")
        for i in [5, 25, 125] {
            XCTAssertEqual("-".join(["a" * i] * i), (("a" * i + "-") * i)[Slice(start: nil, stop: -1, step: nil)])
            XCTAssertEqual("-".join(["a" * i] * i), (("a" * i + "-") * i)[Slice(start: nil, stop: -1, step: nil)])
        }
        XCTAssertEqual(" ".join(["a", "b", "c"]), "a b c")
    }
//    func test_formatting() throws {
//        XCTAssertEqual("+%s+" % ("hello"), "+hello+")
//        XCTAssertEqual("+%d+" % (10), "+10+")
//        XCTAssertEqual("%c" % ("a"), "a")
//        XCTAssertEqual("%c" % ("a"), "a")
//        XCTAssertEqual("%c" % (34), "\"")
//        XCTAssertEqual("%c" % (36), "$")
//        XCTAssertEqual("%d" % (10), "10")
//        XCTAssertEqual("%c" % (127), "\u{7F}")
//        for ordinal in [-100, 2_097_152] {
//            XCTAssertThrowsError( try "%c" % (ordinal) )
//        }
//        let longvalue = Int.max + 10
//        let slongvalue = String(longvalue)
//        XCTAssertEqual("%3ld" % (42), " 42")
//        XCTAssertEqual("%d" % (42.0), "42")
//        XCTAssertEqual("%d" % (longvalue), slongvalue)
//        "%d" % Float(longvalue)
//        XCTAssertEqual("%07.2f" % (42), "0042.00")
//        XCTAssertEqual("%07.2F" % (42), "0042.00")
//        XCTAssertThrowsError( try "abc" % () )
//        XCTAssertThrowsError( try "%(foo)s" % (42) )
//        XCTAssertThrowsError( try "%s%s" % ((42)) )
//        XCTAssertThrowsError( try "%c" % ((nil)) )
//        XCTAssertThrowsError( try "%(foo" % (nil) )
//        XCTAssertThrowsError( try "%(foo)s %(bar)s" % (("foo", 42)) )
//        XCTAssertThrowsError( try "%d" % ("42") )
//        XCTAssertThrowsError(
//            try "%d" % (42 + nil)
//        )
//        XCTAssertEqual("%((foo))s" % (nil), "bar")
//        XCTAssertEqual("%sx" % (103 * "a"), 103 * "a" + "x")
//        XCTAssertThrowsError( try "%*s" % (("foo", "bar")) )
//        XCTAssertThrowsError( try "%10.*f" % (("foo", 42.0)) )
//        XCTAssertThrowsError( try "%10" % ((42)) )
//        XCTAssertThrowsError( try "%%%df" % self.pow(2, 64) % (3.2) )
//        XCTAssertThrowsError( try "%%.%df" % self.pow(2, 64) % (3.2) )
//        XCTAssertThrowsError(
//            try "%*s" % ((Int.max + 1, ""))
//        )
//        XCTAssertThrowsError(
//            try "%.*f" % ((Int.max + 1, 1.0 / 7))
//        )
//    }
//    func test_formatting_c_limits() throws {
//        let SIZE_MAX = 1 << PY_SSIZE_T_MAX.bit_length() + 1 - 1
//        XCTAssertThrowsError(
//            try "%*s" % ((PY_SSIZE_T_MAX + 1, ""))
//        )
//        XCTAssertThrowsError(
//            try "%.*f" % ((INT_MAX + 1, 1.0 / 7))
//        )
//        XCTAssertThrowsError(
//            try "%*s" % ((SIZE_MAX + 1, ""))
//        )
//        XCTAssertThrowsError(
//            try "%.*f" % ((UINT_MAX + 1, 1.0 / 7))
//        )
//    }
//    func test_floatformatting() throws {
//        for prec in range(100) {
//            let format = "%%.%if" % prec
//            var value = 0.01
//            for x in range(60) {
//                value = value * 3.14159265359 / 3.0 * 10.0
//                format % value
//            }
//        }
//    }
    func test_inplace_rewrites() throws {
        XCTAssertEqual("A".lower(), "a")
        XCTAssertEqual("A".isupper(), true)
        XCTAssertEqual("a".upper(), "A")
        XCTAssertEqual("a".islower(), true)
        XCTAssertEqual("A".replace("A", new: "a"), "a")
        XCTAssertEqual("A".isupper(), true)
        XCTAssertEqual("a".capitalize(), "A")
        XCTAssertEqual("a".islower(), true)
        XCTAssertEqual("a".swapcase(), "A")
        XCTAssertEqual("a".islower(), true)
        XCTAssertEqual("a".title(), "A")
        XCTAssertEqual("a".islower(), true)
    }
    func test_partition() throws {
        XCTAssertEqual(
            "this is the partition method".partition("ti"), ("this is the par", "ti", "tion method"))
        let S = "http://www.python.org"
        XCTAssertEqual(S.partition("://"), ("http", "://", "www.python.org"))
        XCTAssertEqual(S.partition("?"), ("http://www.python.org", "", ""))
        XCTAssertEqual(S.partition("http://"), ("", "http://", "www.python.org"))
        XCTAssertEqual(S.partition("org"), ("http://www.python.", "org", ""))
        XCTAssertThrowsError(try S.partition(""))
    }
    func test_rpartition() throws {
        XCTAssertEqual(
            "this is the rpartition method".rpartition("ti"), ("this is the rparti", "ti", "on method"))
        let S = "http://www.python.org"
        XCTAssertEqual(S.rpartition("://"), ("http", "://", "www.python.org"))
        XCTAssertEqual(S.rpartition("?"), ("", "", "http://www.python.org"))
        XCTAssertEqual(S.rpartition("http://"), ("", "http://", "www.python.org"))
        XCTAssertEqual(S.rpartition("org"), ("http://www.python.", "org", ""))
        XCTAssertThrowsError(try S.rpartition(""))
    }
    func test_none_arguments() throws {
        let s = "hello"
        XCTAssertEqual(s.find("l", start: nil), 2)
        XCTAssertEqual(s.find("l", start: -2, end: nil), 3)
        XCTAssertEqual(s.find("l", start: nil, end: -2), 2)
        XCTAssertEqual(s.find("h", start: nil, end: nil), 0)
        XCTAssertEqual(s.rfind("l", start: nil), 3)
        XCTAssertEqual(s.rfind("l", start: -2, end: nil), 3)
        XCTAssertEqual(s.rfind("l", start: nil, end: -2), 2)
        XCTAssertEqual(s.rfind("h", start: nil, end: nil), 0)
        XCTAssertEqual(try s.index("l", start: nil), 2)
        XCTAssertEqual(try s.index("l", start: -2, end: nil), 3)
        XCTAssertEqual(try s.index("l", start: nil, end: -2), 2)
        XCTAssertEqual(try s.index("h", start: nil, end: nil), 0)
        XCTAssertEqual(try s.rindex("l", start: nil), 3)
        XCTAssertEqual(try s.rindex("l", start: -2, end: nil), 3)
        XCTAssertEqual(try s.rindex("l", start: nil, end: -2), 2)
        XCTAssertEqual(try s.rindex("h", start: nil, end: nil), 0)
        XCTAssertEqual(s.count("l", start: nil), 2)
        XCTAssertEqual(s.count("l", start: -2, end: nil), 1)
        XCTAssertEqual(s.count("l", start: nil, end: -2), 1)
        XCTAssertEqual(s.count("x", start: nil, end: nil), 0)
        XCTAssertEqual(s.endswith("o", start: nil), true)
        XCTAssertEqual(s.endswith("lo", start: -2, end: nil), true)
        XCTAssertEqual(s.endswith("l", start: nil, end: -2), true)
        XCTAssertEqual(s.endswith("x", start: nil, end: nil), false)
        XCTAssertEqual(s.startswith("h", start: nil), true)
        XCTAssertEqual(s.startswith("l", start: -2, end: nil), true)
        XCTAssertEqual(s.startswith("h", start: nil, end: -2), true)
        XCTAssertEqual(s.startswith("x", start: nil, end: nil), false)
    }
    func test_find_etc_raise_correct_error_messages() throws {
        XCTAssertEqual("...м......<".find("<"), 10)
    }
}
