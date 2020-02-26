//
//  FormatTests.swift
//  SwiftyPyStringTests
//
//
import XCTest
@testable import SwiftyPyString

final class FormatTests : XCTestCase {
    func testSimpleFormat() throws {
        let str = "{}"
        XCTAssertEqual(str.format(nil), "nil")
        XCTAssertEqual(str.format("12"), "12")
    }
    func testSimpleFormat2Items() throws {
        let str = "{}{}"
        XCTAssertEqual(str.format(1,12), "112")
        XCTAssertEqual(str.format("12",4), "124")
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
