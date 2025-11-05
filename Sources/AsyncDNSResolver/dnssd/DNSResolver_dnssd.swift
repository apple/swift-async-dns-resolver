//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAsyncDNSResolver open source project
//
// Copyright (c) 2023-2024 Apple Inc. and the SwiftAsyncDNSResolver project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAsyncDNSResolver project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
import dnssd

/// ``DNSResolver`` implementation backed by dnssd framework.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct DNSSDDNSResolver: DNSResolver, Sendable {
    let dnssd: DNSSD

    init() {
        self.dnssd = DNSSD()
    }

    /// See ``DNSResolver/queryA(name:)``.
    public func queryA(name: String) async throws -> [ARecord] {
        try await self.dnssd.query(type: .A, name: name, replyHandler: DNSSD.AQueryReplyHandler.instance)
    }

    /// See ``DNSResolver/queryAAAA(name:)``.
    public func queryAAAA(name: String) async throws -> [AAAARecord] {
        try await self.dnssd.query(type: .AAAA, name: name, replyHandler: DNSSD.AAAAQueryReplyHandler.instance)
    }

    /// See ``DNSResolver/queryNS(name:)``.
    public func queryNS(name: String) async throws -> NSRecord {
        try await self.dnssd.query(type: .NS, name: name, replyHandler: DNSSD.NSQueryReplyHandler.instance)
    }

    /// See ``DNSResolver/queryCNAME(name:)``.
    public func queryCNAME(name: String) async throws -> String? {
        try await self.dnssd.query(type: .CNAME, name: name, replyHandler: DNSSD.CNAMEQueryReplyHandler.instance)
    }

    /// See ``DNSResolver/querySOA(name:)``.
    public func querySOA(name: String) async throws -> SOARecord? {
        try await self.dnssd.query(type: .SOA, name: name, replyHandler: DNSSD.SOAQueryReplyHandler.instance)
    }

    /// See ``DNSResolver/queryPTR(name:)``.
    public func queryPTR(name: String) async throws -> PTRRecord {
        try await self.dnssd.query(type: .PTR, name: name, replyHandler: DNSSD.PTRQueryReplyHandler.instance)
    }

    /// See ``DNSResolver/queryMX(name:)``.
    public func queryMX(name: String) async throws -> [MXRecord] {
        try await self.dnssd.query(type: .MX, name: name, replyHandler: DNSSD.MXQueryReplyHandler.instance)
    }

    /// See ``DNSResolver/queryTXT(name:)``.
    public func queryTXT(name: String) async throws -> [TXTRecord] {
        try await self.dnssd.query(type: .TXT, name: name, replyHandler: DNSSD.TXTQueryReplyHandler.instance)
    }

    /// See ``DNSResolver/querySRV(name:)``.
    public func querySRV(name: String) async throws -> [SRVRecord] {
        try await self.dnssd.query(type: .SRV, name: name, replyHandler: DNSSD.SRVQueryReplyHandler.instance)
    }
}

extension QueryType {
    fileprivate var kDNSServiceType: Int {
        switch self {
        case .A:
            return kDNSServiceType_A
        case .NS:
            return kDNSServiceType_NS
        case .CNAME:
            return kDNSServiceType_CNAME
        case .SOA:
            return kDNSServiceType_SOA
        case .PTR:
            return kDNSServiceType_PTR
        case .MX:
            return kDNSServiceType_MX
        case .TXT:
            return kDNSServiceType_TXT
        case .AAAA:
            return kDNSServiceType_AAAA
        case .SRV:
            return kDNSServiceType_SRV
        case .NAPTR:
            return kDNSServiceType_NAPTR
        }
    }
}

// MARK: - dnssd query wrapper

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
struct DNSSD: Sendable {
    // Reference: https://gist.github.com/fikeminkel/a9c4bc4d0348527e8df3690e242038d3
    func query<ReplyHandler: DNSSDQueryReplyHandler>(
        type: QueryType,
        name: String,
        replyHandler: ReplyHandler
    ) async throws -> ReplyHandler.Reply {
        let recordStream = AsyncThrowingStream<ReplyHandler.Record, Error> { continuation in
            let handler = QueryReplyHandler(handler: replyHandler, continuation)

            // Wrap `handler` into a pointer so we can pass it to DNSServiceQueryRecord
            let handlerPointer = UnsafeMutableRawPointer.allocate(
                byteCount: MemoryLayout<QueryReplyHandler>.stride,
                alignment: MemoryLayout<QueryReplyHandler>.alignment
            )

            handlerPointer.initializeMemory(as: QueryReplyHandler.self, repeating: handler, count: 1)

            // The handler might be called multiple times so don't deallocate inside `callback`
            defer {
                let pointer = handlerPointer.assumingMemoryBound(to: QueryReplyHandler.self)
                pointer.deinitialize(count: 1)
                pointer.deallocate()
            }

            // This is called once per record received
            let callback: DNSServiceQueryRecordReply = { _, _, _, errorCode, _, _, _, rdlen, rdata, _, context in
                guard let handlerPointer = context else {
                    preconditionFailure("'context' is nil. This is a bug.")
                }

                let pointer = handlerPointer.assumingMemoryBound(to: QueryReplyHandler.self)
                let handler = pointer.pointee

                // This parses a record then adds it to the stream
                handler.handleRecord(errorCode: errorCode, data: rdata, length: rdlen)
            }

            let serviceRefPtr = UnsafeMutablePointer<DNSServiceRef?>.allocate(capacity: 1)
            defer { serviceRefPtr.deallocate() }

            // Run the query
            let _code = DNSServiceQueryRecord(
                serviceRefPtr,
                kDNSServiceFlagsTimeout,
                0,
                name,
                UInt16(type.kDNSServiceType),
                UInt16(kDNSServiceClass_IN),
                callback,
                handlerPointer
            )

            // Check if query completed successfully
            guard _code == kDNSServiceErr_NoError else {
                return continuation.finish(throwing: AsyncDNSResolver.Error(dnssdCode: _code))
            }

            // Read reply from the socket (blocking) then call reply handler
            DNSServiceProcessResult(serviceRefPtr.pointee)
            DNSServiceRefDeallocate(serviceRefPtr.pointee)

            // Streaming done
            continuation.finish()
        }

        // Build reply using records received
        let records = try await recordStream.reduce(into: []) { partial, record in
            partial.append(record)
        }

        return try replyHandler.generateReply(records: records)
    }
}

// MARK: - dnssd query reply handler

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DNSSD {
    class QueryReplyHandler {
        private let _handleRecord: (DNSServiceErrorType, UnsafeRawPointer?, UInt16) -> Void

        init<Handler: DNSSDQueryReplyHandler>(
            handler: Handler,
            _ continuation: AsyncThrowingStream<Handler.Record, Error>.Continuation
        ) {
            self._handleRecord = { errorCode, _data, _length in
                let data: UnsafeRawPointer?
                let length: UInt16

                switch Int(errorCode) {
                case kDNSServiceErr_NoError:
                    data = _data
                    length = _length
                case kDNSServiceErr_Timeout:
                    // DNSSD doesn't give up until it has answer or it times out. If it times out assume
                    // no answer is available, in which case `data` will be `nil` and parsers will deal
                    // with empty responses appropriately.
                    data = nil
                    length = 0
                default:
                    return continuation.finish(throwing: AsyncDNSResolver.Error(dnssdCode: errorCode))
                }

                do {
                    if let record = try handler.parseRecord(data: data, length: length) {
                        continuation.yield(record)
                    } else {
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        func handleRecord(errorCode: DNSServiceErrorType, data: UnsafeRawPointer?, length: UInt16) {
            self._handleRecord(errorCode, data, length)
        }
    }
}

// MARK: - dnssd query reply handlers

protocol DNSSDQueryReplyHandler {
    associatedtype Record: Sendable
    associatedtype Reply

    func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> Record?

    func generateReply(records: [Record]) throws -> Reply
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension DNSSD {
    // Reference: https://github.com/orlandos-nl/DNSClient/blob/master/Sources/DNSClient/Messages/Message.swift  // // ignore-unacceptable-language

    struct AQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = AQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> ARecord? {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            guard length >= MemoryLayout<in_addr>.size else {
                throw AsyncDNSResolver.Error(code: .badResponse)
            }

            let parsedAddress = sys_inet_ntop(family: AF_INET, bytes: ptr, length: Int(INET_ADDRSTRLEN)) ?? ""
            return ARecord(address: .init(address: parsedAddress), ttl: nil)
        }

        func generateReply(records: [ARecord]) throws -> [ARecord] {
            records
        }
    }

    struct AAAAQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = AAAAQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> AAAARecord? {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            guard length >= MemoryLayout<in6_addr>.size else {
                throw AsyncDNSResolver.Error(code: .badResponse)
            }

            let parsedAddress = sys_inet_ntop(family: AF_INET6, bytes: ptr, length: Int(INET6_ADDRSTRLEN)) ?? ""
            return AAAARecord(address: .init(address: parsedAddress), ttl: nil)
        }

        func generateReply(records: [AAAARecord]) throws -> [AAAARecord] {
            records
        }
    }

    struct NSQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = NSQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> String? {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = Array(bufferPtr)[...]

            guard let nameserver = self.readName(&buffer) else {
                throw AsyncDNSResolver.Error(code: .badResponse, message: "failed to read name")
            }

            return nameserver
        }

        func generateReply(records: [String]) throws -> NSRecord {
            NSRecord(nameservers: records)
        }
    }

    struct CNAMEQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = CNAMEQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> String? {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = Array(bufferPtr)[...]

            guard let cname = self.readName(&buffer) else {
                throw AsyncDNSResolver.Error(code: .badResponse, message: "failed to read name")
            }

            return cname
        }

        func generateReply(records: [String]) throws -> String? {
            try self.ensureAtMostOne(records: records)
        }
    }

    struct SOAQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = SOAQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> SOARecord? {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = Array(bufferPtr)[...]

            guard let mname = self.readName(&buffer),
                let rname = self.readName(&buffer),
                let serial = buffer.readInteger(as: UInt32.self),
                let refresh = buffer.readInteger(as: UInt32.self),
                let retry = buffer.readInteger(as: UInt32.self),
                let expire = buffer.readInteger(as: UInt32.self),
                let ttl = buffer.readInteger(as: UInt32.self)
            else {
                throw AsyncDNSResolver.Error(code: .badResponse)
            }

            return SOARecord(
                mname: mname,
                rname: rname,
                serial: serial,
                refresh: refresh,
                retry: retry,
                expire: expire,
                ttl: ttl
            )
        }

        func generateReply(records: [SOARecord]) throws -> SOARecord? {
            try self.ensureAtMostOne(records: records)
        }
    }

    struct PTRQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = PTRQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> String? {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = Array(bufferPtr)[...]

            guard let name = self.readName(&buffer) else {
                throw AsyncDNSResolver.Error(code: .badResponse, message: "failed to read name")
            }

            return name
        }

        func generateReply(records: [String]) throws -> PTRRecord {
            PTRRecord(names: records)
        }
    }

    struct MXQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = MXQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> MXRecord? {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = Array(bufferPtr)[...]

            guard let priority = buffer.readInteger(as: UInt16.self),
                let host = self.readName(&buffer)
            else {
                throw AsyncDNSResolver.Error(code: .badResponse)
            }

            return MXRecord(
                host: host,
                priority: priority
            )
        }

        func generateReply(records: [MXRecord]) throws -> [MXRecord] {
            records
        }
    }

    struct TXTQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = TXTQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> TXTRecord? {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = Array(bufferPtr)[...]

            guard let txt = self.readName(&buffer, separator: "") else {
                throw AsyncDNSResolver.Error(code: .badResponse)
            }

            return TXTRecord(txt: txt)
        }

        func generateReply(records: [TXTRecord]) throws -> [TXTRecord] {
            records
        }
    }

    struct SRVQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = SRVQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> SRVRecord? {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = Array(bufferPtr)[...]

            guard let priority = buffer.readInteger(as: UInt16.self),
                let weight = buffer.readInteger(as: UInt16.self),
                let port = buffer.readInteger(as: UInt16.self),
                let host = self.readName(&buffer)
            else {
                throw AsyncDNSResolver.Error(code: .badResponse)
            }

            return SRVRecord(
                host: host,
                port: port,
                weight: weight,
                priority: priority
            )
        }

        func generateReply(records: [SRVRecord]) throws -> [SRVRecord] {
            records
        }
    }
}

extension DNSSDQueryReplyHandler {
    func readName(_ buffer: inout ArraySlice<UInt8>, separator: String = ".") -> String? {
        var parts: [String] = []
        while let length = buffer.readInteger(as: UInt8.self),
            length > 0,
            let part = buffer.readString(length: Int(length))
        {
            parts.append(part)
        }

        return parts.isEmpty ? nil : parts.joined(separator: separator)
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
    func ensureAtMostOne<R>(records: [R]) throws -> R? {
        guard records.count <= 1 else {
            throw AsyncDNSResolver.Error(code: .badResponse, message: "expected 1 record but got \(records.count)")
        }

        return records.first
    }
}

extension ArraySlice<UInt8> {
    mutating func readInteger<T: FixedWidthInteger>(as: T.Type = T.self) -> T? {
        let size = MemoryLayout<T>.size
        guard self.count >= size else { return nil }

        let value = self.withUnsafeBytes { pointer in
            var value = T.zero
            Swift.withUnsafeMutableBytes(of: &value) { valuePointer in
                valuePointer.copyMemory(from: UnsafeRawBufferPointer(rebasing: pointer[..<size]))
            }
            return value.bigEndian
        }

        self = self.dropFirst(size)
        return value
    }

    mutating func readString(length: Int) -> String? {
        guard self.count >= length else { return nil }

        let prefix = self.prefix(length)
        self = self.dropFirst(length)
        return String(decoding: prefix, as: UTF8.self)
    }
}
#endif
