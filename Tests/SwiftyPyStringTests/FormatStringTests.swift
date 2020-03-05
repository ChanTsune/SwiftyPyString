//
//  FormatStringTests.swift
//  SwiftyPyStringTests
//

import XCTest
@testable import SwiftyPyString

final class FormatStringTests: XCTestCase {
    func testStringFormat() throws {
        XCTAssertEqual("{}".format(""), "")
    }
    func testAlign() throws {
        XCTAssertEqual("{:5}".format("s"), "s    ")
        XCTAssertEqual("{:<5}".format("s"), "s    ")
        XCTAssertEqual("{:^5}".format("s"), "  s  ")
        XCTAssertEqual("{:>5}".format("s"), "    s")
    }
    func testFill() throws {
        XCTAssertEqual("{:0<5}".format("s"), "s0000")
        XCTAssertEqual("{:0^5}".format("s"), "00s00")
        XCTAssertEqual("{:0>5}".format("s"), "0000s")
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
