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

/// A synchronous failure from `ares_query_dnsrec` must surface as a thrown error and must
/// free the query handler exactly once.
///
/// c-ares invokes the query callback *and* returns the error on every reachable synchronous
/// failure path, so the returned status is not evidence that the callback was skipped. The
/// callback owns the handler box and frees it, which means a second free on the error return
/// is a release of freed memory: either a `swift_release` on a recycled allocation or a
/// `POINTER_BEING_FREED_WAS_NOT_ALLOCATED` abort, both of which kill the process rather than
/// failing an assertion.
final class CAresSynchronousFailureTests: XCTestCase {
    /// How many times to repeat the failing query. One over-release can land on memory that
    /// has not been reused yet and pass unnoticed, so repeat often enough that the allocator
    /// hands the box out again and the fault becomes deterministic.
    private static let iterations = 50

    /// An empty server list is the simplest way to reach a synchronous failure offline, and it
    /// needs no network, no routing changes and no privileges. `AresChannel` joins the list into
    /// a CSV and hands it to `ares_set_servers_ports_csv`, which treats an empty string as
    /// "blank all servers" and succeeds, leaving the channel with none. Every subsequent query
    /// then takes the `ares_slist_len(channel->servers) == 0` path in `ares_send.c`, which calls
    /// the callback with `ARES_ENOSERVER` and returns the same status.
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

    /// The same failure through every query type, since each builds its own reply parser around
    /// the shared handler box and a leak or an extra release in any one of them is the same bug.
    func test_synchronousFailure_throwsForEveryQueryType() async throws {
        let resolver = try self.makeResolverWithNoServers()

        for iteration in 0..<5 {
            await self.assertThrows("queryA", iteration) { _ = try await resolver.queryA(name: "example.com") }
            await self.assertThrows("queryAAAA", iteration) { _ = try await resolver.queryAAAA(name: "example.com") }
            await self.assertThrows("querySRV", iteration) {
                _ = try await resolver.querySRV(name: "_caldavs._tcp.example.com")
            }
            await self.assertThrows("queryTXT", iteration) { _ = try await resolver.queryTXT(name: "example.com") }
        }
    }

    private func assertThrows(
        _ label: String,
        _ iteration: Int,
        _ query: () async throws -> Void
    ) async {
        do {
            try await query()
            XCTFail("\(label) iteration \(iteration): should not succeed with no configured servers")
        } catch {
            // Any thrown error is acceptable here; this case exists to prove the call returns
            // control to the caller instead of faulting.
        }
    }
}
