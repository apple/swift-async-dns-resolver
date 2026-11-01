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

// The test server uses POSIX sockets.
#if !os(Windows)
import Foundation
import XCTest

@testable import AsyncDNSResolver

#if canImport(Glibc)
private let streamSocket = Int32(SOCK_STREAM.rawValue)
private let datagramSocket = Int32(SOCK_DGRAM.rawValue)
#else
private let streamSocket = SOCK_STREAM
private let datagramSocket = SOCK_DGRAM
#endif

/// c-ares must only be told about sockets the OS reports as ready. Reporting a TCP socket as
/// writable during its handshake makes c-ares treat it as connected and send on it, which on
/// Darwin fails with `ENOTCONN` and surfaces as a spurious "connection refused".
///
/// None of these tests use a public DNS server. Established and failed connections are
/// exercised against a server on loopback, where a handshake finishes too quickly to observe,
/// so in-progress handshakes use a reserved address instead.
final class CAresSocketReadinessTests: XCTestCase {
    /// Reserved, non-routable (TEST-NET-1, RFC 5737): a TCP handshake with it never finishes.
    private static let blackholeServer = "192.0.2.1"

    private func makeResolver(
        server: String,
        flags: CAresDNSResolver.Options.Flags = .USEVC,
        timeoutMillis: Int32 = 5000
    ) throws -> CAresDNSResolver {
        var options = CAresDNSResolver.Options()
        options.servers = [server]
        options.flags = flags
        options.timeoutMillis = timeoutMillis
        options.attempts = 1
        return try CAresDNSResolver(options: options)
    }

    /// Returns a socket whose handshake is in progress. Skips the test where the network
    /// rejects or intercepts the connection, as the handshake can't be observed there.
    private func makeConnectingSocket() throws -> Int32 {
        let connecting = socket(AF_INET, streamSocket, 0)
        _ = fcntl(connecting, F_SETFL, O_NONBLOCK)

        var address = sockaddr_in(host: Self.blackholeServer, port: 53)
        let result = withSockaddr(&address) { connect(connecting, $0, $1) }
        let connectError = errno

        var descriptor = pollfd(fd: connecting, events: CShort(POLLOUT), revents: 0)
        guard result != 0, connectError == EINPROGRESS, poll(&descriptor, 1, 100) == 0 else {
            close(connecting)
            throw XCTSkip("this network doesn't leave a handshake with \(Self.blackholeServer) in progress")
        }
        return connecting
    }

    // MARK: Sockets that are still connecting

    /// Regression test: the core of the defect, at the level where it happens.
    func test_readySockets_doesNotReportSocketThatIsStillConnecting() throws {
        let connecting = try self.makeConnectingSocket()
        defer { close(connecting) }

        XCTAssertTrue(SocketRegistry.readySockets(in: [(connecting, true, true)]).isEmpty)
    }

    /// Regression test: a handshake that doesn't finish must end in a timeout. It used to fail
    /// almost immediately with `.connectionRefused` on Darwin.
    func test_tcpQuery_whileHandshakeIsInProgress_timesOut() async throws {
        close(try self.makeConnectingSocket())
        let resolver = try self.makeResolver(server: Self.blackholeServer, timeoutMillis: 500)

        do {
            let records = try await resolver.queryA(name: "example.com")
            XCTFail("expected a timeout, got \(records)")
        } catch let error as AsyncDNSResolver.Error {
            XCTAssertEqual(error.code, .timeout, "\(error)")
        }
    }

    /// Queries sharing a connection that is still being established stay independent:
    /// cancelling one leaves the other in flight until its own timeout.
    func test_tcpQuery_whileHandshakeIsInProgress_cancellationIsIsolated() async throws {
        close(try self.makeConnectingSocket())
        let resolver = try self.makeResolver(server: Self.blackholeServer, timeoutMillis: 1000)

        let cancelled = Task { try await resolver.queryA(name: "cancelled.example.com") }
        let survivor = Task { try await resolver.queryA(name: "survivor.example.com") }

        // Long enough for several polls to run against the connecting socket.
        try await Task.sleep(nanoseconds: 100_000_000)
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            XCTFail("expected the cancelled query to throw")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
        }

        do {
            let records = try await survivor.value
            XCTFail("expected a timeout, got \(records)")
        } catch let error as AsyncDNSResolver.Error {
            XCTAssertEqual(error.code, .timeout, "\(error)")
        }
    }

    // MARK: Established and failed sockets

    func test_tcpQuery_isAnswered() async throws {
        let server = try LoopbackDNSServer()
        defer { server.stop() }
        let resolver = try self.makeResolver(server: server.address)

        let records = try await resolver.queryA(name: "example.com")
        XCTAssertEqual(records.map(\.address.address), [LoopbackDNSServer.answerAddress])
    }

    func test_concurrentQueries_areAllAnswered() async throws {
        let server = try LoopbackDNSServer()
        defer { server.stop() }

        for flags: CAresDNSResolver.Options.Flags in [[], .USEVC] {
            let resolver = try self.makeResolver(server: server.address, flags: flags)
            try await withThrowingTaskGroup(of: [ARecord].self) { group in
                for index in 0..<50 {
                    group.addTask { try await resolver.queryA(name: "host\(index).example.com") }
                }
                for try await records in group {
                    XCTAssertEqual(records.map(\.address.address), [LoopbackDNSServer.answerAddress])
                }
            }
        }
    }

    func test_udpQuery_truncatedResponse_fallsBackToTCP() async throws {
        let server = try LoopbackDNSServer(truncateUDP: true)
        defer { server.stop() }
        let resolver = try self.makeResolver(server: server.address, flags: [])

        let records = try await resolver.queryA(name: "example.com")
        XCTAssertEqual(records.map(\.address.address), [LoopbackDNSServer.answerAddress])
        XCTAssertEqual(server.udpQueryCount, 1)
    }

    /// A failed connection is reported through `POLLERR`/`POLLHUP`. It must still reach c-ares
    /// so the query fails promptly rather than waiting for its timeout.
    func test_tcpQuery_connectionRefused_failsWithoutWaitingForTimeout() async throws {
        let server = try LoopbackDNSServer()
        let address = server.address
        server.stop()  // Nothing listens on the port from here on.
        let resolver = try self.makeResolver(server: address, timeoutMillis: 30_000)

        let start = Date()
        do {
            let records = try await resolver.queryA(name: "example.com")
            XCTFail("expected an error, got \(records)")
        } catch let error as AsyncDNSResolver.Error {
            XCTAssertEqual(error.code, .connectionRefused, "\(error)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }

    // MARK: readySockets

    func test_readySockets_reportsOnlyWhatIsReady() throws {
        var fds: [Int32] = [0, 0]
        XCTAssertEqual(socketpair(AF_UNIX, streamSocket, 0, &fds), 0)
        defer {
            close(fds[0])
            close(fds[1])
        }

        // Nothing to read yet.
        XCTAssertTrue(SocketRegistry.readySockets(in: [(fds[0], true, false)]).isEmpty)

        // Writable, and not reported as readable although read interest is registered.
        let writable = SocketRegistry.readySockets(in: [(fds[0], true, true)])
        XCTAssertEqual(writable.count, 1)
        XCTAssertEqual(writable.first?.readable, false)
        XCTAssertEqual(writable.first?.writable, true)

        // Readable once the peer has written.
        XCTAssertEqual(write(fds[1], "x", 1), 1)
        let readable = SocketRegistry.readySockets(in: [(fds[0], true, false)])
        XCTAssertEqual(readable.count, 1)
        XCTAssertEqual(readable.first?.socket, fds[0])
        XCTAssertEqual(readable.first?.readable, true)
        XCTAssertEqual(readable.first?.writable, false)
    }
}

// MARK: - Test server

/// A minimal DNS server on loopback that answers every question with a single A record.
private final class LoopbackDNSServer: @unchecked Sendable {
    static let answerAddress = "192.0.2.7"

    private(set) var address = ""
    private let truncateUDP: Bool
    private let tcpSocket: Int32
    private let udpSocket: Int32

    private let lock = NSLock()
    private var isStopped = false
    private var _udpQueryCount = 0
    private let finished = DispatchGroup()

    var udpQueryCount: Int {
        self.lock.withLock { self._udpQueryCount }
    }

    init(truncateUDP: Bool = false) throws {
        self.truncateUDP = truncateUDP
        self.tcpSocket = socket(AF_INET, streamSocket, 0)
        self.udpSocket = socket(AF_INET, datagramSocket, 0)

        // Let the kernel pick the TCP port, then claim it for UDP too.
        var address = sockaddr_in(host: "127.0.0.1", port: 0)
        try Self.check(withSockaddr(&address) { bind(self.tcpSocket, $0, $1) })
        try Self.check(listen(self.tcpSocket, 16))
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        try Self.check(
            withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    getsockname(self.tcpSocket, $0, &length)
                }
            }
        )
        self.address = "127.0.0.1:\(UInt16(bigEndian: address.sin_port))"
        try Self.check(withSockaddr(&address) { bind(self.udpSocket, $0, $1) })

        self.finished.enter()
        Thread.detachNewThread { [self] in
            self.run()
            self.finished.leave()
        }
    }

    func stop() {
        self.lock.withLock { self.isStopped = true }
        self.finished.wait()
        close(self.tcpSocket)
        close(self.udpSocket)
    }

    private func run() {
        while !self.lock.withLock({ self.isStopped }) {
            var descriptors = [
                pollfd(fd: self.udpSocket, events: CShort(POLLIN), revents: 0),
                pollfd(fd: self.tcpSocket, events: CShort(POLLIN), revents: 0),
            ]
            guard poll(&descriptors, nfds_t(descriptors.count), 10) > 0 else {
                continue
            }
            if descriptors[0].revents != 0 {
                self.serveUDP()
            }
            if descriptors[1].revents != 0 {
                self.serveTCPConnection()
            }
        }
    }

    private func serveUDP() {
        var query = [UInt8](repeating: 0, count: 512)
        var client = sockaddr_storage()
        var clientLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let count = withUnsafeMutablePointer(to: &client) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                recvfrom(self.udpSocket, &query, query.count, 0, $0, &clientLength)
            }
        }
        guard count > 0 else { return }
        self.lock.withLock { self._udpQueryCount += 1 }

        let response = Self.response(to: query[..<count], truncated: self.truncateUDP)
        _ = withUnsafePointer(to: &client) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                sendto(self.udpSocket, response, response.count, 0, $0, clientLength)
            }
        }
    }

    /// Answers length-prefixed queries until the client disconnects.
    private func serveTCPConnection() {
        let connection = accept(self.tcpSocket, nil, nil)
        guard connection >= 0 else { return }
        defer { close(connection) }

        while !self.lock.withLock({ self.isStopped }) {
            var descriptor = pollfd(fd: connection, events: CShort(POLLIN), revents: 0)
            guard poll(&descriptor, 1, 10) != 0 else { continue }

            guard let prefix = Self.read(connection, count: 2) else { return }
            let length = Int(prefix[0]) << 8 | Int(prefix[1])
            guard let query = Self.read(connection, count: length) else { return }

            let response = Self.response(to: query[...], truncated: false)
            let frame = [UInt8(response.count >> 8), UInt8(response.count & 0xff)] + response
            guard send(connection, frame, frame.count, 0) == frame.count else { return }
        }
    }

    private static func read(_ connection: Int32, count: Int) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: count)
        var offset = 0
        while offset < count {
            let received = bytes.withUnsafeMutableBytes {
                recv(connection, $0.baseAddress! + offset, count - offset, 0)
            }
            guard received > 0 else { return nil }
            offset += received
        }
        return bytes
    }

    /// Builds a response echoing the question of `query`, which has exactly one.
    private static func response(to query: ArraySlice<UInt8>, truncated: Bool) -> [UInt8] {
        let query = Array(query)
        var response = Array(query[0..<2])  // ID
        response += [truncated ? 0x82 : 0x80, 0x00]  // QR, optionally TC; NOERROR
        response += [0, 1, 0, truncated ? 0 : 1, 0, 0, 0, 0]  // QDCOUNT, ANCOUNT, NSCOUNT, ARCOUNT

        // The question runs from the end of the header to the end of the query (no EDNS).
        response += query[12...]
        if !truncated {
            response += [0xc0, 0x0c]  // NAME: pointer to the question
            response += [0, 1, 0, 1]  // TYPE A, CLASS IN
            response += [0, 0, 0, 60]  // TTL
            response += [0, 4, 192, 0, 2, 7]  // RDLENGTH, RDATA (`answerAddress`)
        }
        return response
    }

    private static func check(_ result: Int32) throws {
        guard result == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    }
}

extension sockaddr_in {
    fileprivate init(host: String, port: UInt16) {
        self.init()
        self.sin_family = sa_family_t(AF_INET)
        self.sin_port = port.bigEndian
        self.sin_addr.s_addr = inet_addr(host)
    }
}

private func withSockaddr(
    _ address: inout sockaddr_in,
    _ body: (UnsafePointer<sockaddr>, socklen_t) -> Int32
) -> Int32 {
    withUnsafePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            body($0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
}
#endif
