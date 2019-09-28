import XCTest

import SwiftyPyStringTests

var tests = [XCTestCaseEntry]()
tests += SwiftyPyStringTests.allTests()
tests += SliceTests.allTests()
XCTMain(tests)
