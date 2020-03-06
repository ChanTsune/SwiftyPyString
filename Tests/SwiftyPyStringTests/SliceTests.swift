//
//  SliceTests.swift
//  SwiftyPyStringTests
//

import XCTest
@testable import SwiftyPyString

final class SliceTests: XCTestCase {
    func testSliceInit() throws {
        let slice1 = Slice(stop: 1)
        XCTAssertNil(slice1.start)
        XCTAssertEqual(slice1.stop, 1)
        XCTAssertNil(slice1.step)

        let slice2 = Slice(start: 1, stop: 2)
        XCTAssertEqual(slice2.start, 1)
        XCTAssertEqual(slice2.stop, 2)
        XCTAssertNil(slice2.step)

        let slice3 = Slice(start: 1, stop: 2, step: 3)
        XCTAssertEqual(slice3.start, 1)
        XCTAssertEqual(slice3.stop, 2)
        XCTAssertEqual(slice3.step, 3)
    }
    func testIndicse() throws {
        let slice = Slice(stop: nil)
        XCTAssert(slice.indices(10) == (0, 10, 1))
    }
    func testSubscriptByInt() {
        let str = "0123456789"
        XCTAssertEqual(str[1], "1")
        XCTAssertEqual(str[2], "2")
        XCTAssertEqual(str[-1], "9")
        XCTAssertEqual(str[-2], "8")
        XCTAssertEqual(str[-3], "7")
    }
    func testSlice() throws {
        let str = "0123456789"
        XCTAssertEqual(str[1, 1], "")
        XCTAssertEqual(str[1, 2], "1")
        XCTAssertEqual(str[0, 20], "0123456789")
        XCTAssertEqual(str[0, 10, 2], "02468")
        XCTAssertEqual(str[0, 10, 3], "0369")
    }
    func testSliceNil() throws {
        let str = "0123456789"
        XCTAssertEqual(str[1, nil], "123456789")
        XCTAssertEqual(str[nil, nil, 2], "02468")
        XCTAssertEqual(str[nil, 5], "01234")
        XCTAssertEqual(str[nil, nil, nil], "0123456789")
    }
    func testSliceNegate() throws {
        let str = "0123456789"
        XCTAssertEqual(str[-5, -1], "5678")
        XCTAssertEqual(str[-5, -20], "")
        XCTAssertEqual(str[nil, nil, -1], "9876543210")
        XCTAssertEqual(str[nil, nil, -2], "97531")
    }
    func testSliceEmpty() throws {
        let empty = ""
        XCTAssertEqual(empty[0, 0], "")
        XCTAssertEqual(empty[0, -1], "")
        XCTAssertEqual(empty[0, 1], "")
        XCTAssertEqual(empty[-1, 0], "")
        XCTAssertEqual(empty[1, 0], "")
    }
    func testAssign() throws {
        var str = "01234"
        str[0] = "4"
        XCTAssertEqual(str, "41234")
    }
    func testSliceable() throws {
        let list = [1, 2, 3]
        XCTAssertEqual(list[nil, nil, -1], [3, 2, 1])
        XCTAssertEqual(list[0], 1)
    }
    static var allTests = [
        ("testSliceInit", testSliceInit),
    ]
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

extension Array: Sliceable { }
