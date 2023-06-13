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

// MARK: - Async DNS resolver API

public struct AsyncDNSResolver {
    let underlying: DNSResolver

    public init() throws {
        #if canImport(Darwin)
        self.init(DNSSDDNSResolver())
        #else
        self.init(try CAresDNSResolver())
        #endif
    }

    public init(options: CAresDNSResolver.Options) throws {
        self.init(try CAresDNSResolver(options: options))
    }

    public init(_ dnsResolver: DNSResolver) {
        self.underlying = dnsResolver
    }

    public func queryA(name: String) async throws -> [ARecord] {
        try await self.underlying.queryA(name: name)
    }

    public func queryAAAA(name: String) async throws -> [AAAARecord] {
        try await self.underlying.queryAAAA(name: name)
    }

    public func queryNS(name: String) async throws -> NSRecord {
        try await self.underlying.queryNS(name: name)
    }

    public func queryCNAME(name: String) async throws -> String {
        try await self.underlying.queryCNAME(name: name)
    }

    public func querySOA(name: String) async throws -> SOARecord {
        try await self.underlying.querySOA(name: name)
    }

    public func queryPTR(name: String) async throws -> PTRRecord {
        try await self.underlying.queryPTR(name: name)
    }

    public func queryMX(name: String) async throws -> [MXRecord] {
        try await self.underlying.queryMX(name: name)
    }

    public func queryTXT(name: String) async throws -> [TXTRecord] {
        try await self.underlying.queryTXT(name: name)
    }

    public func querySRV(name: String) async throws -> [SRVRecord] {
        try await self.underlying.querySRV(name: name)
    }
}

public protocol DNSResolver {
    /// Lookup A record associated with `name`.
    func queryA(name: String) async throws -> [ARecord]

    /// Lookup AAAA records associated with `name`.
    func queryAAAA(name: String) async throws -> [AAAARecord]

    /// Lookup NS records associated with `name`.
    func queryNS(name: String) async throws -> NSRecord

    /// Lookup CNAME record associated with `name`.
    func queryCNAME(name: String) async throws -> String

    /// Lookup SOA record associated with `name`.
    func querySOA(name: String) async throws -> SOARecord

    /// Lookup PTR record associated with `name`.
    func queryPTR(name: String) async throws -> PTRRecord

    /// Lookup MX records associated with `name`.
    func queryMX(name: String) async throws -> [MXRecord]

    /// Lookup TXT records associated with `name`.
    func queryTXT(name: String) async throws -> [TXTRecord]

    /// Lookup SRV records associated with `name`.
    func querySRV(name: String) async throws -> [SRVRecord]
}

enum QueryType {
    case A
    case NS
    case CNAME
    case SOA
    case PTR
    case MX
    case TXT
    case AAAA
    case SRV
    case NAPTR
}

// MARK: - Query reply types

public enum IPAddress: CustomStringConvertible {
    case IPv4(String)
    case IPv6(String)

    public var description: String {
        switch self {
        case .IPv4(let address):
            return address
        case .IPv6(let address):
            return address
        }
    }
}

public struct ARecord: CustomStringConvertible {
    public let address: IPAddress
    public let ttl: Int32?

    public var description: String {
        "\(Self.self)(address=\(self.address), ttl=\(self.ttl.map { "\($0)" } ?? ""))"
    }
}

public struct AAAARecord: CustomStringConvertible {
    public let address: IPAddress
    public let ttl: Int32?

    public var description: String {
        "\(Self.self)(address=\(self.address), ttl=\(self.ttl.map { "\($0)" } ?? ""))"
    }
}

public struct NSRecord: CustomStringConvertible {
    public let nameservers: [String]

    public var description: String {
        "\(Self.self)(nameservers=\(self.nameservers))"
    }
}

public struct SOARecord: CustomStringConvertible {
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

public struct PTRRecord: CustomStringConvertible {
    public let names: [String]

    public var description: String {
        "\(Self.self)(names=\(self.names))"
    }
}

public struct MXRecord: CustomStringConvertible {
    public let host: String
    public let priority: UInt16

    public var description: String {
        "\(Self.self)(host=\(self.host), priority=\(self.priority))"
    }
}

public struct TXTRecord {
    public let txt: String

    public var description: String {
        "\(Self.self)(\(self.txt))"
    }
}

public struct SRVRecord: CustomStringConvertible {
    public let host: String
    public let port: UInt16
    public let weight: UInt16
    public let priority: UInt16

    public var description: String {
        "\(Self.self)(host=\(self.host), port=\(self.port), weight=\(self.weight), priority=\(self.priority))"
    }
}

public struct NAPTRRecord: CustomStringConvertible {
    public let flags: String?
    public let service: String?
    public let regExp: String?
    public let replacement: String
    public let order: UInt16
    public let preference: UInt16

    public var description: String {
        "\(Self.self)(flags=\(self.flags ?? ""), service=\(self.service ?? ""), regExp=\(self.regExp ?? ""), replacement=\(self.replacement), order=\(self.order), preference=\(self.preference))"
    }
}
