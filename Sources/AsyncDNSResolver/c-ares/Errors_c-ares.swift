//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAsyncDNSResolver open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the SwiftAsyncDNSResolver project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAsyncDNSResolver project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CAsyncDNSResolver

extension AsyncDNSResolver.Error {
    /// Create error from c-ares error code.
    init(code: Int32, _ description: String? = nil) {
        switch code {
        case ARES_ENODATA:
            self = .noData(description)
        case ARES_EFORMERR:
            self = .invalidQuery(description)
        case ARES_ESERVFAIL:
            self = .serverFailure(description)
        case ARES_ENOTFOUND:
            self = .notFound(description)
        case ARES_ENOTIMP:
            self = .notImplemented(description)
        case ARES_EREFUSED:
            self = .serverRefused(description)
        case ARES_EBADQUERY:
            self = .badQuery(description)
        case ARES_EBADNAME:
            self = .badName(description)
        case ARES_EBADFAMILY:
            self = .badFamily(description)
        case ARES_EBADRESP:
            self = .badResponse(description)
        case ARES_ECONNREFUSED:
            self = .connectionRefused(description)
        case ARES_ETIMEOUT:
            self = .timeout(description)
        case ARES_EOF:
            self = .eof(description)
        case ARES_EFILE:
            self = .fileIO(description)
        case ARES_ENOMEM:
            self = .noMemory(description)
        case ARES_EDESTRUCTION:
            self = .destruction(description)
        case ARES_EBADSTR:
            self = .badString(description)
        case ARES_EBADFLAGS:
            self = .badFlags(description)
        case ARES_ENONAME:
            self = .noName(description)
        case ARES_EBADHINTS:
            self = .badHints(description)
        case ARES_ENOTINITIALIZED:
            self = .notInitialized(description)
        case ARES_ELOADIPHLPAPI, ARES_EADDRGETNETWORKPARAMS:
            self = .initError(description)
        case ARES_ECANCELLED:
            self = .cancelled(description)
        case ARES_ESERVICE:
            self = .service(description)
        default:
            self = .other(code: Int(code), description)
        }
    }
}
