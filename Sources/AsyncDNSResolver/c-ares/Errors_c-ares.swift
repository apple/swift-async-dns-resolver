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
    init(code: Int32, _ description: String = "") {
        switch code {
        case ARES_EFORMERR:
            self = .init(code: .invalidQuery, message: description)
        case ARES_ESERVFAIL:
            self = .init(code: .serverFailure, message: description)
        case ARES_ENOTFOUND:
            self = .init(code: .notFound, message: description)
        case ARES_ENOTIMP:
            self = .init(code: .notImplemented, message: description)
        case ARES_EREFUSED:
            self = .init(code: .serverRefused, message: description)
        case ARES_EBADQUERY:
            self = .init(code: .badQuery, message: description)
        case ARES_EBADNAME:
            self = .init(code: .badName, message: description)
        case ARES_EBADFAMILY:
            self = .init(code: .badFamily, message: description)
        case ARES_EBADRESP:
            self = .init(code: .badResponse, message: description)
        case ARES_ECONNREFUSED:
            self = .init(code: .connectionRefused, message: description)
        case ARES_ETIMEOUT:
            self = .init(code: .timeout, message: description)
        case ARES_EOF:
            self = .init(code: .eof, message: description)
        case ARES_EFILE:
            self = .init(code: .fileIO, message: description)
        case ARES_ENOMEM:
            self = .init(code: .noMemory, message: description)
        case ARES_EDESTRUCTION:
            self = .init(code: .destruction, message: description)
        case ARES_EBADSTR:
            self = .init(code: .badString, message: description)
        case ARES_EBADFLAGS:
            self = .init(code: .badFlags, message: description)
        case ARES_ENONAME:
            self = .init(code: .noName, message: description)
        case ARES_EBADHINTS:
            self = .init(code: .badHints, message: description)
        case ARES_ENOTINITIALIZED:
            self = .init(code: .notInitialized, message: description)
        case ARES_ELOADIPHLPAPI, ARES_EADDRGETNETWORKPARAMS:
            self = .init(code: .initError, message: description)
        case ARES_ECANCELLED:
            self = .init(code: .cancelled, message: description)
        case ARES_ESERVICE:
            self = .init(code: .service, message: description)
        default:
            self = .init(code: .other(Int(code)), message: description)
        }
    }
}
