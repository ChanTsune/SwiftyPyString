//
//  FormatTests.swift
//  SwiftyPyStringTests
//
//
import XCTest
@testable import SwiftyPyString

final class FormatTests: XCTestCase {
    func testSimpleFormat() throws {
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
    func testFormatNamed() throws {
        XCTAssertEqual("{key}:{value}".format(kwargs:["key":"Swift","value":"Python"]), "Swift:Python")
    }
    func testRecursion() throws {
        XCTAssertEqual("{0:{1}}".format("abc", "s"), "abc")
        XCTAssertEqual("{0:{1}}".format("abc", "{<5"), "abc{{")
    }
    func testMapString() throws {
        let m = ["swift": 1, "python": 2]
        XCTAssertEqual("{0[swift]}".format(m), "1")
        XCTAssertEqual("{0[swift]:}".format(m), "1")
        XCTAssertEqual("{0[python]:03}".format(m), "002")
    }
    func testMapInteger() throws {
        let m = [1: 1, 2: 2]
        XCTAssertEqual("{0[1]}".format(m), "1")
        XCTAssertEqual("{0[1]:}".format(m), "1")
        XCTAssertEqual("{0[2]:03}".format(m), "002")
    }
    func testArray() throws {
        let a = [1, 2]
        XCTAssertEqual("{0[0]}".format(a), "1")
        XCTAssertEqual("{0[0]:}".format(a), "1")
        XCTAssertEqual("{0[1]:03}".format(a), "002")
    }
    func testAttribute() throws {
        struct A {
            var field: Int
        }
        let a = A(field: 12)
        XCTAssertEqual("{0.field}".format(a), "12")
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
