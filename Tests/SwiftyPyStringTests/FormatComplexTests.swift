//
//  FormatComplexTests.swift
//  SwiftyPyStringTests
//
import XCTest
@testable import SwiftyPyString

final class FormatComplexTests: XCTestCase {
    struct TestComplex: PSFormattableComplex {
        var real: Double
        var imag: Double
        var formatableReal: Double { return real }
        var formatableImag: Double { return imag }
    }
    let pp = TestComplex(real: 1.0, imag: 1.0)
    let pn = TestComplex(real: 1.0, imag: -1.0)
    let np = TestComplex(real: -1.0, imag: 1.0)
    let nn = TestComplex(real: -1.0, imag: -1.0)

    func testComplexFormat() throws {
        XCTAssertEqual("{}".format(pp), "(1+1j)")
        XCTAssertEqual("{}".format(pn), "(1-1j)")
        XCTAssertEqual("{}".format(np), "(-1+1j)")
        XCTAssertEqual("{}".format(nn), "(-1-1j)")
    }
    func testFill() throws {
        XCTAssertEqual("{:a>10}".format(pp), "aaaa(1+1j)")
        XCTAssertEqual("{:a>10}".format(pn), "aaaa(1-1j)")
        XCTAssertEqual("{:a>10}".format(np), "aaa(-1+1j)")
        XCTAssertEqual("{:a>10}".format(nn), "aaa(-1-1j)")
    }
    static var allTests = [
        ("testComplexFormat", testComplexFormat),
    ]

}
