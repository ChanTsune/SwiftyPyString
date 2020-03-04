import XCTest

import SwiftyPyStringTests

var tests = [XCTestCaseEntry]()
tests += EmptyString.allTests()
tests += FormatTests.allTests()
tests += SliceTests.allTests()
tests += SwiftyPyStringTests.allTests()
XCTMain(tests)
