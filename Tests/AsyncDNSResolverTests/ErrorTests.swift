//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAsyncDNSResolver open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAsyncDNSResolver project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAsyncDNSResolver project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

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
