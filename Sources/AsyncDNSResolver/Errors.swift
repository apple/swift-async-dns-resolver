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
        public struct Code: Hashable, Sendable {
            fileprivate enum Value: Hashable, Sendable {
                case badQuery
                case badResponse
                case connectionRefused
                case timeout
                case internalError
                case cancelled
            }

            fileprivate var value: Value
            private init(_ value: Value) {
                self.value = value
            }

            /// The query was badly formed.
            public static var badQuery: Self { Self(.badQuery) }

            /// The response couldn't be parsed.
            public static var badResponse: Self { Self(.badResponse) }

            /// The server refused to accept a connection.
            public static var connectionRefused: Self { Self(.connectionRefused) }

            /// The query timed out.
            public static var timeout: Self { Self(.timeout) }

            /// An internal error.
            public static var internalError: Self { Self(.internalError) }

            /// The query was cancelled.
            public static var cancelled: Self { Self(.cancelled) }
        }

        public var code: Code
        public var message: String
        public var source: Swift.Error?

        public init(code: Code, message: String = "", source: Swift.Error? = nil) {
            self.code = code
            self.message = message
            self.source = source
        }

        public var description: String {
            let name: String
            switch self.code.value {
            case .badQuery:
                name = "bad query"
            case .badResponse:
                name = "bad response"
            case .connectionRefused:
                name = "connection refused"
            case .timeout:
                name = "timeout"
            case .internalError:
                name = "internal"
            case .cancelled:
                name = "cancelled"
            }

            let suffix = self.source.map { " (\($0))" } ?? ""
            return "\(name): \(self.message)\(suffix)"
        }
    }
}

/// An error thrown from c-ares.
public struct CAresError: Error, Hashable, Sendable {
    /// The error code.
    public var code: Int

    public init(code: Int) {
        self.code = code
    }
}

/// An error thrown from DNSSD.
public struct DNSSDError: Error, Hashable, Sendable {
    /// The error code.
    public var code: Int

    public init(code: Int) {
        self.code = code
    }
}
