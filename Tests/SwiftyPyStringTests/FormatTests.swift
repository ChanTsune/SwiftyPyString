//
//  FormatTests.swift
//  SwiftyPyStringTests
//
//
import XCTest
@testable import SwiftyPyString

final class FormatTests: XCTestCase {
    func testSimpleFormat() throws {
        let str = "{}"
        XCTAssertEqual(str.format(""), "")
        XCTAssertEqual(str.format("12"), "12")
    }
    func testSimpleFormat2Items() throws {
        let str = "{}{}"
        XCTAssertEqual(str.format(1, 12), "112")
        XCTAssertEqual(str.format("12", 4), "124")
    }
    func testSimpleFormatFloat() throws {
        let str = "{}{}"
        XCTAssertEqual(str.format(1.0, 0.1), "1.00.1")
        XCTAssertEqual(str.format(1.01, 0.1), "1.010.1")
    }
    func testFormat() throws {
        let str = "@@{}--{}##"
        XCTAssertEqual(str.format(0.001, "12"), "@@0.001--12##")
    }
    func testFormatEscape() throws {
        let str = "{{}}@@{}"
        XCTAssertEqual(str.format(1), "{}@@1")
        XCTAssertEqual("{{escape}}".format(), "{escape}")
    }
    func testEmptyFormatSpec() throws {
        XCTAssertEqual("{:}".format(""), "")
    }
    func testFormatSpecConversion() throws {
        let str = "{!a}{!s}{!r}"
        XCTAssertEqual(str.format("a", "b", "c"), "'a'b'c'")
        XCTAssertEqual(str.format(1, 2, 3), "123")
        XCTAssertEqual(str.format(1.1, 2.2, 3.3), "1.12.23.3")
    }
    func testFormatPositional() throws {
        XCTAssertEqual("{0} # {1} # {0}".format("@", "&"), "@ # & # @")
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
