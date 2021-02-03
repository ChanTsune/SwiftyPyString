//
//  InternalTests.swift
//  SwiftyPyStringTests
//

import Foundation
import XCTest
@testable import SwiftyPyString

class InternalTests: XCTestCase {
    func test_StringProtocol_slice() {
        let str = "0123456789"
        XCTAssertEqual(str.slice(start: 0, end: 10), "0123456789")
        XCTAssertEqual(str.slice(start: 0, end: 9), "012345678")
        XCTAssertEqual(str.slice(start: 2, end: 10), "23456789")
    }
    func test_StringProtocol_dropLast_while() {
        let str = "012345"
        XCTAssertEqual(str.dropLast(while: { $0 == "5" }), "01234")
        XCTAssertEqual(str.dropLast(while: { $0 == "4" }), "012345")
    }
}
