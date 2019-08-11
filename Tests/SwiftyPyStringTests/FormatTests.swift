//
//  FormatTests.swift
//  SwiftyPyStringTests
//
//
import XCTest
@testable import SwiftyPyString

final class FormatTests : XCTestCase {
    func testFormat() throws {
        let fstr = "{}{:5}"
        XCTAssertEqual(fstr.format("12","93"), "12   93")
    }
    func testFormatFloat() throws {
        let str = FloatFormatter.SpecifiedFloatNumberFormat(1.112,accuracy: 0)
        let str2 = FloatFormatter.SpecifiedFloatNumberFormat(1.112,accuracy: 1)
        XCTAssertEqual(str, "1")
        XCTAssertEqual(str2, "1.1")
        
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
