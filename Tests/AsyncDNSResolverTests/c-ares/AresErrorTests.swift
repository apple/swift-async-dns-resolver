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

import CAsyncDNSResolver
import XCTest

@testable import AsyncDNSResolver

final class AresErrorTests: XCTestCase {
    func test_initFromCode() {
        let inputs: [Int32: AsyncDNSResolver.Error.Code] = [
            ARES_EFORMERR: .badQuery,
            ARES_EBADQUERY: .badQuery,
            ARES_EBADNAME: .badQuery,
            ARES_EBADFAMILY: .badQuery,
            ARES_EBADFLAGS: .badQuery,
            ARES_EBADRESP: .badResponse,
            ARES_ECONNREFUSED: .connectionRefused,
            ARES_ETIMEOUT: .timeout,
        ]

        for (code, expected) in inputs {
            let error = AsyncDNSResolver.Error(cAresCode: code, "some error")
            XCTAssertEqual(error.code, expected)
            XCTAssertEqual(
                error.message,
                "some error",
                "Expected description to be \"some error\", got \(error.message)"
            )
        }
    }
}
