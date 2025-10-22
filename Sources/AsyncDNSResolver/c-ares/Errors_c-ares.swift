//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAsyncDNSResolver open source project
//
// Copyright (c) 2020-2024 Apple Inc. and the SwiftAsyncDNSResolver project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAsyncDNSResolver project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CAsyncDNSResolver

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension AsyncDNSResolver.Error {
    /// Create an ``AsyncDNSResolver/AsyncDNSResolver/Error`` from c-ares error code.
    init(cAresCode: Int32, _ description: String = "") {
        self.message = description
        self.source = CAresError(code: Int(cAresCode))

        switch Int32(cAresCode) {
        case Int32(ARES_EFORMERR.rawValue), Int32(ARES_EBADQUERY.rawValue), Int32(ARES_EBADNAME.rawValue), Int32(ARES_EBADFAMILY.rawValue), Int32(ARES_EBADFLAGS.rawValue):
            self.code = .badQuery
        case Int32(ARES_EBADRESP.rawValue):
            self.code = .badResponse
        case Int32(ARES_ECONNREFUSED.rawValue):
            self.code = .connectionRefused
        case Int32(ARES_ETIMEOUT.rawValue):
            self.code = .timeout
        default:
            self.code = .internalError
        }
    }
}
