//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAsyncDNSResolver open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftAsyncDNSResolver project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAsyncDNSResolver project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import XCTest

@testable import AsyncDNSResolver

/// A synchronous failure from `ares_query_dnsrec` must surface as a thrown error without
/// freeing the query handler more than once.
final class CAresSynchronousFailureTests: XCTestCase {
    /// How many times to repeat the failing query. One over-release can land on memory that
    /// has not been reused yet and pass unnoticed, so repeat often enough that the allocator
    /// hands the box out again and the fault becomes deterministic.
    private static let iterations = 50

    /// An empty server list is the simplest way to reach a synchronous failure offline, and it
    /// needs no network, no routing changes and no privileges.
    private func makeResolverWithNoServers() throws -> CAresDNSResolver {
        var options = CAresDNSResolver.Options()
        options.servers = []
        return try CAresDNSResolver(options: options)
    }

    func test_synchronousFailure_throwsAndDoesNotDoubleFreeTheQueryHandler() async throws {
        let resolver = try self.makeResolverWithNoServers()

        for iteration in 0..<Self.iterations {
            do {
                _ = try await resolver.queryA(name: "example.com")
                XCTFail("iteration \(iteration): a query with no configured servers should not succeed")
            } catch is AsyncDNSResolver.Error {
                // Expected: the synchronous status reached the caller as a thrown error.
            } catch {
                XCTFail("iteration \(iteration): expected AsyncDNSResolver.Error, got \(error)")
            }
        }
    }
}
