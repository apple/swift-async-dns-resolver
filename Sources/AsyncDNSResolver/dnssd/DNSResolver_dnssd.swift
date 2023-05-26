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

#if canImport(Darwin)
import dnssd
import NIOCore

struct DNSSDDNSResolver: DNSResolver {
    let dnssd: DNSSD

    init() {
        self.dnssd = DNSSD()
    }

    func queryA(name: String) async throws -> [ARecord] {
        try await self.dnssd.query(type: .A, name: name, replyHandler: DNSSD.AQueryReplyHandler.instance)
    }

    func queryAAAA(name: String) async throws -> [AAAARecord] {
        try await self.dnssd.query(type: .AAAA, name: name, replyHandler: DNSSD.AAAAQueryReplyHandler.instance)
    }

    func queryNS(name: String) async throws -> NSRecord {
        try await self.dnssd.query(type: .NS, name: name, replyHandler: DNSSD.NSQueryReplyHandler.instance)
    }

    func queryCNAME(name: String) async throws -> String {
        try await self.dnssd.query(type: .CNAME, name: name, replyHandler: DNSSD.CNAMEQueryReplyHandler.instance)
    }

    func querySOA(name: String) async throws -> SOARecord {
        try await self.dnssd.query(type: .SOA, name: name, replyHandler: DNSSD.SOAQueryReplyHandler.instance)
    }

    func queryPTR(name: String) async throws -> PTRRecord {
        try await self.dnssd.query(type: .PTR, name: name, replyHandler: DNSSD.PTRQueryReplyHandler.instance)
    }

    func queryMX(name: String) async throws -> [MXRecord] {
        try await self.dnssd.query(type: .MX, name: name, replyHandler: DNSSD.MXQueryReplyHandler.instance)
    }

    func queryTXT(name: String) async throws -> [TXTRecord] {
        try await self.dnssd.query(type: .TXT, name: name, replyHandler: DNSSD.TXTQueryReplyHandler.instance)
    }

    func querySRV(name: String) async throws -> [SRVRecord] {
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

struct DNSSD {
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
            // The handler might be called multiple times so don't deallocate inside `callback`
            defer { handlerPointer.deallocate() }

            handlerPointer.initializeMemory(as: QueryReplyHandler.self, repeating: handler, count: 1)

            // This is called once per record received
            let callback: DNSServiceQueryRecordReply = { _, _, _, errorCode, _, _, _, rdlen, rdata, _, context in
                guard let handlerPointer = context else {
                    preconditionFailure("'context' is nil. This is a bug.")
                }

                let handler = QueryReplyHandler(pointer: handlerPointer)
                // This parses a record then adds it to the stream
                handler.handleRecord(errorCode: errorCode, data: rdata, length: rdlen)
            }

            let serviceRefPtr = UnsafeMutablePointer<DNSServiceRef?>.allocate(capacity: 1)
            defer { serviceRefPtr.deallocate() }

            // Run the query
            let code = DNSServiceQueryRecord(
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
            guard code == kDNSServiceErr_NoError else {
                return continuation.finish(throwing: AsyncDNSResolver.Error.other(code: Int(code)))
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

extension DNSSD {
    struct QueryReplyHandler {
        private let _handleRecord: (DNSServiceErrorType, UnsafeRawPointer?, UInt16) -> Void

        init<Handler: DNSSDQueryReplyHandler>(handler: Handler, _ continuation: AsyncThrowingStream<Handler.Record, Error>.Continuation) {
            self._handleRecord = { errorCode, data, length in
                guard errorCode == kDNSServiceErr_NoError else {
                    return continuation.finish(throwing: AsyncDNSResolver.Error.other(code: Int(errorCode)))
                }

                do {
                    let record = try handler.parseRecord(data: data, length: length)
                    continuation.yield(record)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        init(pointer: UnsafeMutableRawPointer) {
            let handlerPointer = pointer.assumingMemoryBound(to: Self.self)
            self = handlerPointer.pointee
        }

        func handleRecord(errorCode: DNSServiceErrorType, data: UnsafeRawPointer?, length: UInt16) {
            self._handleRecord(errorCode, data, length)
        }
    }
}

// MARK: - dnssd query reply handlers

protocol DNSSDQueryReplyHandler {
    associatedtype Record
    associatedtype Reply

    func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> Record

    func generateReply(records: [Record]) throws -> Reply
}

extension DNSSD {
    // Reference: https://github.com/orlandos-nl/DNSClient/blob/master/Sources/DNSClient/Messages/Message.swift

    struct AQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = AQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> ARecord {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                throw AsyncDNSResolver.Error.noData()
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = ByteBuffer(bytes: bufferPtr)

            guard let addressBytes = buffer.readInteger(as: UInt32.self) else {
                throw AsyncDNSResolver.Error.badResponse("failed to read address")
            }

            let address = withUnsafeBytes(of: addressBytes) { buffer in
                let buffer = buffer.bindMemory(to: UInt8.self)
                return "\(buffer[3]).\(buffer[2]).\(buffer[1]).\(buffer[0])"
            }

            return ARecord(address: .IPv4(address), ttl: nil)
        }

        func generateReply(records: [ARecord]) throws -> [ARecord] {
            records
        }
    }

    struct AAAAQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = AAAAQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> AAAARecord {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                throw AsyncDNSResolver.Error.noData()
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = ByteBuffer(bytes: bufferPtr)

            guard let addressBytes = buffer.readBytes(length: 16) else {
                throw AsyncDNSResolver.Error.badResponse("failed to read address")
            }

            let address = stride(from: 0, to: addressBytes.endIndex, by: 2).map {
                "\(String(addressBytes[$0], radix: 16))\(String(addressBytes[$0.advanced(by: 1)], radix: 16))"
            }.joined(separator: ":")

            return AAAARecord(address: .IPv6(address), ttl: nil)
        }

        func generateReply(records: [AAAARecord]) throws -> [AAAARecord] {
            records
        }
    }

    struct NSQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = NSQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> String {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                throw AsyncDNSResolver.Error.noData()
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = ByteBuffer(bytes: bufferPtr)

            guard let nameserver = self.readName(&buffer) else {
                throw AsyncDNSResolver.Error.badResponse("failed to read name")
            }

            return nameserver
        }

        func generateReply(records: [String]) throws -> NSRecord {
            NSRecord(nameservers: records)
        }
    }

    struct CNAMEQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = CNAMEQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> String {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                throw AsyncDNSResolver.Error.noData()
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = ByteBuffer(bytes: bufferPtr)

            guard let cname = self.readName(&buffer) else {
                throw AsyncDNSResolver.Error.badResponse("failed to read name")
            }

            return cname
        }

        func generateReply(records: [String]) throws -> String {
            try self.ensureOne(records: records)
        }
    }

    struct SOAQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = SOAQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> SOARecord {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                throw AsyncDNSResolver.Error.noData()
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = ByteBuffer(bytes: bufferPtr)

            guard let mname = self.readName(&buffer),
                  let rname = self.readName(&buffer),
                  let serial = buffer.readInteger(as: UInt32.self),
                  let refresh = buffer.readInteger(as: UInt32.self),
                  let retry = buffer.readInteger(as: UInt32.self),
                  let expire = buffer.readInteger(as: UInt32.self),
                  let ttl = buffer.readInteger(as: UInt32.self) else {
                throw AsyncDNSResolver.Error.badResponse()
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

        func generateReply(records: [SOARecord]) throws -> SOARecord {
            try self.ensureOne(records: records)
        }
    }

    struct PTRQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = PTRQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> String {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                throw AsyncDNSResolver.Error.noData()
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = ByteBuffer(bytes: bufferPtr)

            guard let name = self.readName(&buffer) else {
                throw AsyncDNSResolver.Error.badResponse("failed to read name")
            }

            return name
        }

        func generateReply(records: [String]) throws -> PTRRecord {
            PTRRecord(names: records)
        }
    }

    struct MXQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = MXQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> MXRecord {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                throw AsyncDNSResolver.Error.noData()
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = ByteBuffer(bytes: bufferPtr)

            guard let priority = buffer.readInteger(as: UInt16.self),
                  let host = self.readName(&buffer) else {
                throw AsyncDNSResolver.Error.badResponse()
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

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> TXTRecord {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                throw AsyncDNSResolver.Error.noData()
            }
            let txt = String(cString: ptr.advanced(by: 1))
            return TXTRecord(txt: txt)
        }

        func generateReply(records: [TXTRecord]) throws -> [TXTRecord] {
            records
        }
    }

    struct SRVQueryReplyHandler: DNSSDQueryReplyHandler {
        static let instance = SRVQueryReplyHandler()

        func parseRecord(data: UnsafeRawPointer?, length: UInt16) throws -> SRVRecord {
            guard let ptr = data?.assumingMemoryBound(to: UInt8.self) else {
                throw AsyncDNSResolver.Error.noData()
            }

            let bufferPtr = UnsafeBufferPointer(start: ptr, count: Int(length))
            var buffer = ByteBuffer(bytes: bufferPtr)

            guard let priority = buffer.readInteger(as: UInt16.self),
                  let weight = buffer.readInteger(as: UInt16.self),
                  let port = buffer.readInteger(as: UInt16.self),
                  let host = self.readName(&buffer) else {
                throw AsyncDNSResolver.Error.badResponse()
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
    func readName(_ buffer: inout ByteBuffer) -> String? {
        var parts: [String] = []
        while let length = buffer.readInteger(as: UInt8.self),
              length > 0,
              let part = buffer.readString(length: Int(length)) {
            parts.append(part)
        }
        return parts.isEmpty ? nil : parts.joined(separator: ".")
    }

    func ensureOne<R>(records: [R]) throws -> R {
        guard records.count <= 1 else {
            throw AsyncDNSResolver.Error.badResponse("expected 1 record but got \(records.count)")
        }
        guard let record = records.first else {
            throw AsyncDNSResolver.Error.noData()
        }
        return record
    }
}
#endif
