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

// MARK: - Async DNS resolver API

/// `AsyncDNSResolver` provides API for running asynchronous DNS queries.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct AsyncDNSResolver {
    let underlying: DNSResolver

    /// Initialize an `AsyncDNSResolver`.
    ///
    /// By default, this makes use of the `dnssd` framework on Darwin platforms,
    /// and the `c-ares` C library on others.
    public init() throws {
        #if canImport(Darwin)
        self.init(DNSSDDNSResolver())
        #else
        try self.init(CAresDNSResolver())
        #endif
    }

    /// Initialize an `AsyncDNSResolver` using the given ``DNSResolver``.
    ///
    /// - Parameters:
    ///   - dnsResolver: The ``DNSResolver`` to use.
    public init(_ dnsResolver: DNSResolver) {
        self.underlying = dnsResolver
    }

    /// Initialize an `AsyncDNSResolver` backed by ``CAresDNSResolver``
    /// created using the given options.
    ///
    /// - Parameters:
    ///   - options: Options to create ``CAresDNSResolver`` with.
    public init(options: CAresDNSResolver.Options) throws {
        try self.init(CAresDNSResolver(options: options))
    }

    /// See ``DNSResolver/queryA(name:)``.
    public func queryA(name: String) async throws -> [ARecord] {
        try await self.underlying.queryA(name: name)
    }

    /// See ``DNSResolver/queryAAAA(name:)``.
    public func queryAAAA(name: String) async throws -> [AAAARecord] {
        try await self.underlying.queryAAAA(name: name)
    }

    /// See ``DNSResolver/queryNS(name:)``.
    public func queryNS(name: String) async throws -> NSRecord {
        try await self.underlying.queryNS(name: name)
    }

    /// See ``DNSResolver/queryCNAME(name:)``.
    public func queryCNAME(name: String) async throws -> String? {
        try await self.underlying.queryCNAME(name: name)
    }

    /// See ``DNSResolver/querySOA(name:)``.
    public func querySOA(name: String) async throws -> SOARecord? {
        try await self.underlying.querySOA(name: name)
    }

    /// See ``DNSResolver/queryPTR(name:)``.
    public func queryPTR(name: String) async throws -> PTRRecord {
        try await self.underlying.queryPTR(name: name)
    }

    /// See ``DNSResolver/queryMX(name:)``.
    public func queryMX(name: String) async throws -> [MXRecord] {
        try await self.underlying.queryMX(name: name)
    }

    /// See ``DNSResolver/queryTXT(name:)``.
    public func queryTXT(name: String) async throws -> [TXTRecord] {
        try await self.underlying.queryTXT(name: name)
    }

    /// See ``DNSResolver/querySRV(name:)``.
    public func querySRV(name: String) async throws -> [SRVRecord] {
        try await self.underlying.querySRV(name: name)
    }
}

/// API for running DNS queries.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public protocol DNSResolver {
    /// Lookup A records associated with `name`.
    ///
    /// - Parameters:
    ///   - name: The name to resolve.
    ///
    /// - Returns: ``ARecord``s for the given name, empty if no records were found.
    func queryA(name: String) async throws -> [ARecord]

    /// Lookup AAAA records associated with `name`.
    ///
    /// - Parameters:
    ///   - name: The name to resolve.
    ///
    /// - Returns: ``AAAARecord``s for the given name, empty if no records were found.
    func queryAAAA(name: String) async throws -> [AAAARecord]

    /// Lookup NS record associated with `name`.
    ///
    /// - Parameters:
    ///   - name: The name to resolve.
    ///
    /// - Returns: ``NSRecord`` for the given name.
    func queryNS(name: String) async throws -> NSRecord

    /// Lookup CNAME record associated with `name`.
    ///
    /// - Parameters:
    ///   - name: The name to resolve.
    ///
    /// - Returns: CNAME for the given name, `nil` if no record was found.
    func queryCNAME(name: String) async throws -> String?

    /// Lookup SOA record associated with `name`.
    ///
    /// - Parameters:
    ///   - name: The name to resolve.
    ///
    /// - Returns: ``SOARecord`` for the given name, `nil` if no record was found.
    func querySOA(name: String) async throws -> SOARecord?

    /// Lookup PTR record associated with `name`.
    ///
    /// - Parameters:
    ///   - name: The name to resolve.
    ///
    /// - Returns: ``PTRRecord`` for the given name.
    func queryPTR(name: String) async throws -> PTRRecord

    /// Lookup MX records associated with `name`.
    ///
    /// - Parameters:
    ///   - name: The name to resolve.
    ///
    /// - Returns: ``MXRecord``s for the given name, empty if no records were found.
    func queryMX(name: String) async throws -> [MXRecord]

    /// Lookup TXT records associated with `name`.
    ///
    /// - Parameters:
    ///   - name: The name to resolve.
    ///
    /// - Returns: ``TXTRecord``s for the given name, empty if no records were found.
    func queryTXT(name: String) async throws -> [TXTRecord]

    /// Lookup SRV records associated with `name`.
    ///
    /// - Parameters:
    ///   - name: The name to resolve.
    ///
    /// - Returns: ``SRVRecord``s for the given name, empty if no records were found.
    func querySRV(name: String) async throws -> [SRVRecord]
}

enum QueryType: Int {
    case A = 1
    case NS = 2
    case CNAME = 5
    case SOA = 6
    case PTR = 12
    case MX = 15
    case TXT = 16
    case AAAA = 28
    case SRV = 33
    case NAPTR = 35
}

// MARK: - Query reply types

public enum IPAddress: Sendable, Hashable, CustomStringConvertible {
    case ipv4(IPv4)
    case ipv6(IPv6)

    public var description: String {
        switch self {
        case .ipv4(let address):
            return String(describing: address)
        case .ipv6(let address):
            return String(describing: address)
        }
    }

    public struct IPv4: Sendable, Hashable, CustomStringConvertible {
        public var address: String
        public var description: String { self.address }

        public init(address: String) {
            self.address = address
        }
    }

    public struct IPv6: Sendable, Hashable, CustomStringConvertible {
        public var address: String
        public var description: String { self.address }

        public init(address: String) {
            self.address = address
        }
    }
}

public struct ARecord: Sendable, Hashable, CustomStringConvertible {
    public let address: IPAddress.IPv4
    public let ttl: Int32?

    public var description: String {
        "\(Self.self)(address=\(self.address), ttl=\(self.ttl.map { "\($0)" } ?? ""))"
    }

    public init(address: IPAddress.IPv4, ttl: Int32?) {
        self.address = address
        self.ttl = ttl
    }
}

public struct AAAARecord: Sendable, Hashable, CustomStringConvertible {
    public let address: IPAddress.IPv6
    public let ttl: Int32?

    public var description: String {
        "\(Self.self)(address=\(self.address), ttl=\(self.ttl.map { "\($0)" } ?? ""))"
    }

    public init(address: IPAddress.IPv6, ttl: Int32?) {
        self.address = address
        self.ttl = ttl
    }
}

public struct NSRecord: Sendable, Hashable, CustomStringConvertible {
    public let nameservers: [String]

    public var description: String {
        "\(Self.self)(nameservers=\(self.nameservers))"
    }

    public init(nameservers: [String]) {
        self.nameservers = nameservers
    }
}

public struct SOARecord: Sendable, Hashable, CustomStringConvertible {
    public let mname: String?
    public let rname: String?
    public let serial: UInt32
    public let refresh: UInt32
    public let retry: UInt32
    public let expire: UInt32
    public let ttl: UInt32

    public var description: String {
        "\(Self.self)(mname=\(self.mname ?? ""), rname=\(self.rname ?? ""), serial=\(self.serial), refresh=\(self.refresh), retry=\(self.retry), expire=\(self.expire), ttl=\(self.ttl))"
    }
}

public struct PTRRecord: Sendable, Hashable, CustomStringConvertible {
    public let names: [String]

    public var description: String {
        "\(Self.self)(names=\(self.names))"
    }

    public init(names: [String]) {
        self.names = names
    }
}

public struct MXRecord: Sendable, Hashable, CustomStringConvertible {
    public let host: String
    public let priority: UInt16

    public var description: String {
        "\(Self.self)(host=\(self.host), priority=\(self.priority))"
    }

    public init(host: String, priority: UInt16) {
        self.host = host
        self.priority = priority
    }
}

public struct TXTRecord: Sendable, Hashable {
    public let txt: String

    public var description: String {
        "\(Self.self)(\(self.txt))"
    }

    public init(txt: String) {
        self.txt = txt
    }
}

public struct SRVRecord: Sendable, Hashable, CustomStringConvertible {
    public let host: String
    public let port: UInt16
    public let weight: UInt16
    public let priority: UInt16

    public var description: String {
        "\(Self.self)(host=\(self.host), port=\(self.port), weight=\(self.weight), priority=\(self.priority))"
    }

    public init(host: String, port: UInt16, weight: UInt16, priority: UInt16) {
        self.host = host
        self.port = port
        self.weight = weight
        self.priority = priority
    }
}

public struct NAPTRRecord: Sendable, Hashable, CustomStringConvertible {
    public let flags: String?
    public let service: String?
    public let regExp: String?
    public let replacement: String
    public let order: UInt16
    public let preference: UInt16

    public var description: String {
        "\(Self.self)(flags=\(self.flags ?? ""), service=\(self.service ?? ""), regExp=\(self.regExp ?? ""), replacement=\(self.replacement), order=\(self.order), preference=\(self.preference))"
    }

    public init(
        flags: String?,
        service: String?,
        regExp: String?,
        replacement: String,
        order: UInt16,
        preference: UInt16
    ) {
        self.flags = flags
        self.service = service
        self.regExp = regExp
        self.replacement = replacement
        self.order = order
        self.preference = preference
    }
}
