import XCTest
@testable import SwiftyPyString

final class EmptyStringTests: XCTestCase {

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
        let empty: String = ""

        XCTAssertFalse(empty.endswith("world"))
        XCTAssertTrue("world".endswith(""))
        XCTAssertTrue(empty.endswith(""))
    }
    func testExpandtabs() throws {
        XCTAssertEqual("".expandtabs(), "")
        XCTAssertEqual("".expandtabs(0), "")
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
