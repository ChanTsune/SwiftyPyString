import XCTest
@testable import SwiftyPyString

final class EmptyStringTests: XCTestCase {

    let empty = ""

    func testCapitalize() throws {
        XCTAssertEqual("".capitalize(), "")
    }
    func testCasefold() throws {
        XCTAssertEqual("".casefold(), "")
    }
    func testCenter() throws {
        XCTAssertEqual("".center(10), "          ")
    }
    func testCount() throws {
        XCTAssertEqual("".count("a"), 0)
        XCTAssertEqual("".count(""), 1)
        XCTAssertEqual("文字列".count(""), 4)
    }
    func testEndswith() throws {
        XCTAssertFalse(empty.endswith("world"))
        XCTAssertTrue("world".endswith(""))
        XCTAssertTrue(empty.endswith(""))
    }
    func testExpandtabs() throws {
        XCTAssertEqual("".expandtabs(), "")
        XCTAssertEqual("".expandtabs(0), "")
    }
    func testFind() throws {
        let str = "0123456789"
        XCTAssertEqual(empty.find(""), 0)
        XCTAssertEqual(empty.find("5"), -1)
        XCTAssertEqual(str.find(empty), 0)
    }
    func testIsAlnum() throws {
        XCTAssertFalse("".isalnum())
    }
    func testIsAlpha() throws {
        XCTAssertFalse("".isalpha())
    }
    func testIsAscii() throws {
        XCTAssertTrue("".isascii())
    }
    func testIsDecimal() throws {
        XCTAssertFalse("".isdecimal())
    }
    func testIsDigit() throws {
        XCTAssertFalse("".isdigit())
    }
    func testIsLower() throws {
        XCTAssertFalse("".islower())
    }
    func testIsPrintable() throws {
        XCTAssertTrue("".isprintable())
    }
    func testIsSpace() throws {
        XCTAssertFalse("".isspace())
    }
    func testIsNumeric() throws {
        XCTAssertFalse("".isnumeric())
    }
    func testIsTitle() throws {
        XCTAssertFalse("".istitle())
    }
    func testIsUpper() throws {
        XCTAssertFalse("".isupper())
    }
    func testJoin() throws {
        let arry: [String] = []
        XCTAssertEqual("".join(arry), "")
    }
    func testLjust() throws {
        XCTAssertEqual(empty.ljust(1), " ")
        XCTAssertEqual(empty.ljust(5, fillchar: "z"), "zzzzz")
    }
    func testLower() throws {
        XCTAssertEqual("".lower(), "")
    }
    func testLstrip() throws {
        XCTAssertEqual("".lstrip(), "")
    }
    func testMaketrans() throws {
        XCTAssertEqual(String.maketrans("", y: ""), [:])
    }
    func testPartition() throws {
        XCTAssert("".partition(",") == ("", "", ""))
    }
    func testReplaceEmpty() throws {
        XCTAssertEqual("".replace("", new: "p"), "p")
        XCTAssertEqual("".replace("", new: "p", count: 0), "")
        XCTAssertEqual("".replace("", new: "p", count: 1), "")
    }
    func testRfind() throws {
        XCTAssertEqual(empty.rfind(""), empty.count)
        XCTAssertEqual(empty.rfind("x"), -1)
    }
    func testRjust() throws {
        XCTAssertEqual(empty.rjust(1), " ")
        XCTAssertEqual(empty.rjust(5, fillchar: "z"), "zzzzz")
    }
    func testRpartition() throws {
        XCTAssert("".rpartition(",") == ("", "", ""))
    }
    func testRsplit() throws {
        XCTAssertEqual("".rsplit(","), [""])
        XCTAssertEqual("".rsplit(), [])
    }
    func testRstrip() throws {
        XCTAssertEqual("".rstrip(), "")
    }
    func testSplit() throws {
        XCTAssertEqual("".split(","), [""])
        XCTAssertEqual("".split(), [])
    }
    func testSplitlines() throws {
        XCTAssertEqual("".splitlines(), [])
        XCTAssertEqual("".splitlines(true), [])
    }
    func testStartswith() throws {
        XCTAssertTrue("".startswith(""))
        XCTAssertTrue("world".startswith(""))
    }
    func testStrip() throws {
        XCTAssertEqual("".strip(), "")
    }
    func testSwapcase() throws {
        XCTAssertEqual("".swapcase(), "")
    }
    func testTitle() throws {
        XCTAssertEqual("".title(), "")
    }

    func testUpper() throws {
        XCTAssertEqual("".upper(), "")
    }
    func testZfill() throws {
        XCTAssertEqual(empty.zfill(2), "00")
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
