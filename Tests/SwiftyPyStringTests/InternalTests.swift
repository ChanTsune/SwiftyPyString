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
}
