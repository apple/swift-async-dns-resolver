@testable import AsyncDNSResolver
import CAsyncDNSResolver
import XCTest

final class ErrorTests: XCTestCase {
    func test_initFromCode() {
        let code = ARES_ENODATA
        let error = AsyncDNSResolver.Error(code: code, "some error")

        guard case .noData(let description) = error.code else {
            return XCTFail("Expected error to be .noData, got \(error.code)")
        }
        XCTAssertNotNil(description, "description should not be nil")
        XCTAssertEqual(description!, "some error", "Expected description to be \"some error\", got \(description!)")
    }
}
