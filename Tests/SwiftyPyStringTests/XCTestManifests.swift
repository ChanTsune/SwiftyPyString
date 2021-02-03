import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(EmptyStringTests.allTests),
        testCase(FormatComplexTests.allTests),
        testCase(FormatFloatingPointTests.allTests),
        testCase(FormatIntegerTests.allTests),
        testCase(FormatStringTests.allTests),
        testCase(FormatTests.allTests),
        testCase(SliceTests.allTests),
        testCase(SwiftyPyStringTests.allTests),
        testCase(PythonCompliantStringTests.allTests),
    ]
}
#endif
