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
    func testSliceable() throws {
        let list = [1, 2, 3]
        XCTAssertEqual(list[nil, nil, -1], [3, 2, 1])
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

extension Array: Sliceable {
    public subscript (_ slice: Slice) -> Array {
        var (start, _, step, loop) = slice.adjustIndex(self.count)
        var result: Array = []
        for _ in 0..<loop {
            result.append(self[start])
            start += step
        }
        return result
    }
}
