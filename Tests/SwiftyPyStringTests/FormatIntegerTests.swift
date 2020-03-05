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
    func testFill() throws {
        XCTAssertEqual("{:a<5}".format(1), "1aaaa")
        XCTAssertEqual("{:a^5}".format(1), "aa1aa")
        XCTAssertEqual("{:a>5}".format(1), "aaaa1")
        XCTAssertEqual("{:a<5}".format(-1), "-1aaa")
        XCTAssertEqual("{:a^5}".format(-1), "a-1aa")
        XCTAssertEqual("{:a>5}".format(-1), "aaa-1")
    }
    func testAlign() throws {
        XCTAssertEqual("{:5}".format(1), "    1")
        XCTAssertEqual("{:<5}".format(1), "1    ")
        XCTAssertEqual("{:^5}".format(1), "  1  ")
        XCTAssertEqual("{:>5}".format(1), "    1")
        XCTAssertEqual("{:=5}".format(1), "00001")
        XCTAssertEqual("{:5}".format(-1), "   -1")
        XCTAssertEqual("{:<5}".format(-1), "-1   ")
        XCTAssertEqual("{:^5}".format(-1), " -1  ")
        XCTAssertEqual("{:>5}".format(-1), "   -1")
        XCTAssertEqual("{:=5}".format(-1), "-0001")
    }
    func testSign() throws {
        XCTAssertEqual("{:+}".format(1), "+1")
        XCTAssertEqual("{:+}".format(0), "+0")
        XCTAssertEqual("{:+}".format(-1), "-1")
        XCTAssertEqual("{:-}".format(1), "1")
        XCTAssertEqual("{:-}".format(0), "0")
        XCTAssertEqual("{:-}".format(-1), "-1")
        XCTAssertEqual("{: }".format(1), " 1")
        XCTAssertEqual("{: }".format(0), " 0")
        XCTAssertEqual("{: }".format(-1), "-1")
    }
    func testWidth() throws {
        XCTAssertEqual("{:2}".format(0), " 0")
        XCTAssertEqual("{:2}".format(10), "10")
        XCTAssertEqual("{:2}".format(101), "101")
    }
    func testGroupingOption() throws {
        XCTAssertEqual("{:_}".format(0), "0")
        XCTAssertEqual("{:_}".format(10), "10")
        XCTAssertEqual("{:_}".format(210), "210")
        XCTAssertEqual("{:_}".format(3210), "3_210")
        XCTAssertEqual("{:_}".format(43210), "43_210")
        XCTAssertEqual("{:_}".format(543210), "543_210")
        XCTAssertEqual("{:_}".format(6543210), "6_543_210")
        XCTAssertEqual("{:,}".format(0), "0")
        XCTAssertEqual("{:,}".format(10), "10")
        XCTAssertEqual("{:,}".format(210), "210")
        XCTAssertEqual("{:,}".format(3210), "3,210")
        XCTAssertEqual("{:,}".format(43210), "43,210")
        XCTAssertEqual("{:,}".format(543210), "543,210")
        XCTAssertEqual("{:,}".format(6543210), "6,543,210")
    }
    func testType() throws {
        XCTAssertEqual("{:b}".format(97),"1100001")
        XCTAssertEqual("{:c}".format(97),"a")
        XCTAssertEqual("{:d}".format(97),"97")
        XCTAssertEqual("{:e}".format(97),"9.700000e+01")
        XCTAssertEqual("{:E}".format(97),"9.700000E+01")
        XCTAssertEqual("{:f}".format(97),"97.000000")
        XCTAssertEqual("{:F}".format(97),"97.000000")
        XCTAssertEqual("{:g}".format(97),"97")
        XCTAssertEqual("{:G}".format(97),"97")
        XCTAssertEqual("{:n}".format(97),"97")
        XCTAssertEqual("{:o}".format(97),"141")
        XCTAssertEqual("{:x}".format(97),"61")
        XCTAssertEqual("{:X}".format(97),"61")
        XCTAssertEqual("{:%}".format(97),"9700.000000%")
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
