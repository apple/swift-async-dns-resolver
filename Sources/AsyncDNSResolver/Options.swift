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

import CAsyncDNSResolver

// MARK: - Options for async DNS resolver

extension AsyncDNSResolver {
    public struct Options {
        public static var `default`: Options {
            .init()
        }

        /// Flags controlling the behavior of the resolver.
        ///
        /// - SeeAlso: `AsyncDNSResolver.Options.Flags`
        public var flags: Flags = .init()

        /// The number of milliseconds each name server is given to respond to a query on the first try. (After the first try, the
        /// timeout algorithm becomes more complicated, but scales linearly with the value of timeout).
        public var timeoutMillis: Int32 = 3000

        /// The number of attempts the resolver will try contacting each name server before giving up.
        public var attempts: Int32 = 3

        /// The number of dots which must be present in a domain name for it to be queried for "as is" prior to querying for it
        /// with the default domain extensions appended. The value here is the default unless set otherwise by `resolv.conf`
        /// or the `RES_OPTIONS` environment variable.
        public var numberOfDots: Int32 = 1

        /// The UDP port to use for queries. The default value is 53, the standard name service port.
        public var udpPort: UInt16 = 53

        /// The TCP port to use for queries. The default value is 53, the standard name service port.
        public var tcpPort: UInt16 = 53

        /// The socket send buffer size.
        public var socketSendBufferSize: Int32?

        /// The socket receive buffer size.
        public var socketReceiveBufferSize: Int32?

        /// The EDNS packet size.
        public var ednsPacketSize: Int32?

        /// Configures round robin selection of nameservers.
        public var rotate: Bool?

        /// The path to use for reading the resolv.conf file. The `resolvconf_path` should be set to a path string, and
        /// will be honored on \*nix like systems. The default is `/etc/resolv.conf`.
        public var resolvConfPath: String?

        /// The path to use for reading the hosts file. The `hosts_path` should be set to a path string, and
        /// will be honored on \*nix like systems. The default is `/etc/hosts`.
        public var hostsFilePath: String?

        /// The lookups to perform for host queries. `lookups` should be set to a string of the characters "b" or "f",
        /// where "b" indicates a DNS lookup and "f" indicates a lookup in the hosts file.
        public var lookups: String?

        /// The domains to search, instead of the domains specified in `resolv.conf` or the domain derived
        /// from the kernel hostname variable.
        public var domains: [String]?

        /// The list of servers to contact, instead of the servers specified in `resolv.conf` or the local named.
        ///
        /// String format is `host[:port]`. IPv6 addresses with ports require square brackets. e.g. `[2001:4860:4860::8888]:53`.
        public var servers: [String]?

        /// The address sortlist configuration, so that addresses returned by `ares_gethostbyname` are sorted
        /// according to it.
        ///
        /// String format IP-address-netmask pairs. The netmask is optional but follows the address after a slash if present.
        /// e.g., `130.155.160.0/255.255.240.0 130.155.0.0`.
        public var sortlist: [String]?
    }
}

extension AsyncDNSResolver.Options {
    public struct Flags: OptionSet {
        public let rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Always use TCP queries (the "virtual circuit") instead of UDP queries. Normally, TCP is only used if a UDP query yields a truncated result.
        public static let USEVC = Flags(rawValue: ARES_FLAG_USEVC)
        /// Only query the first server in the list of servers to query.
        public static let PRIMARY = Flags(rawValue: ARES_FLAG_PRIMARY)
        /// If a truncated response to a UDP query is received, do not fall back to TCP; simply continue on with the truncated response.
        public static let IGNTC = Flags(rawValue: ARES_FLAG_IGNTC)
        /// Do not set the "recursion desired" bit on outgoing queries, so that the name server being contacted will not try to fetch the answer
        /// from other servers if it doesn't know the answer locally. Be aware that this library will not do the recursion for you. Recursion must be
        /// handled by the client calling this library.
        public static let NORECURSE = Flags(rawValue: ARES_FLAG_NORECURSE)
        /// Do not close communications sockets when the number of active queries drops to zero.
        public static let STAYOPEN = Flags(rawValue: ARES_FLAG_STAYOPEN)
        /// Do not use the default search domains; only query hostnames as-is or as aliases.
        public static let NOSEARCH = Flags(rawValue: ARES_FLAG_NOSEARCH)
        /// Do not honor the HOSTALIASES environment variable, which normally specifies a file of hostname translations.
        public static let NOALIASES = Flags(rawValue: ARES_FLAG_NOALIASES)
        /// Do not discard responses with the SERVFAIL, NOTIMP, or REFUSED response code or responses whose questions don't match the
        /// questions in the request. Primarily useful for writing clients which might be used to test or debug name servers.
        public static let NOCHECKRESP = Flags(rawValue: ARES_FLAG_NOCHECKRESP)
        /// Include an EDNS pseudo-resource record (RFC 2671) in generated requests.
        public static let EDNS = Flags(rawValue: ARES_FLAG_EDNS)
    }
}

extension AsyncDNSResolver.Options {
    var aresOptions: AresOptions {
        let aresOptions = AresOptions()
        aresOptions.setFlags(self.flags.rawValue)
        aresOptions.setTimeoutMillis(self.timeoutMillis)
        aresOptions.setTries(self.attempts)
        aresOptions.setNDots(self.numberOfDots)
        aresOptions.setUDPPort(self.udpPort)
        aresOptions.setTCPPort(self.tcpPort)

        if let socketSendBufferSize = self.socketSendBufferSize {
            aresOptions.setSocketSendBufferSize(socketSendBufferSize)
        }

        if let socketReceiveBufferSize = self.socketReceiveBufferSize {
            aresOptions.setSocketReceiveBufferSize(socketReceiveBufferSize)
        }

        if let ednsPacketSize = self.ednsPacketSize {
            aresOptions.setEDNSPacketSize(ednsPacketSize)
        }

        if let rotate = self.rotate {
            if rotate {
                aresOptions.setRotate()
            } else {
                aresOptions.setNoRotate()
            }
        }

        if let resolvConfPath = self.resolvConfPath {
            aresOptions.setResolvConfPath(resolvConfPath)
        }

        if let hostsFilePath = self.hostsFilePath {
            aresOptions.setHostsFilePath(hostsFilePath)
        }

        if let lookups = self.lookups {
            aresOptions.setLookups(lookups)
        }

        if let domains = self.domains {
            aresOptions.setDomains(domains)
        }

        if let servers = self.servers {
            aresOptions.setServers(servers)
        }

        if let sortlist = self.sortlist {
            aresOptions.setSortlist(sortlist)
        }

        return aresOptions
    }
}

// MARK: - ares_options

/// Wrapper for `ares_options`.
///
/// `servers` /`nservers` and `sortlist`/`nsort` are configured by calling `ares_set_*`, which
/// require `ares_channel` argument. Even though `ares_options` has dedicated fields for them, they
/// are not set here but in `AresChannel` instead.
class AresOptions {
    let pointer: UnsafeMutablePointer<ares_options>

    private var resolvConfPathPointer: UnsafeMutablePointer<CChar>?
    private var hostsFilePathPointer: UnsafeMutablePointer<CChar>?
    private var lookupsPointer: UnsafeMutablePointer<CChar>?
    private var domainPointers: [UnsafeMutablePointer<CChar>?]?

    private(set) var servers: [String]?
    private(set) var sortlist: [String]?

    private(set) var _optionMasks: AresOptionMasks = .init()
    var optionMasks: AresOptionMasks.RawValue {
        self._optionMasks.rawValue
    }

    var underlying: ares_options {
        self.pointer.pointee
    }

    deinit {
        self.pointer.deallocate()
        self.resolvConfPathPointer?.deallocate()
        self.hostsFilePathPointer?.deallocate()
        self.lookupsPointer?.deallocate()
        self.domainPointers?.deallocate()
    }

    init() {
        self.pointer = UnsafeMutablePointer<ares_options>.allocate(capacity: 1)
        self.pointer.pointee = ares_options()
    }

    func setFlags(_ flags: CInt) {
        self.set(option: .FLAGS, keyPath: \.flags, value: flags)
    }

    func setTimeoutMillis(_ timeoutMillis: CInt) {
        self.set(option: .TIMEOUTMS, keyPath: \.timeout, value: timeoutMillis)
    }

    func setTries(_ tries: CInt) {
        self.set(option: .TRIES, keyPath: \.tries, value: tries)
    }

    func setNDots(_ ndots: CInt) {
        self.set(option: .NDOTS, keyPath: \.ndots, value: ndots)
    }

    func setUDPPort(_ udpPort: CUnsignedShort) {
        self.set(option: .UDP_PORT, keyPath: \.udp_port, value: udpPort)
    }

    func setTCPPort(_ tcpPort: CUnsignedShort) {
        self.set(option: .TCP_PORT, keyPath: \.tcp_port, value: tcpPort)
    }

    func setSocketSendBufferSize(_ socketSendBufferSize: CInt) {
        self.set(option: .SOCK_SNDBUF, keyPath: \.socket_send_buffer_size, value: socketSendBufferSize)
    }

    func setSocketReceiveBufferSize(_ socketReceiveBufferSize: CInt) {
        self.set(option: .SOCK_RCVBUF, keyPath: \.socket_receive_buffer_size, value: socketReceiveBufferSize)
    }

    func setEDNSPacketSize(_ ednsPacketSize: CInt) {
        self.set(option: .EDNSPSZ, keyPath: \.ednspsz, value: ednsPacketSize)
    }

    func setRotate() {
        self._optionMasks.insert(.ROTATE)
        self._optionMasks.remove(.NOROTATE)
    }

    func setNoRotate() {
        self._optionMasks.insert(.NOROTATE)
        self._optionMasks.remove(.ROTATE)
    }

    func setResolvConfPath(_ resolvConfPath: String) {
        // The pointer is being replaced so deallocate it first
        self.resolvConfPathPointer?.deallocate()
        self.resolvConfPathPointer = resolvConfPath.ccharArrayPointer
        self.set(option: .RESOLVCONF, keyPath: \.resolvconf_path, value: self.resolvConfPathPointer)
    }

    func setHostsFilePath(_ hostsFilePath: String) {
        // The pointer is being replaced so deallocate it first
        self.hostsFilePathPointer?.deallocate()
        self.hostsFilePathPointer = hostsFilePath.ccharArrayPointer
        self.set(option: .HOSTS_FILE, keyPath: \.hosts_path, value: self.hostsFilePathPointer)
    }

    func setLookups(_ lookups: String) {
        // The pointer is being replaced so deallocate it first
        self.lookupsPointer?.deallocate()
        self.lookupsPointer = lookups.ccharArrayPointer
        self.set(option: .LOOKUPS, keyPath: \.lookups, value: self.lookupsPointer)
    }

    func setDomains(_ domains: [String]) {
        // The pointers are being replaced so deallocate them first
        self.domainPointers?.deallocate()

        let domainPointers = domains.map(\.ccharArrayPointer)
        self.domainPointers = domainPointers

        domainPointers.withUnsafeBufferPointer { bufferPointer in
            let domainsPointer = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>(mutating: bufferPointer.baseAddress)
            self.set(option: .DOMAINS, keyPath: \.domains, value: domainsPointer)
            self.set(keyPath: \.ndomains, value: Int32(domains.count))
        }
    }

    func setServers(_ servers: [String]) {
        self.servers = servers
    }

    func setSortlist(_ sortlist: [String]) {
        self.sortlist = sortlist
    }

    /// Sets the callback function to be invoked when a socket changes state.
    ///
    /// `callback(data, socket, readable, writable)` will be called when a socket changes state:
    ///     - `data` is the optional `data` used to invoke `setSocketStateCallback`
    ///     - `readable` is set to true if the socket should listen for read events
    ///     - `writable` is set to true if the socket should listen for write events
    func setSocketStateCallback(with data: UnsafeMutableRawPointer? = nil, _ callback: @escaping SocketStateCallback) {
        self.set(option: .SOCK_STATE_CB, keyPath: \.sock_state_cb, value: callback)
        self.set(keyPath: \.sock_state_cb_data, value: data)
    }

    private func set<T>(option: AresOptionMasks, keyPath: WritableKeyPath<ares_options, T>, value: T) {
        self.set(keyPath: keyPath, value: value)
        self._optionMasks.insert(option)
    }

    private func set<T>(keyPath: WritableKeyPath<ares_options, T>, value: T) {
        var underlying = self.underlying
        underlying[keyPath: keyPath] = value
        self.pointer.pointee = underlying
    }

    private func set<T>(option: AresOptionMasks, keyPath: WritableKeyPath<ares_options, T?>, value: T?) {
        var underlying = self.underlying
        underlying[keyPath: keyPath] = value
        self.pointer.pointee = underlying
        self._optionMasks.insert(option)
    }
}

typealias Socket = ares_socket_t
typealias SocketStateCallback = @convention(c) (UnsafeMutableRawPointer?, Socket, CInt, CInt) -> Void

extension String {
    fileprivate var ccharArrayPointer: UnsafeMutablePointer<CChar>? {
        let count = self.utf8CString.count
        let destPointer = UnsafeMutablePointer<CChar>.allocate(capacity: count)
        self.withCString { srcPointer in
            destPointer.initialize(from: srcPointer, count: count)
        }
        return destPointer
    }
}

extension Sequence {
    fileprivate func deallocate<T>() where Element == UnsafeMutablePointer<T>? {
        self.forEach { $0?.deallocate() }
    }
}

/// Represents `ARES_OPT_*` values.
struct AresOptionMasks: OptionSet {
    let rawValue: CInt

    static let FLAGS = AresOptionMasks(rawValue: ARES_OPT_FLAGS)
    static let TIMEOUT = AresOptionMasks(rawValue: ARES_OPT_TIMEOUT) // Deprecated by TIMEOUTMS
    static let TRIES = AresOptionMasks(rawValue: ARES_OPT_TRIES)
    static let NDOTS = AresOptionMasks(rawValue: ARES_OPT_NDOTS)
    static let UDP_PORT = AresOptionMasks(rawValue: ARES_OPT_UDP_PORT)
    static let TCP_PORT = AresOptionMasks(rawValue: ARES_OPT_TCP_PORT)
    static let SERVERS = AresOptionMasks(rawValue: ARES_OPT_SERVERS)
    static let DOMAINS = AresOptionMasks(rawValue: ARES_OPT_DOMAINS)
    static let LOOKUPS = AresOptionMasks(rawValue: ARES_OPT_LOOKUPS)
    static let SOCK_STATE_CB = AresOptionMasks(rawValue: ARES_OPT_SOCK_STATE_CB)
    static let SORTLIST = AresOptionMasks(rawValue: ARES_OPT_SORTLIST)
    static let SOCK_SNDBUF = AresOptionMasks(rawValue: ARES_OPT_SOCK_SNDBUF)
    static let SOCK_RCVBUF = AresOptionMasks(rawValue: ARES_OPT_SOCK_RCVBUF)
    static let TIMEOUTMS = AresOptionMasks(rawValue: ARES_OPT_TIMEOUTMS)
    static let ROTATE = AresOptionMasks(rawValue: ARES_OPT_ROTATE)
    static let EDNSPSZ = AresOptionMasks(rawValue: ARES_OPT_EDNSPSZ)
    static let NOROTATE = AresOptionMasks(rawValue: ARES_OPT_NOROTATE)
    static let RESOLVCONF = AresOptionMasks(rawValue: ARES_OPT_RESOLVCONF)
    static let HOSTS_FILE = AresOptionMasks(rawValue: ARES_OPT_HOSTS_FILE)
}
