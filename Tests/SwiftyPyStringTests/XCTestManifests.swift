import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SliceTests.allTests),
        testCase(SwiftyPyStringTests.allTests),
    ]
}
#endif
