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
