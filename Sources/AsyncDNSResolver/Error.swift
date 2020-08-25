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

// MARK: - Async DNS resolver errors

extension AsyncDNSResolver {
    public struct Error: Swift.Error, CustomStringConvertible {
        enum Code: Equatable, CustomStringConvertible {
            case noData(String?)
            case invalidQuery(String?)
            case serverFailure(String?)
            case notFound(String?)
            case notImplemented(String?)
            case serverRefused(String?)
            case badQuery(String?)
            case badName(String?)
            case badFamily(String?)
            case badResponse(String?)
            case connectionRefused(String?)
            case timeout(String?)
            case eof(String?)
            case fileIO(String?)
            case noMemory(String?)
            case destruction(String?)
            case badString(String?)
            case badFlags(String?)
            case noName(String?)
            case badHints(String?)
            case service(String?)
            case notInitialized(String?)
            case cancelled(String?)
            case other(code: Int32, String?)

            var description: String {
                switch self {
                case .noData(let description):
                    return "No data: \(description ?? "")"
                case .invalidQuery(let description):
                    return "Invalid query: \(description ?? "")"
                case .serverFailure(let description):
                    return "Server failure: \(description ?? "")"
                case .notFound(let description):
                    return "Not found: \(description ?? "")"
                case .notImplemented(let description):
                    return "Not implemented: \(description ?? "")"
                case .serverRefused(let description):
                    return "Server refused: \(description ?? "")"
                case .badQuery(let description):
                    return "Bad query: \(description ?? "")"
                case .badName(let description):
                    return "Bad name: \(description ?? "")"
                case .badFamily(let description):
                    return "Bad family: \(description ?? "")"
                case .badResponse(let description):
                    return "Bad response: \(description ?? "")"
                case .connectionRefused(let description):
                    return "Connection refused: \(description ?? "")"
                case .timeout(let description):
                    return "Timeout: \(description ?? "")"
                case .eof(let description):
                    return "EOF: \(description ?? "")"
                case .fileIO(let description):
                    return "File IO: \(description ?? "")"
                case .noMemory(let description):
                    return "No memory: \(description ?? "")"
                case .destruction(let description):
                    return "Destruction: \(description ?? "")"
                case .badString(let description):
                    return "Bad string: \(description ?? "")"
                case .badFlags(let description):
                    return "Bad flags: \(description ?? "")"
                case .noName(let description):
                    return "No name: \(description ?? "")"
                case .badHints(let description):
                    return "Bad hints: \(description ?? "")"
                case .service(let description):
                    return "Service: \(description ?? "")"
                case .notInitialized(let description):
                    return "Not initialized: \(description ?? "")"
                case .cancelled(let description):
                    return "Cancelled: \(description ?? "")"
                case .other(let code, let description):
                    return "Other code [\(code)]: \(description ?? "")"
                }
            }
        }

        let code: Code

        private init(code: Code) {
            self.code = code
        }

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
            case ARES_ESERVICE:
                self = .service(description)
            case ARES_ENOTINITIALIZED:
                self = .notInitialized(description)
            case ARES_ECANCELLED:
                self = .cancelled(description)
            default:
                self = .other(code: code, description)
            }
        }

        public var description: String {
            "\(self.code)"
        }

        public static func noData(_ description: String? = nil) -> Error {
            .init(code: .noData(description))
        }

        public static func invalidQuery(_ description: String? = nil) -> Error {
            .init(code: .invalidQuery(description))
        }

        public static func serverFailure(_ description: String? = nil) -> Error {
            .init(code: .serverFailure(description))
        }

        public static func notFound(_ description: String? = nil) -> Error {
            .init(code: .notFound(description))
        }

        public static func notImplemented(_ description: String? = nil) -> Error {
            .init(code: .notImplemented(description))
        }

        public static func serverRefused(_ description: String? = nil) -> Error {
            .init(code: .serverRefused(description))
        }

        public static func badQuery(_ description: String? = nil) -> Error {
            .init(code: .badQuery(description))
        }

        public static func badName(_ description: String? = nil) -> Error {
            .init(code: .badName(description))
        }

        public static func badFamily(_ description: String? = nil) -> Error {
            .init(code: .badFamily(description))
        }

        public static func badResponse(_ description: String? = nil) -> Error {
            .init(code: .badResponse(description))
        }

        public static func connectionRefused(_ description: String? = nil) -> Error {
            .init(code: .connectionRefused(description))
        }

        public static func timeout(_ description: String? = nil) -> Error {
            .init(code: .timeout(description))
        }

        public static func eof(_ description: String? = nil) -> Error {
            .init(code: .eof(description))
        }

        public static func fileIO(_ description: String? = nil) -> Error {
            .init(code: .fileIO(description))
        }

        public static func noMemory(_ description: String? = nil) -> Error {
            .init(code: .noMemory(description))
        }

        public static func destruction(_ description: String? = nil) -> Error {
            .init(code: .destruction(description))
        }

        public static func badString(_ description: String? = nil) -> Error {
            .init(code: .badString(description))
        }

        public static func badFlags(_ description: String? = nil) -> Error {
            .init(code: .badFlags(description))
        }

        public static func noName(_ description: String? = nil) -> Error {
            .init(code: .noName(description))
        }

        public static func badHints(_ description: String? = nil) -> Error {
            .init(code: .badHints(description))
        }

        public static func service(_ description: String? = nil) -> Error {
            .init(code: .service(description))
        }

        public static func notInitialized(_ description: String? = nil) -> Error {
            .init(code: .notInitialized(description))
        }

        public static func cancelled(_ description: String? = nil) -> Error {
            .init(code: .cancelled(description))
        }

        public static func other(code: Int32, _ description: String? = nil) -> Error {
            .init(code: .other(code: code, description))
        }
    }
}
