import XCTest
import UnicodeDB
import class Foundation.Bundle

final class SwiftyPyStringTests: XCTestCase {
    // func testExample() throws {
    //     // This is an example of a functional test case.
    //     // Use XCTAssert and related functions to verify your tests produce the correct
    //     // results.

    //     // Some of the APIs that we use below are available in macOS 10.13 and above.
    //     guard #available(macOS 10.13, *) else {
    //         return
    //     }

    //     let fooBinary = productsDirectory.appendingPathComponent("SwiftyPyString")

    //     let process = Process()
    //     process.executableURL = fooBinary

    //     let pipe = Pipe()
    //     process.standardOutput = pipe

    //     try process.run()
    //     process.waitUntilExit()

    //     let data = pipe.fileHandleForReading.readDataToEndOfFile()
    //     let output = String(data: data, encoding: .utf8)

    //     XCTAssertEqual(output, "Hello, world!\n")
    // }
    func test_CompileTime() throws {}
    func testSlice() throws {
        let str = "0123456789"
        XCTAssertEqual(str[1,1],"")
        XCTAssertEqual(str[1,2],"1")
        XCTAssertEqual(str[0,20],"0123456789")
        XCTAssertEqual(str[0,10,2],"02468")
        XCTAssertEqual(str[0,10,3],"0369")
    }
    func testSliceNil() throws {
        let str = "0123456789"
        XCTAssertEqual(str[1,nil],"123456789")
        XCTAssertEqual(str[nil,nil,2],"02468")
        XCTAssertEqual(str[nil,5],"01234")
        XCTAssertEqual(str[nil,nil,nil],"0123456789")
    }
    func testSliceNegate() throws {
        let str = "0123456789"
        XCTAssertEqual(str[-5,-1],"5678")
        XCTAssertEqual(str[-5,-20],"")
        XCTAssertEqual(str[nil,nil,-1],"9876543210")
        XCTAssertEqual(str[nil,nil,-2],"97531")
    }
    func testCapitalize() throws {
        let case1 = "hello world!"
        let case2 = "Hello World!"
        XCTAssertEqual(case1.capitalize(),"Hello world!")
        XCTAssertEqual(case2.capitalize(),"Hello world!")
    }
    func testCasefold() throws {
        /* code */
    }
    func testCenter() throws {
        let even = "1234"
        let odd = "123"
        XCTAssertEqual(even.center(10),"   1234   ")
        XCTAssertEqual(odd.center(10),"   123    ")
        XCTAssertEqual(even.center(10,fillchar:"0"),"0001234000")
        XCTAssertEqual(odd.center(10,fillchar:"0"),"0001230000")
    }
    func testCount() throws {
        /* code */
        XCTAssertEqual(1,1)
    }
    func testEndswith() throws {
        /* code */
    }
    func testJoin() throws {
        let arry = ["abc","def","ghi"]
        let carry:[Character] = ["a","b","c"]
        XCTAssertEqual("".join(arry),"abcdefghi")
        XCTAssertEqual("-".join(arry),"abc-def-ghi")
        XCTAssertEqual("-".join(carry),"a-b-c")
    }
    func testLjust() throws {
        let str = "abc"
        XCTAssertEqual(str.ljust(1),"abc")
        XCTAssertEqual(str.ljust(5),"  abc")
        XCTAssertEqual(str.ljust(5,fillchar:"z"),"zzabc")
    }
    func testRjust() throws {
        let str = "abc"
        XCTAssertEqual(str.rjust(1),"abc")
        XCTAssertEqual(str.rjust(5),"abc  ")
        XCTAssertEqual(str.rjust(5,fillchar:"z"),"abczz")
    }

    func testZfill() throws {
        let str = "abc"
        let plus = "+12"
        let minus = "-3"
        XCTAssertEqual(str.zfill(1),"abc")
        XCTAssertEqual(str.zfill(5),"00abc")
        XCTAssertEqual(plus.zfill(5),"+0012")
        XCTAssertEqual(minus.zfill(5),"-0003")
        XCTAssertEqual(plus.zfill(2),"+12")
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
