import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SwiftyPyStringTests.allTests),
        testCase(FormatTests.allTests),
    ]
}
#endif
