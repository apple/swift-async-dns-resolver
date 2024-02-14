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

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension AsyncDNSResolver {
    /// Possible ``AsyncDNSResolver/AsyncDNSResolver`` errors.
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
            case notInitialized(String?)
            case initError(String?)
            case cancelled(String?)
            case service(String?)
            case other(code: Int, String?)

            var description: String {
                switch self {
                case .noData(let description):
                    return "no data: \(description ?? "")"
                case .invalidQuery(let description):
                    return "invalid query: \(description ?? "")"
                case .serverFailure(let description):
                    return "server failure: \(description ?? "")"
                case .notFound(let description):
                    return "not found: \(description ?? "")"
                case .notImplemented(let description):
                    return "not implemented: \(description ?? "")"
                case .serverRefused(let description):
                    return "server refused: \(description ?? "")"
                case .badQuery(let description):
                    return "bad query: \(description ?? "")"
                case .badName(let description):
                    return "bad name: \(description ?? "")"
                case .badFamily(let description):
                    return "bad family: \(description ?? "")"
                case .badResponse(let description):
                    return "bad response: \(description ?? "")"
                case .connectionRefused(let description):
                    return "connection refused: \(description ?? "")"
                case .timeout(let description):
                    return "timeout: \(description ?? "")"
                case .eof(let description):
                    return "EOF: \(description ?? "")"
                case .fileIO(let description):
                    return "file IO: \(description ?? "")"
                case .noMemory(let description):
                    return "no memory: \(description ?? "")"
                case .destruction(let description):
                    return "destruction: \(description ?? "")"
                case .badString(let description):
                    return "bad string: \(description ?? "")"
                case .badFlags(let description):
                    return "bad flags: \(description ?? "")"
                case .noName(let description):
                    return "no name: \(description ?? "")"
                case .badHints(let description):
                    return "bad hints: \(description ?? "")"
                case .notInitialized(let description):
                    return "not initialized: \(description ?? "")"
                case .initError(let description):
                    return "initialization error: \(description ?? "")"
                case .cancelled(let description):
                    return "cancelled: \(description ?? "")"
                case .service(let description):
                    return "service: \(description ?? "")"
                case .other(let code, let description):
                    return "other [\(code)]: \(description ?? "")"
                }
            }
        }

        let code: Code

        private init(code: Code) {
            self.code = code
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

        public static func notInitialized(_ description: String? = nil) -> Error {
            .init(code: .notInitialized(description))
        }

        public static func initError(_ description: String? = nil) -> Error {
            .init(code: .initError(description))
        }

        public static func cancelled(_ description: String? = nil) -> Error {
            .init(code: .cancelled(description))
        }

        public static func service(_ description: String? = nil) -> Error {
            .init(code: .service(description))
        }

        public static func other(code: Int, _ description: String? = nil) -> Error {
            .init(code: .other(code: code, description))
        }
    }
}
