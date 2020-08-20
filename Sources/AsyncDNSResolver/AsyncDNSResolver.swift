import CAsyncDNSResolver
import Dispatch
import Logging

// MARK: - Async DNS resolver API

public class AsyncDNSResolver {
    private let logger = Logger(label: "\(AsyncDNSResolver.self)")

    private let options: Options
    let ares: Ares

    public init(options: Options) throws {
        self.options = options
        self.ares = try Ares(options: options.aresOptions)
    }

    public convenience init() throws {
        try self.init(options: .default)
    }

    public func query(_ query: Query) {
        switch query {
        case .A(let name, let handler):
            self.ares.query(type: .A, name: name, handler: .init(parser: Ares.AQueryResultParser.instance, handler))
        case .AAAA(let name, let handler):
            self.ares.query(type: .AAAA, name: name, handler: .init(parser: Ares.AAAAQueryResultParser.instance, handler))
        case .NS(let name, let handler):
            self.ares.query(type: .NS, name: name, handler: .init(parser: Ares.NSQueryResultParser.instance, handler))
        case .CNAME(let name, let handler):
            self.ares.query(type: .CNAME, name: name, handler: .init(parser: Ares.CNAMEQueryResultParser.instance, handler))
        case .SOA(let name, let handler):
            self.ares.query(type: .SOA, name: name, handler: .init(parser: Ares.SOAQueryResultParser.instance, handler))
        case .PTR(let name, let handler):
            self.ares.query(type: .PTR, name: name, handler: .init(parser: Ares.PTRQueryResultParser.instance, handler))
        case .MX(let name, let handler):
            self.ares.query(type: .MX, name: name, handler: .init(parser: Ares.MXQueryResultParser.instance, handler))
        case .TXT(let name, let handler):
            self.ares.query(type: .TXT, name: name, handler: .init(parser: Ares.TXTQueryResultParser.instance, handler))
        case .SRV(let name, let handler):
            self.ares.query(type: .SRV, name: name, handler: .init(parser: Ares.SRVQueryResultParser.instance, handler))
        case .NAPTR(let name, let handler):
            self.ares.query(type: .NAPTR, name: name, handler: .init(parser: Ares.NAPTRQueryResultParser.instance, handler))
        }
    }

    public enum Query {
        /// Looks up the A records associated with `name`. Upon completion, `handler` is called with the result.
        case A(name: String, handler: (Result<[ARecord], Swift.Error>) -> Void)
        /// Looks up the AAAA records associated with `name`. Upon completion, `handler` is called with the result.
        case AAAA(name: String, handler: (Result<[AAAARecord], Swift.Error>) -> Void)
        /// Looks up the NS records associated with `name`. Upon completion, `handler` is called with the result.
        case NS(name: String, handler: (Result<[String], Swift.Error>) -> Void)
        /// Looks up the CNAME record associated with `name`. Upon completion, `handler` is called with the result.
        case CNAME(name: String, handler: (Result<String, Swift.Error>) -> Void)
        /// Looks up the SOA record associated with `name`. Upon completion, `handler` is called with the result.
        case SOA(name: String, handler: (Result<SOARecord, Swift.Error>) -> Void)
        /// Looks up the PTR records associated with `name`. Upon completion, `handler` is called with the result.
        case PTR(name: String, handler: (Result<[String], Swift.Error>) -> Void)
        /// Looks up the MX records associated with `name`. Upon completion, `handler` is called with the result.
        case MX(name: String, handler: (Result<[MXRecord], Swift.Error>) -> Void)
        /// Looks up the TXT records associated with `name`. Upon completion, `handler` is called with the result.
        case TXT(name: String, handler: (Result<[TXTRecord], Swift.Error>) -> Void)
        /// Looks up the SRV records associated with `name`. Upon completion, `handler` is called with the result.
        case SRV(name: String, handler: (Result<[SRVRecord], Swift.Error>) -> Void)
        /// Looks up the NAPTR records associated with `name`. Upon completion, `handler` is called with the result.
        case NAPTR(name: String, handler: (Result<[NAPTRRecord], Swift.Error>) -> Void)
    }
}

// MARK: - c-ares queries

class Ares {
    typealias QueryCallback = @convention(c) (UnsafeMutableRawPointer?, CInt, CInt, UnsafeMutablePointer<CUnsignedChar>?, CInt) -> Void

    private let queue = DispatchQueue(label: "c-ares.query.queue")

    private let options: AresOptions
    internal let channel: AresChannel
    private let queryProcessor: QueryProcessor

    init(options: AresOptions) throws {
        self.options = options
        self.channel = try AresChannel(options: options)

        // Need to call `ares_process` or `ares_process_fd` for query callbacks to happen
        self.queryProcessor = QueryProcessor(channel: self.channel)
        self.queryProcessor.start()
    }

    func query(type: QueryType, name: String, handler: QueryResultHandler) {
        // Wrap `handler` into a pointer so we can pass it to callback. The pointer will be deallocated in there later.
        let argPointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<QueryResultHandler>.stride, alignment: MemoryLayout<QueryResultHandler>.alignment)
        argPointer.initializeMemory(as: QueryResultHandler.self, repeating: handler, count: 1)

        let queryCallback: QueryCallback = { arg, status, _, buf, len in
            guard let argPointer = arg else {
                preconditionFailure("'arg' is nil. This is a bug.")
            }

            let handler = QueryResultHandler(pointer: argPointer)
            defer { argPointer.deallocate() }

            handler.handle(status: status, buffer: buf, length: len)
        }

        self.queue.async {
            self.channel.withChannel { channel in
                ares_query(channel, name, DNSClass.IN.rawValue, type.rawValue, queryCallback, argPointer)
            }
        }
    }

    /// See `arpa/nameser.h`.
    private enum DNSClass: CInt {
        case IN = 1
    }

    /// See `arpa/nameser.h`.
    enum QueryType: CInt {
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
}

extension Ares {
    struct QueryResultHandler {
        private let _handler: (CInt, UnsafeMutablePointer<CUnsignedChar>?, CInt) -> Void
        private let _errorHandler: (Error) -> Void

        init<T, Parser: AresQueryResultParser>(parser: Parser, _ handler: @escaping (Result<T, Error>) -> Void) where Parser.ResultType == T {
            self._handler = { status, buffer, length in
                guard status == ARES_SUCCESS else {
                    return handler(.failure(AsyncDNSResolver.Error(code: status, "Query failed")))
                }

                let result = parser.parse(buffer: buffer, length: length)
                handler(result)
            }
            self._errorHandler = { error in
                handler(.failure(error))
            }
        }

        init(pointer: UnsafeMutableRawPointer) {
            let handlerPointer = pointer.assumingMemoryBound(to: Self.self)
            self = handlerPointer.pointee
        }

        func handle(status: CInt, buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) {
            self._handler(status, buffer, length)
        }

        func handleError(_ error: Error) {
            self._errorHandler(error)
        }
    }
}

extension Ares {
    // TODO: implement this more nicely using NIO EventLoop?
    // See:
    // https://github.com/dimbleby/c-ares-resolver/blob/master/src/unix/eventloop.rs
    // https://github.com/dimbleby/rust-c-ares/blob/master/src/channel.rs
    // https://github.com/dimbleby/rust-c-ares/blob/master/examples/event-loop.rs
    class QueryProcessor {
        private let queue = DispatchQueue(label: "c-ares.process.queue")

        private let channel: AresChannel
        private let pollInterval: DispatchTimeInterval

        init(channel: AresChannel, pollInterval: DispatchTimeInterval = .milliseconds(10)) {
            self.channel = channel
            self.pollInterval = pollInterval
        }

        /// Asks c-ares for the set of socket descriptors we are waiting on for the `ares_channel`'s pending queries
        /// then call `ares_process_fd` if any is ready for read and/or write.
        /// c-ares returns up to ARES_GETSOCK_MAXNUM socket descriptors only. If more are in use (unlikely) they are not reported back.
        func poll() {
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
            self.queue.asyncAfter(deadline: DispatchTime.now() + self.pollInterval) { [weak self] in
                if let self = self {
                    self.poll()
                }
            }
        }
    }
}

// MARK: - Query result parsers

protocol AresQueryResultParser {
    associatedtype ResultType

    func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<ResultType, Error>
}

extension Ares {
    struct AQueryResultParser: AresQueryResultParser {
        static let instance = AQueryResultParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<[ARecord], Error> {
            // `hostent` is not needed, but if we don't allocate and pass it as an arg c-ares will allocate one
            // and free it automatically, and that might cause TSAN errors in `ares_free_hostent`. If we allocate
            // it then we control when it's freed.
            let hostentPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<hostent>?>.allocate(capacity: 1)
            defer { hostentPtrPtr.deallocate() }

            let addrttlsPointer = UnsafeMutablePointer<ares_addrttl>.allocate(capacity: 1)
            defer { addrttlsPointer.deallocate() }
            let naddrttlsPointer = UnsafeMutablePointer<CInt>.allocate(capacity: 1)
            defer { naddrttlsPointer.deallocate() }

            let parseStatus = ares_parse_a_reply(buffer, length, hostentPtrPtr, addrttlsPointer, naddrttlsPointer)
            guard parseStatus == ARES_SUCCESS else {
                return .failure(AsyncDNSResolver.Error(code: parseStatus, "Failed to parse A query result"))
            }

            let aRecords = Array(UnsafeBufferPointer(start: addrttlsPointer, count: Int(naddrttlsPointer.pointee)))
                .map { ARecord(address: $0.ipaddr, ttl: $0.ttl) }
            return .success(aRecords)
        }
    }

    struct AAAAQueryResultParser: AresQueryResultParser {
        static let instance = AAAAQueryResultParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<[AAAARecord], Error> {
            // `hostent` is not needed, but if we don't allocate and pass it as an arg c-ares will allocate one
            // and free it automatically, and that might cause TSAN errors in `ares_free_hostent`. If we allocate
            // it then we control when it's freed.
            let hostentPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<hostent>?>.allocate(capacity: 1)
            defer { hostentPtrPtr.deallocate() }

            let addrttlsPointer = UnsafeMutablePointer<ares_addr6ttl>.allocate(capacity: 1)
            defer { addrttlsPointer.deallocate() }
            let naddrttlsPointer = UnsafeMutablePointer<CInt>.allocate(capacity: 1)
            defer { naddrttlsPointer.deallocate() }

            let parseStatus = ares_parse_aaaa_reply(buffer, length, hostentPtrPtr, addrttlsPointer, naddrttlsPointer)
            guard parseStatus == ARES_SUCCESS else {
                return .failure(AsyncDNSResolver.Error(code: parseStatus, "Failed to parse AAAA query result"))
            }

            let aaaaRecords: [AAAARecord] = Array(UnsafeBufferPointer(start: addrttlsPointer, count: Int(naddrttlsPointer.pointee)))
                .map { AAAARecord(address: $0.ip6addr, ttl: $0.ttl) }
            return .success(aaaaRecords)
        }
    }

    struct NSQueryResultParser: AresQueryResultParser {
        static let instance = NSQueryResultParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<[String], Error> {
            let hostentPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<hostent>?>.allocate(capacity: 1)
            defer { hostentPtrPtr.deallocate() }

            let parseStatus = ares_parse_ns_reply(buffer, length, hostentPtrPtr)
            guard parseStatus == ARES_SUCCESS else {
                return .failure(AsyncDNSResolver.Error(code: parseStatus, "Failed to parse NS query result"))
            }

            guard let hostent = hostentPtrPtr.pointee?.pointee else {
                return .failure(AsyncDNSResolver.Error.noData("No NS records found"))
            }

            let nameServers = self.toStringArray(from: hostent.h_aliases)
            return .success(nameServers ?? [])
        }
    }

    struct CNAMEQueryResultParser: AresQueryResultParser {
        static let instance = CNAMEQueryResultParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<String, Error> {
            let hostentPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<hostent>?>.allocate(capacity: 1)
            defer { hostentPtrPtr.deallocate() }

            let parseStatus = ares_parse_a_reply(buffer, length, hostentPtrPtr, nil, nil)
            guard parseStatus == ARES_SUCCESS else {
                return .failure(AsyncDNSResolver.Error(code: parseStatus, "Failed to parse CNAME query result"))
            }

            guard let hostent = hostentPtrPtr.pointee?.pointee else {
                return .failure(AsyncDNSResolver.Error.noData("No CNAME record found"))
            }

            return .success(String(cString: hostent.h_name))
        }
    }

    struct SOAQueryResultParser: AresQueryResultParser {
        static let instance = SOAQueryResultParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<SOARecord, Error> {
            let soaReplyPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<ares_soa_reply>?>.allocate(capacity: 1)
            defer { soaReplyPtrPtr.deallocate() }

            let parseStatus = ares_parse_soa_reply(buffer, length, soaReplyPtrPtr)
            guard parseStatus == ARES_SUCCESS else {
                return .failure(AsyncDNSResolver.Error(code: parseStatus, "Failed to parse SOA query result"))
            }

            guard let soaReply = soaReplyPtrPtr.pointee?.pointee else {
                return .failure(AsyncDNSResolver.Error.noData("No SOA record found"))
            }

            let soaRecord = SOARecord(
                nsName: soaReply.nsname.map { String(cString: $0) },
                hostMaster: soaReply.hostmaster.map { String(cString: $0) },
                serial: soaReply.serial,
                refresh: soaReply.refresh,
                retry: soaReply.retry,
                expire: soaReply.expire,
                minTTL: soaReply.minttl
            )
            return .success(soaRecord)
        }
    }

    struct PTRQueryResultParser: AresQueryResultParser {
        static let instance = PTRQueryResultParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<[String], Error> {
            let dummyAddrPointer = UnsafeMutablePointer<CChar>.allocate(capacity: 1)
            defer { dummyAddrPointer.deallocate() }
            let hostentPtrPtr = UnsafeMutablePointer<UnsafeMutablePointer<hostent>?>.allocate(capacity: 1)
            defer { hostentPtrPtr.deallocate() }

            let parseStatus = ares_parse_ptr_reply(buffer, length, dummyAddrPointer, INET_ADDRSTRLEN, AF_INET, hostentPtrPtr)
            guard parseStatus == ARES_SUCCESS else {
                return .failure(AsyncDNSResolver.Error(code: parseStatus, "Failed to parse PTR query result"))
            }

            guard let hostent = hostentPtrPtr.pointee?.pointee else {
                return .failure(AsyncDNSResolver.Error.noData("No PTR records found"))
            }

            let hostnames = self.toStringArray(from: hostent.h_aliases)
            return .success(hostnames ?? [])
        }
    }

    struct MXQueryResultParser: AresQueryResultParser {
        static let instance = MXQueryResultParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<[MXRecord], Error> {
            let mxsPointer = UnsafeMutablePointer<UnsafeMutablePointer<ares_mx_reply>?>.allocate(capacity: 1)
            defer { mxsPointer.deallocate() }

            let parseStatus = ares_parse_mx_reply(buffer, length, mxsPointer)
            guard parseStatus == ARES_SUCCESS else {
                return .failure(AsyncDNSResolver.Error(code: parseStatus, "Failed to parse MX query result"))
            }

            var mxRecords = [MXRecord]()
            var mxRecordOptional = mxsPointer.pointee?.pointee
            while let mxRecord = mxRecordOptional {
                mxRecords.append(MXRecord(host: String(cString: mxRecord.host), priority: mxRecord.priority))
                mxRecordOptional = mxRecord.next?.pointee
            }
            return .success(mxRecords)
        }
    }

    struct TXTQueryResultParser: AresQueryResultParser {
        static let instance = TXTQueryResultParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<[TXTRecord], Error> {
            let txtsPointer = UnsafeMutablePointer<UnsafeMutablePointer<ares_txt_reply>?>.allocate(capacity: 1)
            defer { txtsPointer.deallocate() }

            let parseStatus = ares_parse_txt_reply(buffer, length, txtsPointer)
            guard parseStatus == ARES_SUCCESS else {
                return .failure(AsyncDNSResolver.Error(code: parseStatus, "Failed to parse TXT query result"))
            }

            var txtRecords = [TXTRecord]()
            var txtRecordOptional = txtsPointer.pointee?.pointee
            while let txtRecord = txtRecordOptional {
                txtRecords.append(TXTRecord(txt: String(cString: txtRecord.txt)))
                txtRecordOptional = txtRecord.next?.pointee
            }
            return .success(txtRecords)
        }
    }

    struct SRVQueryResultParser: AresQueryResultParser {
        static let instance = SRVQueryResultParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<[SRVRecord], Error> {
            let srvsPointer = UnsafeMutablePointer<UnsafeMutablePointer<ares_srv_reply>?>.allocate(capacity: 1)
            defer { srvsPointer.deallocate() }

            let parseStatus = ares_parse_srv_reply(buffer, length, srvsPointer)
            guard parseStatus == ARES_SUCCESS else {
                return .failure(AsyncDNSResolver.Error(code: parseStatus, "Failed to parse SRV query result"))
            }

            var srvRecords = [SRVRecord]()
            var srvRecordOptional = srvsPointer.pointee?.pointee
            while let srvRecord = srvRecordOptional {
                srvRecords.append(SRVRecord(host: String(cString: srvRecord.host), port: srvRecord.port, weight: srvRecord.weight, priority: srvRecord.priority))
                srvRecordOptional = srvRecord.next?.pointee
            }
            return .success(srvRecords)
        }
    }

    struct NAPTRQueryResultParser: AresQueryResultParser {
        static let instance = NAPTRQueryResultParser()

        func parse(buffer: UnsafeMutablePointer<CUnsignedChar>?, length: CInt) -> Result<[NAPTRRecord], Error> {
            let naptrsPointer = UnsafeMutablePointer<UnsafeMutablePointer<ares_naptr_reply>?>.allocate(capacity: 1)
            defer { naptrsPointer.deallocate() }

            let parseStatus = ares_parse_naptr_reply(buffer, length, naptrsPointer)
            guard parseStatus == ARES_SUCCESS else {
                return .failure(AsyncDNSResolver.Error(code: parseStatus, "Failed to parse NAPTR query result"))
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
            return .success(naptrRecords)
        }
    }
}

extension AresQueryResultParser {
    func toStringArray(from cStringArray: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> [String]? {
        guard let cStringArray = cStringArray else {
            return nil
        }

        var result = [String]()
        var stringPointer = cStringArray
        while let ptr = stringPointer.pointee {
            result.append(String(cString: ptr))
            stringPointer = stringPointer.advanced(by: 1)
        }

        return result
    }
}

// MARK: - Query result types

public enum IPAddress: CustomStringConvertible {
    case IPv4(in_addr)
    case IPv6(ares_in6_addr)

    public var family: Int32 {
        switch self {
        case .IPv4:
            return AF_INET
        case .IPv6:
            return AF_INET6
        }
    }

    var byteCount: Int32 {
        switch self {
        case .IPv4:
            return INET_ADDRSTRLEN
        case .IPv6:
            return INET6_ADDRSTRLEN
        }
    }

    init(_ address: in_addr) {
        self = .IPv4(address)
    }

    init(_ address: ares_in6_addr) {
        self = .IPv6(address)
    }

    public var description: String {
        var addressBytes = [CChar](repeating: 0, count: Int(self.byteCount))

        switch self {
        case .IPv4(var address):
            inet_ntop(self.family, &address, &addressBytes, socklen_t(self.byteCount))
        case .IPv6(var address):
            inet_ntop(self.family, &address, &addressBytes, socklen_t(self.byteCount))
        }

        return String(cString: addressBytes)
    }
}

public struct ARecord {
    public let address: IPAddress
    public let ttl: Int32

    init(address: in_addr, ttl: Int32) {
        self.address = IPAddress(address)
        self.ttl = ttl
    }
}

public struct AAAARecord {
    public let address: IPAddress
    public let ttl: Int32

    init(address: ares_in6_addr, ttl: Int32) {
        self.address = IPAddress(address)
        self.ttl = ttl
    }
}

public struct SOARecord {
    public let nsName: String?
    public let hostMaster: String?
    public let serial: UInt32
    public let refresh: UInt32
    public let retry: UInt32
    public let expire: UInt32
    public let minTTL: UInt32
}

public struct MXRecord {
    public let host: String
    public let priority: UInt16
}

public struct TXTRecord {
    public let txt: String
}

public struct SRVRecord {
    public let host: String
    public let port: UInt16
    public let weight: UInt16
    public let priority: UInt16
}

public struct NAPTRRecord {
    public let flags: String?
    public let service: String?
    public let regExp: String?
    public let replacement: String
    public let order: UInt16
    public let preference: UInt16
}
