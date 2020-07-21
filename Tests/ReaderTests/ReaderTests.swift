
import XCTest
@testable import Reader

private let myReader = AnyReader<Int, String> { int in "\(int)" }

private struct MyError: Error { var description: String }

final class ReaderTests: XCTestCase {
    func testAnyReader() {
        XCTAssertEqual("2", myReader.run(2))
    }

    func testFlatMap() {
        let foo = AnyReader<Int, String> { "foo: \($0)" }
        let bar = AnyReader<Int, String> { "bar: \($0)" }
        let x = myReader
            .flatMap { $0 == "1" ? foo : bar }

        XCTAssertEqual("foo: 1", x.run(1))
        XCTAssertEqual("bar: 99", x.run(99))
    }

    func testFold() {
        let x = myReader
            .tryMap { string throws -> String in
                if string == "0" {
                    throw MyError(description: "foo")
                }
                return "\(string)!"
        }
        .fold(
            transformValue: { $0.count },
            transformError: { ($0 as! MyError).description.count }
        )

        XCTAssertEqual(2, x.run(1))
        XCTAssertEqual(3, x.run(0))
    }

    func testReplaceError() {
        let x = myReader
            .tryMap { _ in throw MyError(description: "foo") }
            .replaceError("bar")

        XCTAssertEqual(x.run(1), "bar")
    }

    func testMap() {
        let x = myReader
            .map { $0.count }

        XCTAssertEqual(9, x.run(999_999_999))
    }

    func testMapSuccess() {
        let x = myReader
            .tryMap { $0.count }
            .mapSuccess { "\($0)" }

        switch x.run(999_999_999) {
        case .failure:
            XCTFail("should not be an error")
            return
        case .success(let stringValue):
            XCTAssertEqual("9", stringValue)
        }
    }

    func testPullback() {
        let x = myReader
            .pullback(to: String.self) { $0.count }

        XCTAssertEqual("3", x.run("foo"))
    }

    func testTap() {
        var foo: String?

        let x = myReader
            .tap { foo = $0 }

        _ = x.run(9)
        XCTAssertEqual("9", foo)
    }

    func testTryMapSuccess() {
        let x = myReader
            .tryMap { $0.count }
            .tryMapSuccess { _ in throw MyError(description: "foo") }

        switch x.run(0) {
        case .failure(let error as MyError):
            XCTAssertEqual("foo", error.description)
        default:
            XCTFail("should have gotten an error")
        }
    }

    func testEraseToAnyReader() {
        let x = myReader
            .pullback(to: MyStruct.self) { $0.myString.count }
            .map { "\($0)!!?" }
            .tap { print("got a value: \($0)") }
            .eraseToAnyReader()

        XCTAssertEqual(
            "12!!?",
            x.run(
                .init(myString: "hello world!")
            )
        )
    }
}

private struct MyStruct {
    var myString: String
}
