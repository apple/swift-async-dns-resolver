//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAsyncDNSResolver open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftAsyncDNSResolver project authors
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

#if canImport(Darwin)
final class DNSSDDNSResolverTests: XCTestCase {
    var resolver: DNSSDDNSResolver!
    var verbose: Bool = false

    override func setUp() {
        super.setUp()

        self.resolver = DNSSDDNSResolver()
        self.verbose = ProcessInfo.processInfo.environment["VERBOSE_TESTS"] == "true"
    }

    override func tearDown() {
        super.tearDown()
        self.resolver = nil  // FIXME: for tsan
    }

    func test_queryA() async throws {
        let reply = try await self.resolver.queryA(name: "apple.com")
        if self.verbose {
            print("test_queryA: \(reply)")
        }
        XCTAssertFalse(reply.isEmpty, "should have A record(s)")
    }

    func test_queryAAAA() async throws {
        let reply = try await self.resolver.queryAAAA(name: "apple.com")
        if self.verbose {
            print("test_queryAAAA: \(reply)")
        }
        XCTAssertFalse(reply.isEmpty, "should have AAAA record(s)")
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
            print("test_queryCNAME: \(String(describing: reply))")
        }
        XCTAssertFalse(reply?.isEmpty ?? true, "should have CNAME")
    }

    func test_querySOA() async throws {
        let reply = try await self.resolver.querySOA(name: "apple.com")
        if self.verbose {
            print("test_querySOA: \(String(describing: reply))")
        }
        XCTAssertFalse(reply?.mname?.isEmpty ?? true, "should have nameserver")
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

    func test_parseA() throws {
        let addrBytes: [UInt8] = [38, 32, 1, 73]
        try addrBytes.withUnsafeBufferPointer {
            let record = try DNSSD.AQueryReplyHandler.instance.parseRecord(
                data: $0.baseAddress,
                length: UInt16($0.count)
            )
            XCTAssertEqual(record, ARecord(address: .init(address: "38.32.1.73"), ttl: nil))
        }
    }

    func test_parseATooShort() throws {
        let addrBytes: [UInt8] = [38, 32, 1]
        try addrBytes.withUnsafeBufferPointer {
            XCTAssertThrowsError(
                try DNSSD.AQueryReplyHandler.instance.parseRecord(
                    data: $0.baseAddress,
                    length: UInt16($0.count)
                )
            )
        }
    }

    func test_parseAAAATooShort() throws {
        let addrBytes: [UInt8] = [38, 32, 1, 73, 17, 11, 71, 14, 0, 0, 0, 0, 0, 0, 14]
        try addrBytes.withUnsafeBufferPointer {
            XCTAssertThrowsError(
                try DNSSD.AAAAQueryReplyHandler.instance.parseRecord(
                    data: $0.baseAddress,
                    length: UInt16($0.count)
                )
            )
        }
    }

    func test_concurrency() async throws {
        func run(
            times: Int = 100,
            _ query: @Sendable @escaping (_ index: Int) async throws -> Void
        ) async throws {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 1...times {
                    group.addTask {
                        try await query(i)
                    }
                }
                for try await _ in group {}
            }
        }

        let resolver = self.resolver!
        let verbose = self.verbose
        try await run { i in
            let reply = try await resolver.queryA(name: "apple.com")
            if verbose {
                print("[A] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await resolver.queryAAAA(name: "apple.com")
            if verbose {
                print("[AAAA] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await resolver.queryNS(name: "apple.com")
            if verbose {
                print("[NS] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await resolver.queryCNAME(name: "www.apple.com")
            if verbose {
                print("[CNAME] run #\(i) result: \(String(describing: reply))")
            }
        }

        try await run { i in
            let reply = try await resolver.querySOA(name: "apple.com")
            if verbose {
                print("[SOA] run #\(i) result: \(String(describing: reply))")
            }
        }

        try await run { i in
            let reply = try await resolver.queryPTR(name: "47.224.172.17.in-addr.arpa")
            if verbose {
                print("[PTR] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await resolver.queryMX(name: "apple.com")
            if verbose {
                print("[MX] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await resolver.queryTXT(name: "apple.com")
            if verbose {
                print("[TXT] run #\(i) result: \(reply)")
            }
        }

        try await run { i in
            let reply = try await resolver.querySRV(name: "_caldavs._tcp.google.com")
            if verbose {
                print("[SRV] run #\(i) result: \(reply)")
            }
        }
    }
}
#endif
