//
//  FormatIntegerTests.swift
//  SwiftyPyStringTests
//
import XCTest
@testable import SwiftyPyString

final class FormatIntegerTests : XCTestCase {
    func testIntegerFormat() throws {
        XCTAssertEqual("{}".format(-1), "-1")
    }
    func testIntegerFormatAlign() throws {
        XCTAssertEqual("{:5}".format(1), "    1")
        XCTAssertEqual("{:<5}".format(1), "1    ")
        XCTAssertEqual("{:^5}".format(1), "  1  ")
        XCTAssertEqual("{:>5}".format(1), "    1")
    }
    func testIntegerFormatFill() throws {
        XCTAssertEqual("{:a<5}".format(1), "1aaaa")
        XCTAssertEqual("{:a^5}".format(1), "aa1aa")
        XCTAssertEqual("{:a>5}".format(1), "aaaa1")
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
