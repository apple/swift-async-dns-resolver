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

@testable import AsyncDNSResolver
import CAsyncDNSResolver
import XCTest

final class AsyncDNSResolverTests: XCTestCase {
    var resolver: AsyncDNSResolver!
    var verbose: Bool = false

    override func setUp() {
        super.setUp()

        let servers = ProcessInfo.processInfo.environment["NAME_SERVERS"]?.split(separator: ",").map { String($0) }

        var options = AsyncDNSResolver.Options()
        options.servers = servers

        self.resolver = try! AsyncDNSResolver(options: options)
        self.verbose = ProcessInfo.processInfo.environment["VERBOSE_TESTS"] == "true"
    }

    override func tearDown() {
        super.tearDown()
        self.resolver = nil // FIXME: for tsan
    }

    func test_queryA() async throws {
        let reply = try await self.resolver.queryA(name: "apple.com")
        if self.verbose {
            print("test_queryA: \(reply)")
        }
        XCTAssertFalse(reply.addresses.isEmpty, "should have IP address(es)")
    }

    func test_queryAAAA() async throws {
        let reply = try await self.resolver.queryAAAA(name: "apple.com")
        if self.verbose {
            print("test_queryAAAA: \(reply)")
        }
        XCTAssertFalse(reply.addresses.isEmpty, "should have IP address(es)")
    }

    func test_queryNS() async throws {
        let reply = try await self.resolver.queryNS(name: "apple.com")
        if self.verbose {
            print("test_queryNS: \(reply)")
        }
        XCTAssertFalse(reply.nameservers.isEmpty, "should have nameserver(s)")
    }

    func test_queryCNAME() async throws {
        let reply = try await self.resolver.queryCNAME(name: "www.apple.com")
        if self.verbose {
            print("test_queryCNAME: \(reply)")
        }
        XCTAssertFalse(reply.isEmpty, "should have CNAME")
    }

    func test_querySOA() async throws {
        let reply = try await self.resolver.querySOA(name: "apple.com")
        if self.verbose {
            print("test_querySOA: \(reply)")
        }
        XCTAssertFalse(reply.mname?.isEmpty ?? true, "should have nameserver")
    }

    func test_queryPTR() async throws {
        let reply = try await self.resolver.queryPTR(name: "47.224.172.17.in-addr.arpa")
        if self.verbose {
            print("test_queryPTR: \(reply)")
        }
        XCTAssertFalse(reply.names.isEmpty, "should have names")
    }

    func test_queryMX() async throws {
        let reply = try await self.resolver.queryMX(name: "apple.com")
        if self.verbose {
            print("test_queryMX: \(reply)")
        }
        XCTAssertFalse(reply.isEmpty, "should have MX record(s)")
    }

    func test_queryTXT() async throws {
        let reply = try await self.resolver.queryTXT(name: "apple.com")
        if self.verbose {
            print("test_queryTXT: \(reply)")
        }
        XCTAssertFalse(reply.isEmpty, "should have TXT record(s)")
    }

    func test_querySRV() async throws {
        let reply = try await self.resolver.querySRV(name: "_caldavs._tcp.google.com")
        if self.verbose {
            print("test_querySRV: \(reply)")
        }
        XCTAssertFalse(reply.isEmpty, "should have SRV record(s)")
    }

    func test_queryNAPTR() async throws {
        do {
            // expected: "no data" error
            let reply = try await self.resolver.queryNAPTR(name: "apple.com")
            if self.verbose {
                print("test_queryNAPTR: \(reply)")
            }
        } catch {
            print("test_queryNAPTR error: \(error)")
        }
    }

    func test_concurrency() async throws {
        func run(
            times: Int = 100,
            _ query: @escaping (_ index: Int) async throws -> Void
        ) async throws {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 1 ... times {
                    group.addTask {
                        try await query(i)
                    }
                }
                for try await _ in group {}
            }
        }

        try await run { i in
            let reply = try await self.resolver.queryA(name: "apple.com")
            if self.verbose {
                print("[A] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await self.resolver.queryAAAA(name: "apple.com")
            if self.verbose {
                print("[AAAA] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await self.resolver.queryNS(name: "apple.com")
            if self.verbose {
                print("[NS] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await self.resolver.queryCNAME(name: "www.apple.com")
            if self.verbose {
                print("[CNAME] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await self.resolver.querySOA(name: "apple.com")
            if self.verbose {
                print("[SOA] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await self.resolver.queryPTR(name: "47.224.172.17.in-addr.arpa")
            if self.verbose {
                print("[PTR] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await self.resolver.queryMX(name: "apple.com")
            if self.verbose {
                print("[MX] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await self.resolver.queryTXT(name: "apple.com")
            if self.verbose {
                print("[TXT] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await self.resolver.querySRV(name: "_caldavs._tcp.google.com")
            if self.verbose {
                print("[SRV] run #\(i) result: \(reply)")
            }
        }

        /* expected: "no data" error
         try await run { i in
             let reply = try await self.resolver.queryNAPTR(name: "apple.com")
             if self.verbose {
                 print("[NAPTR] run #\(i) result: \(reply)")
             }
         }
          */
    }
}
