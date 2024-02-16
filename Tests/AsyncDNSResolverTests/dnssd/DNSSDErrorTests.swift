//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAsyncDNSResolver open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAsyncDNSResolver project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAsyncDNSResolver project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import dnssd
@testable import AsyncDNSResolver
import XCTest

final class DNSSDErrorTests: XCTestCase {
    func test_initFromCode() {
        let inputs: [Int: AsyncDNSResolver.Error.Code] = [
            kDNSServiceErr_BadFlags: .badQuery,
            kDNSServiceErr_BadParam: .badQuery,
            kDNSServiceErr_Invalid: .badQuery,
            kDNSServiceErr_Refused: .connectionRefused,
            kDNSServiceErr_Timeout: .timeout
        ]

        for (code, expected) in inputs {
            let error = AsyncDNSResolver.Error(dnssdCode: Int32(code), "some error")
            XCTAssertEqual(error.code, expected)
            XCTAssertEqual(error.message, "some error", "Expected description to be \"some error\", got \(error.message)")
        }
    }
}
#endif
