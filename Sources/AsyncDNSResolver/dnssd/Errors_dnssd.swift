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

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension AsyncDNSResolver.Error {
    /// Create an ``AsyncDNSResolver/AsyncDNSResolver/Error`` from a DNSSD error code.
    init(dnssdCode code: Int32, _ description: String = "") {
        self.message = description
        self.source = DNSSDError(code: Int(code))

        switch Int(code) {
        case kDNSServiceErr_BadFlags, kDNSServiceErr_BadParam, kDNSServiceErr_Invalid:
            self.code = .badQuery
        case kDNSServiceErr_Refused:
            self.code = .connectionRefused
        case kDNSServiceErr_Timeout:
            self.code = .timeout
        default:
            self.code = .internalError
        }
    }
}

#endif
