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
    func testFill() throws {
        XCTAssertEqual("{:a<5}".format(1.1), "1.1aa")
        XCTAssertEqual("{:a^5}".format(1.1), "a1.1a")
        XCTAssertEqual("{:a>5}".format(1.1), "aa1.1")
        XCTAssertEqual("{:a<5}".format(-1.1), "-1.1a")
        XCTAssertEqual("{:a^5}".format(-1.1), "-1.1a")
        XCTAssertEqual("{:a>5}".format(-1.1), "a-1.1")
    }
    func testAlign() throws {
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
    func testSign() throws {
        XCTAssertEqual("{:+}".format(1.1), "+1.1")
        XCTAssertEqual("{:+}".format(0.0), "+0.0")
        XCTAssertEqual("{:+}".format(-1.1), "-1.1")
        XCTAssertEqual("{:-}".format(1.1), "1.1")
        XCTAssertEqual("{:-}".format(0.0), "0.0")
        XCTAssertEqual("{:-}".format(-1.1), "-1.1")
        XCTAssertEqual("{: }".format(1.1), " 1.1")
        XCTAssertEqual("{: }".format(0.0), " 0.0")
        XCTAssertEqual("{: }".format(-1.1), "-1.1")
    }
    func testAlternative() throws {
        XCTAssertEqual("{:#}".format(1.1), "1.1")
    }
    func testZero() throws {
        XCTAssertEqual("{:05}".format(1.1), "001.1")
        XCTAssertEqual("{:05}".format(-1.1), "-01.1")
    }
    func testWidth() throws {
        XCTAssertEqual("{:4}".format(0.0), " 0.0")
        XCTAssertEqual("{:4}".format(10.0), "10.0")
        XCTAssertEqual("{:4}".format(101.0), "101.0")
    }
    
    func testGroupingOption() throws {
        XCTAssertEqual("{:_}".format(10001.1), "10_001.1")
    }
    func testType() throws {
        XCTAssertEqual("{:e}".format(1.1),"1.100000e+00")
        XCTAssertEqual("{:E}".format(1.1),"1.100000E+00")
        XCTAssertEqual("{:f}".format(1.1),"1.100000")
        XCTAssertEqual("{:F}".format(1.1),"1.100000")
        XCTAssertEqual("{:g}".format(1.1),"1.1")
        XCTAssertEqual("{:G}".format(1.1),"1.1")
        XCTAssertEqual("{:n}".format(1.1),"1.1")
        XCTAssertEqual("{:%}".format(1.1),"110.000000%")
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

