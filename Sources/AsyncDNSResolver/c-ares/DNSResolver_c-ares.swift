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

import CAsyncDNSResolver

/// ``DNSResolver`` implementation backed by c-ares C library.
public class CAresDNSResolver: DNSResolver {
    let options: Options
    let ares: Ares

    /// Initialize a `CAresDNSResolver` with the given options.
    ///
    /// - Parameters:
    ///   - options: ``CAresDNSResolver/Options`` to create resolver with.
    public init(options: Options) throws {
        self.options = options
        self.ares = try Ares(options: options.aresOptions)
    }

    /// Initialize a `CAresDNSResolver` using default options.
    public convenience init() throws {
        try self.init(options: .default)
    }

    /// See ``DNSResolver/queryA(name:)``.
    public func queryA(name: String) async throws -> [ARecord] {
        try await self.ares.query(type: .A, name: name, replyParser: Ares.AQueryReplyParser.instance)
    }

    /// See ``DNSResolver/queryAAAA(name:)``.
    public func queryAAAA(name: String) async throws -> [AAAARecord] {
        try await self.ares.query(type: .AAAA, name: name, replyParser: Ares.AAAAQueryReplyParser.instance)
    }

    /// See ``DNSResolver/queryNS(name:)``.
    public func queryNS(name: String) async throws -> NSRecord {
        try await self.ares.query(type: .NS, name: name, replyParser: Ares.NSQueryReplyParser.instance)
    }

    /// See ``DNSResolver/queryCNAME(name:)``.
    public func queryCNAME(name: String) async throws -> String {
        try await self.ares.query(type: .CNAME, name: name, replyParser: Ares.CNAMEQueryReplyParser.instance)
    }

    /// See ``DNSResolver/querySOA(name:)``.
    public func querySOA(name: String) async throws -> SOARecord {
        try await self.ares.query(type: .SOA, name: name, replyParser: Ares.SOAQueryReplyParser.instance)
    }

    /// See ``DNSResolver/queryPTR(name:)``.
    public func queryPTR(name: String) async throws -> PTRRecord {
        try await self.ares.query(type: .PTR, name: name, replyParser: Ares.PTRQueryReplyParser.instance)
    }

    /// See ``DNSResolver/queryMX(name:)``.
    public func queryMX(name: String) async throws -> [MXRecord] {
        try await self.ares.query(type: .MX, name: name, replyParser: Ares.MXQueryReplyParser.instance)
    }

    /// See ``DNSResolver/queryTXT(name:)``.
    public func queryTXT(name: String) async throws -> [TXTRecord] {
        try await self.ares.query(type: .TXT, name: name, replyParser: Ares.TXTQueryReplyParser.instance)
    }

    /// See ``DNSResolver/querySRV(name:)``.
    public func querySRV(name: String) async throws -> [SRVRecord] {
        try await self.ares.query(type: .SRV, name: name, replyParser: Ares.SRVQueryReplyParser.instance)
    }

    /// Lookup NAPTR records associated with `name`.
    ///
    /// - Parameters:
    ///   - name: The name to resolve.
    ///
    /// - Returns: ``NAPTRRecord``s for the given name.
    public func queryNAPTR(name: String) async throws -> [NAPTRRecord] {
        try await self.ares.query(type: .NAPTR, name: name, replyParser: Ares.NAPTRQueryReplyParser.instance)
    }
}

extension QueryType {
    fileprivate var intValue: CInt {
        /// See `arpa/nameser.h`.
        switch self {
        case .A:
            return 1
        case .NS:
            return 2
        case .CNAME:
            return 5
        case .SOA:
            return 6
        case .PTR:
            return 12
        case .MX:
            return 15
        case .TXT:
            return 16
        case .AAAA:
            return 28
        case .SRV:
            return 33
        case .NAPTR:
            return 35
        }
    }
}

// MARK: - c-ares query wrapper

class Ares {
    typealias QueryCallback = @convention(c) (UnsafeMutableRawPointer?, CInt, CInt, UnsafeMutablePointer<CUnsignedChar>?, CInt) -> Void

    let options: AresOptions
    let channel: AresChannel

    private let queryProcessor: QueryProcessor

    init(options: AresOptions) throws {
        self.options = options
        self.channel = try AresChannel(options: options)

        // Need to call `ares_process` or `ares_process_fd` for query callbacks to happen
        self.queryProcessor = QueryProcessor(channel: self.channel)
        self.queryProcessor.start()
    }

    func query<ReplyParser: AresQueryReplyParser>(
        type: QueryType,
        name: String,
        replyParser: ReplyParser
    ) async throws -> ReplyParser.Reply {
        try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    let handler = QueryReplyHandler(parser: replyParser, continuation)

                    // Wrap `handler` into a pointer so we can pass it to callback. The pointer will be deallocated in there later.
                    let handlerPointer = UnsafeMutableRawPointer.allocate(
                        byteCount: MemoryLayout<QueryReplyHandler>.stride,
                        alignment: MemoryLayout<QueryReplyHandler>.alignment
                    )
                    handlerPointer.initializeMemory(as: QueryReplyHandler.self, repeating: handler, count: 1)

                    let queryCallback: QueryCallback = { arg, status, _, buf, len in
                        guard let handlerPointer = arg else {
                            preconditionFailure("'arg' is nil. This is a bug.")
                        }

                        let handler = QueryReplyHandler(pointer: handlerPointer)
                        defer { handlerPointer.deallocate() }

                        handler.handle(status: status, buffer: buf, length: len)
                    }

                    self.channel.withChannel { channel in
                        ares_query(channel, name, DNSClass.IN.rawValue, type.intValue, queryCallback, handlerPointer)
                    }
                }
            },
            onCancel: {
                self.channel.withChannel { channel in
                    ares_cancel(channel)
                }
            }
        )
    }

    /// See `arpa/nameser.h`.
    private enum DNSClass: CInt {
        case IN = 1
    }
}

extension Ares {
    // TODO: implement this more nicely using NIO EventLoop?
    // See:
    // https://github.com/dimbleby/c-ares-resolver/blob/master/src/unix/eventloop.rs
    // https://github.com/dimbleby/rust-c-ares/blob/master/src/channel.rs
    // https://github.com/dimbleby/rust-c-ares/blob/master/examples/event-loop.rs
    class QueryProcessor {
        static let defaultPollInterval: UInt64 = 10 * 1_000_000 // 10ms

        private let channel: AresChannel
        private let pollIntervalNanos: UInt64

        private var pollingTask: Task<Void, Error>?

        deinit {
            self.pollingTask?.cancel()
        }

        init(channel: AresChannel, pollIntervalNanos: UInt64 = QueryProcessor.defaultPollInterval) {
            self.channel = channel
            self.pollIntervalNanos = pollIntervalNanos
        }

        /// Asks c-ares for the set of socket descriptors we are waiting on for the `ares_channel`'s pending queries
        /// then call `ares_process_fd` if any is ready for read and/or write.
        /// c-ares returns up to `ARES_GETSOCK_MAXNUM` socket descriptors only. If more are in use (unlikely) they are not reported back.
        func poll() async {
            var socks = [ares_socket_t](repeating: ares_socket_t(), count: Int(ARES_GETSOCK_MAXNUM))

            self.channel.withChannel { channel in
                // Indicates what actions (i.e., read/write) to wait for on the different sockets
                let bitmask = UInt32(ares_getsock(channel, &socks, ARES_GETSOCK_MAXNUM))

                for (index, socket) in socks.enumerated() {
                    let readableBit: UInt32 = 1 << UInt32(index)
                    let readable = (bitmask & readableBit) != 0
                    let writableBit = readableBit << UInt32(ARES_GETSOCK_MAXNUM)
                    let writable = (bitmask & writableBit) != 0

                    if readable || writable {
                        // `ARES_SOCKET_BAD` instructs c-ares not to perform the action
                        let readFD = readable ? socket : ARES_SOCKET_BAD
                        let writeFD = writable ? socket : ARES_SOCKET_BAD
                        ares_process_fd(channel, readFD, writeFD)
                    }
                }
            }

            // Schedule next poll
            self.schedule()
        }

        func start() {
            self.schedule()
        }

        private func schedule() {
            self.pollingTask = Task { [weak self] in
                guard let s = self else {
                    return
                }
                try await Task.sleep(nanoseconds: s.pollIntervalNanos)
                await s.poll()
            }
        }
    }
}

// MARK: - c-ares query reply handler

extension Ares {
    struct QueryReplyHandler {
        private let _handler: (CInt, UnsafeMutablePointer<CUnsignedChar>?, CInt) -> Void

        init<Parser: AresQueryReplyParser>(parser: Parser, _ continuation: CheckedContinuation<Parser.Reply, Error>) {
            self._handler = { status, buffer, length in
                guard status == ARES_SUCCESS else {
                    return continuation.resume(throwing: AsyncDNSResolver.Error(code: status))
                }

                do {
                    let reply = try parser.parse(buffer: buffer, length: length)
                    continuation.resume(returning: reply)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        init(pointer: UnsafeMutableRawPointer) {
            let handlerPointer = pointer.assumingMemoryBound(to: Self.self)
            self = handlerPointer.pointee
        }

        func handle(status: CInt, buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) {
            self._handler(status, buffer, length)
        }
    }
}

// MARK: - c-ares query reply parsers

protocol AresQueryReplyParser {
    associatedtype Reply

    func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> Reply
}

extension Ares {
    static let maxAddresses: Int = 32

    struct AQueryReplyParser: AresQueryReplyParser {
        static let instance = AQueryReplyParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> [ARecord] {
            // `hostent` is not needed, but if we don't allocate and pass it as an arg c-ares will allocate one
            // and free it automatically, and that might cause TSAN errors in `ares_free_hostent`. If we allocate
            // it then we control when it's freed.
            let hostentPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<hostent>?>.allocate(capacity: 1)
            defer { hostentPtrPtr.deallocate() }

            let addrttlsPointer = UnsafeMutablePointer<ares_addrttl>.allocate(capacity: Ares.maxAddresses)
            defer { addrttlsPointer.deallocate() }
            let naddrttlsPointer = UnsafeMutablePointer<CInt>.allocate(capacity: 1)
            defer { naddrttlsPointer.deallocate() }

            // Set a limit or else addrttl array won't be populated
            naddrttlsPointer.pointee = CInt(Ares.maxAddresses)

            let parseStatus = ares_parse_a_reply(buffer, length, hostentPtrPtr, addrttlsPointer, naddrttlsPointer)
            guard parseStatus == ARES_SUCCESS else {
                throw AsyncDNSResolver.Error(code: parseStatus, "failed to parse A query reply")
            }

            let records = Array(UnsafeBufferPointer(start: addrttlsPointer, count: Int(naddrttlsPointer.pointee)))
                .map { ARecord($0) }
            return records
        }
    }

    struct AAAAQueryReplyParser: AresQueryReplyParser {
        static let instance = AAAAQueryReplyParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> [AAAARecord] {
            // `hostent` is not needed, but if we don't allocate and pass it as an arg c-ares will allocate one
            // and free it automatically, and that might cause TSAN errors in `ares_free_hostent`. If we allocate
            // it then we control when it's freed.
            let hostentPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<hostent>?>.allocate(capacity: 1)
            defer { hostentPtrPtr.deallocate() }

            let addrttlsPointer = UnsafeMutablePointer<ares_addr6ttl>.allocate(capacity: Ares.maxAddresses)
            defer { addrttlsPointer.deallocate() }
            let naddrttlsPointer = UnsafeMutablePointer<CInt>.allocate(capacity: 1)
            defer { naddrttlsPointer.deallocate() }

            // Set a limit or else addrttl array won't be populated
            naddrttlsPointer.pointee = CInt(Ares.maxAddresses)

            let parseStatus = ares_parse_aaaa_reply(buffer, length, hostentPtrPtr, addrttlsPointer, naddrttlsPointer)
            guard parseStatus == ARES_SUCCESS else {
                throw AsyncDNSResolver.Error(code: parseStatus, "failed to parse AAAA query reply")
            }

            let records = Array(UnsafeBufferPointer(start: addrttlsPointer, count: Int(naddrttlsPointer.pointee)))
                .map { AAAARecord($0) }
            return records
        }
    }

    struct NSQueryReplyParser: AresQueryReplyParser {
        static let instance = NSQueryReplyParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> NSRecord {
            let hostentPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<hostent>?>.allocate(capacity: 1)
            defer { hostentPtrPtr.deallocate() }

            let parseStatus = ares_parse_ns_reply(buffer, length, hostentPtrPtr)
            guard parseStatus == ARES_SUCCESS else {
                throw AsyncDNSResolver.Error(code: parseStatus, "failed to parse NS query reply")
            }

            guard let hostent = hostentPtrPtr.pointee?.pointee else {
                throw AsyncDNSResolver.Error.noData("no NS records found")
            }

            let nameServers = toStringArray(hostent.h_aliases)
            return NSRecord(nameservers: nameServers ?? [])
        }
    }

    struct CNAMEQueryReplyParser: AresQueryReplyParser {
        static let instance = CNAMEQueryReplyParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> String {
            let hostentPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<hostent>?>.allocate(capacity: 1)
            defer { hostentPtrPtr.deallocate() }

            let parseStatus = ares_parse_a_reply(buffer, length, hostentPtrPtr, nil, nil)
            guard parseStatus == ARES_SUCCESS else {
                throw AsyncDNSResolver.Error(code: parseStatus, "failed to parse CNAME query reply")
            }

            guard let hostent = hostentPtrPtr.pointee?.pointee else {
                throw AsyncDNSResolver.Error.noData("no CNAME record found")
            }

            return String(cString: hostent.h_name)
        }
    }

    struct SOAQueryReplyParser: AresQueryReplyParser {
        static let instance = SOAQueryReplyParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> SOARecord {
            let soaReplyPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<ares_soa_reply>?>.allocate(capacity: 1)
            defer { soaReplyPtrPtr.deallocate() }

            let parseStatus = ares_parse_soa_reply(buffer, length, soaReplyPtrPtr)
            guard parseStatus == ARES_SUCCESS else {
                throw AsyncDNSResolver.Error(code: parseStatus, "failed to parse SOA query reply")
            }

            guard let soaReply = soaReplyPtrPtr.pointee?.pointee else {
                throw AsyncDNSResolver.Error.noData("no SOA record found")
            }

            return SOARecord(
                mname: soaReply.nsname.map { String(cString: $0) },
                rname: soaReply.hostmaster.map { String(cString: $0) },
                serial: soaReply.serial,
                refresh: soaReply.refresh,
                retry: soaReply.retry,
                expire: soaReply.expire,
                ttl: soaReply.minttl
            )
        }
    }

    struct PTRQueryReplyParser: AresQueryReplyParser {
        static let instance = PTRQueryReplyParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> PTRRecord {
            let dummyAddrPointer = UnsafeMutablePointer<CChar>.allocate(capacity: 1)
            defer { dummyAddrPointer.deallocate() }
            let hostentPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<hostent>?>.allocate(capacity: 1)
            defer { hostentPtrPtr.deallocate() }

            let parseStatus = ares_parse_ptr_reply(buffer, length, dummyAddrPointer, INET_ADDRSTRLEN, AF_INET, hostentPtrPtr)
            guard parseStatus == ARES_SUCCESS else {
                throw AsyncDNSResolver.Error(code: parseStatus, "failed to parse PTR query record")
            }

            guard let hostent = hostentPtrPtr.pointee?.pointee else {
                throw AsyncDNSResolver.Error.noData("no PTR record found")
            }

            let hostnames = toStringArray(hostent.h_aliases)
            return PTRRecord(names: hostnames ?? [])
        }
    }

    struct MXQueryReplyParser: AresQueryReplyParser {
        static let instance = MXQueryReplyParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> [MXRecord] {
            let mxsPointer = UnsafeMutablePointer<UnsafeMutablePointer<ares_mx_reply>?>.allocate(capacity: 1)
            defer { mxsPointer.deallocate() }

            let parseStatus = ares_parse_mx_reply(buffer, length, mxsPointer)
            guard parseStatus == ARES_SUCCESS else {
                throw AsyncDNSResolver.Error(code: parseStatus, "failed to parse MX query record")
            }

            var mxRecords = [MXRecord]()
            var mxRecordOptional = mxsPointer.pointee?.pointee
            while let mxRecord = mxRecordOptional {
                mxRecords.append(
                    MXRecord(
                        host: String(cString: mxRecord.host),
                        priority: mxRecord.priority
                    )
                )
                mxRecordOptional = mxRecord.next?.pointee
            }
            return mxRecords
        }
    }

    struct TXTQueryReplyParser: AresQueryReplyParser {
        static let instance = TXTQueryReplyParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> [TXTRecord] {
            let txtsPointer = UnsafeMutablePointer<UnsafeMutablePointer<ares_txt_reply>?>.allocate(capacity: 1)
            defer { txtsPointer.deallocate() }

            let parseStatus = ares_parse_txt_reply(buffer, length, txtsPointer)
            guard parseStatus == ARES_SUCCESS else {
                throw AsyncDNSResolver.Error(code: parseStatus, "failed to parse TXT query reply")
            }

            var txtRecords = [TXTRecord]()
            var txtRecordOptional = txtsPointer.pointee?.pointee
            while let txtRecord = txtRecordOptional {
                txtRecords.append(
                    TXTRecord(
                        txt: String(cString: txtRecord.txt)
                    )
                )
                txtRecordOptional = txtRecord.next?.pointee
            }
            return txtRecords
        }
    }

    struct SRVQueryReplyParser: AresQueryReplyParser {
        static let instance = SRVQueryReplyParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> [SRVRecord] {
            let replyPointer = UnsafeMutablePointer<UnsafeMutablePointer<ares_srv_reply>?>.allocate(capacity: 1)
            defer { replyPointer.deallocate() }

            let parseStatus = ares_parse_srv_reply(buffer, length, replyPointer)
            guard parseStatus == ARES_SUCCESS else {
                throw AsyncDNSResolver.Error(code: parseStatus, "failed to parse SRV query reply")
            }

            var srvRecords = [SRVRecord]()
            var srvRecordOptional = replyPointer.pointee?.pointee
            while let srvRecord = srvRecordOptional {
                srvRecords.append(
                    SRVRecord(
                        host: String(cString: srvRecord.host),
                        port: srvRecord.port,
                        weight: srvRecord.weight,
                        priority: srvRecord.priority
                    )
                )
                srvRecordOptional = srvRecord.next?.pointee
            }
            return srvRecords
        }
    }

    struct NAPTRQueryReplyParser: AresQueryReplyParser {
        static let instance = NAPTRQueryReplyParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) throws -> [NAPTRRecord] {
            let naptrsPointer = UnsafeMutablePointer<UnsafeMutablePointer<ares_naptr_reply>?>.allocate(capacity: 1)
            defer { naptrsPointer.deallocate() }

            let parseStatus = ares_parse_naptr_reply(buffer, length, naptrsPointer)
            guard parseStatus == ARES_SUCCESS else {
                throw AsyncDNSResolver.Error(code: parseStatus, "failed to parse NAPTR query reply")
            }

            var naptrRecords = [NAPTRRecord]()
            var naptrRecordOptional = naptrsPointer.pointee?.pointee
            while let naptrRecord = naptrRecordOptional {
                naptrRecords.append(
                    NAPTRRecord(
                        flags: String(cString: naptrRecord.flags),
                        service: String(cString: naptrRecord.service),
                        regExp: String(cString: naptrRecord.regexp),
                        replacement: String(cString: naptrRecord.replacement),
                        order: naptrRecord.order,
                        preference: naptrRecord.preference
                    )
                )
                naptrRecordOptional = naptrRecord.next?.pointee
            }
            return naptrRecords
        }
    }
}

// MARK: - helpers

private func toStringArray(_ arrayPointer: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> [String]? {
    guard let arrayPointer = arrayPointer else {
        return nil
    }

    var result = [String]()
    var stringPointer = arrayPointer
    while let ptr = stringPointer.pointee {
        result.append(String(cString: ptr))
        stringPointer = stringPointer.advanced(by: 1)
    }
    return result
}

extension IPAddress.IPv4 {
    init(_ address: in_addr) {
        var address = address
        var addressBytes = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &address, &addressBytes, socklen_t(INET_ADDRSTRLEN))
        self = .init(address: String(cString: addressBytes))
    }
}

extension IPAddress.IPv6 {
    init(_ address: ares_in6_addr) {
        var address = address
        var addressBytes = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        inet_ntop(AF_INET6, &address, &addressBytes, socklen_t(INET6_ADDRSTRLEN))
        self = .init(address: String(cString: addressBytes))
    }
}

extension ARecord {
    init(_ addrttl: ares_addrttl) {
        self.address = IPAddress.IPv4(addrttl.ipaddr)
        self.ttl = addrttl.ttl
    }
}

extension AAAARecord {
    init(_ addrttl: ares_addr6ttl) {
        self.address = IPAddress.IPv6(addrttl.ip6addr)
        self.ttl = addrttl.ttl
    }
}
