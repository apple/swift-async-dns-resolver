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
    public struct Error: Swift.Error, Hashable, CustomStringConvertible {
        public struct Code: Hashable, Sendable {
            fileprivate enum Value: Hashable, Sendable {
                case invalidQuery
                case serverFailure
                case notFound
                case notImplemented
                case serverRefused
                case badQuery
                case badName
                case badFamily
                case badResponse
                case connectionRefused
                case timeout
                case eof
                case fileIO
                case noMemory
                case destruction
                case badString
                case badFlags
                case noName
                case badHints
                case notInitialized
                case initError
                case cancelled
                case service
                case other(Int)
            }

            fileprivate var value: Value
            private init(_ value: Value) {
                self.value = value
            }

            public static var invalidQuery: Self { Self(.invalidQuery) }

            public static var serverFailure: Self { Self(.serverFailure) }

            public static var notFound: Self { Self(.notFound) }

            public static var notImplemented: Self { Self(.notImplemented) }

            public static var serverRefused: Self { Self(.serverRefused) }

            public static var badQuery: Self { Self(.badQuery) }

            public static var badName: Self { Self(.badName) }

            public static var badFamily: Self { Self(.badFamily) }

            public static var badResponse: Self { Self(.badResponse) }

            public static var connectionRefused: Self { Self(.connectionRefused) }

            public static var timeout: Self { Self(.timeout) }

            public static var eof: Self { Self(.eof) }

            public static var fileIO: Self { Self(.fileIO) }

            public static var noMemory: Self { Self(.noMemory) }

            public static var destruction: Self { Self(.destruction) }

            public static var badString: Self { Self(.badString) }

            public static var badFlags: Self { Self(.badFlags) }

            public static var noName: Self { Self(.noName) }

            public static var badHints: Self { Self(.badHints) }

            public static var notInitialized: Self { Self(.notInitialized) }

            public static var initError: Self { Self(.initError) }

            public static var cancelled: Self { Self(.cancelled) }

            public static var service: Self { Self(.service) }

            public static func other(_ code: Int) -> Self {
                Self(.other(code))
            }
        }

        public var code: Code
        public var message: String

        public init(code: Code, message: String = "") {
            self.code = code
            self.message = message
        }

        public var description: String {
            switch self.code.value {
            case .invalidQuery:
                return "invalid query: \(self.message)"
            case .serverFailure:
                return "server failure: \(self.message)"
            case .notFound:
                return "not found: \(self.message)"
            case .notImplemented:
                return "not implemented: \(self.message)"
            case .serverRefused:
                return "server refused: \(self.message)"
            case .badQuery:
                return "bad query: \(self.message)"
            case .badName:
                return "bad name: \(self.message)"
            case .badFamily:
                return "bad family: \(self.message)"
            case .badResponse:
                return "bad response: \(self.message)"
            case .connectionRefused:
                return "connection refused: \(self.message)"
            case .timeout:
                return "timeout: \(self.message)"
            case .eof:
                return "EOF: \(self.message)"
            case .fileIO:
                return "file IO: \(self.message)"
            case .noMemory:
                return "no memory: \(self.message)"
            case .destruction:
                return "destruction: \(self.message)"
            case .badString:
                return "bad string: \(self.message)"
            case .badFlags:
                return "bad flags: \(self.message)"
            case .noName:
                return "no name: \(self.message)"
            case .badHints:
                return "bad hints: \(self.message)"
            case .notInitialized:
                return "not initialized: \(self.message)"
            case .initError:
                return "initialization error: \(self.message)"
            case .cancelled:
                return "cancelled: \(self.message)"
            case .service:
                return "service: \(self.message)"
            case .other(let code):
                return "other [\(code)]: \(self.message)"
            }
        }
    }
}
