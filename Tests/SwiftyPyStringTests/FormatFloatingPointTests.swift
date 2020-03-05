//
//  FormatFloatingPointTests.swift
//  SwiftyPyStringTests
//
import XCTest
@testable import SwiftyPyString

final class FormatFloatingPointTests : XCTestCase {
    func testFloatFormat() throws {
        XCTAssertEqual("{}".format(1.1), "1.1")
        XCTAssertEqual("{}".format(-1.1), "-1.1")
    }
    func testFloatFormatAlign() throws {
        XCTAssertEqual("{:5}".format(1.1), "  1.1")
        XCTAssertEqual("{:<5}".format(1.1), "1.1  ")
        XCTAssertEqual("{:^5}".format(1.1), " 1.1 ")
        XCTAssertEqual("{:>5}".format(1.1), "  1.1")
        XCTAssertEqual("{:5}".format(1.0), "  1.0")
        XCTAssertEqual("{:5}".format(-1.1), " -1.1")
        XCTAssertEqual("{:<5}".format(-1.1), "-1.1 ")
        XCTAssertEqual("{:^5}".format(-1.1), "-1.1 ")
        XCTAssertEqual("{:>5}".format(-1.1), " -1.1")
    }
    func testFloatFormatFill() throws {
        XCTAssertEqual("{:a<5}".format(1.1), "1.1aa")
        XCTAssertEqual("{:a^5}".format(1.1), "a1.1a")
        XCTAssertEqual("{:a>5}".format(1.1), "aa1.1")
        XCTAssertEqual("{:a<5}".format(-1.1), "-1.1a")
        XCTAssertEqual("{:a^5}".format(-1.1), "-1.1a")
        XCTAssertEqual("{:a>5}".format(-1.1), "a-1.1")
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

