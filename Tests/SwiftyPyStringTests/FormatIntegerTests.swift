//
//  FormatIntegerTests.swift
//  SwiftyPyStringTests
//
import XCTest
@testable import SwiftyPyString

final class FormatIntegerTests : XCTestCase {
    func testIntegerFormat() throws {
        XCTAssertEqual("{}".format(1), "1")
        XCTAssertEqual("{}".format(-1), "-1")
    }
    func testAlign() throws {
        XCTAssertEqual("{:5}".format(1), "    1")
        XCTAssertEqual("{:<5}".format(1), "1    ")
        XCTAssertEqual("{:^5}".format(1), "  1  ")
        XCTAssertEqual("{:>5}".format(1), "    1")
        XCTAssertEqual("{:5}".format(-1), "   -1")
        XCTAssertEqual("{:<5}".format(-1), "-1   ")
        XCTAssertEqual("{:^5}".format(-1), " -1  ")
        XCTAssertEqual("{:>5}".format(-1), "   -1")
    }
    func testFill() throws {
        XCTAssertEqual("{:a<5}".format(1), "1aaaa")
        XCTAssertEqual("{:a^5}".format(1), "aa1aa")
        XCTAssertEqual("{:a>5}".format(1), "aaaa1")
        XCTAssertEqual("{:a<5}".format(-1), "-1aaa")
        XCTAssertEqual("{:a^5}".format(-1), "a-1aa")
        XCTAssertEqual("{:a>5}".format(-1), "aaa-1")
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
