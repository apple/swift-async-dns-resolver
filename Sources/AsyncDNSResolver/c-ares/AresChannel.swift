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
import Foundation

#if os(Windows)
import WinSDK
#endif

// MARK: - ares_channel

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class AresChannel: @unchecked Sendable {
    private let locked_pointer: UnsafeMutablePointer<ares_channel?>
    private let lock = NSLock()
    // Owned here so its lifetime exactly brackets the channel's: c-ares holds only an
    // unmanaged pointer to it (via `sock_state_cb_data`), and `ares_destroy` (in `deinit`)
    // may invoke the socket-state callback while closing sockets. Being a stored property,
    // it stays alive until after `deinit`'s body runs. `QueryProcessor` reads it to poll.
    let socketRegistry: SocketRegistry

    // For testing only.
    var underlying: ares_channel? {
        self.locked_pointer.pointee
    }

    deinit {
        // Safe to perform without the lock, as in deinit we know that no more
        // strong references to self exist, so nobody can be holding the lock.
        ares_destroy(locked_pointer.pointee)
        locked_pointer.deallocate()
        ares_library_cleanup()
    }

    init(options: AresOptions) throws {
        let socketRegistry = SocketRegistry()

        // c-ares invokes this whenever a socket is opened/closed or its read/write interest
        // changes. It must be registered on the options *before* `ares_init_options`, and being
        // `@convention(c)` it cannot capture context, so the registry is threaded through
        // `sock_state_cb_data` as an unmanaged pointer (kept valid by `self.socketRegistry`).
        let socketStateCallback: SocketStateCallback = { data, socket, readable, writable in
            guard let data = data else { return }
            let registry = Unmanaged<SocketRegistry>.fromOpaque(data).takeUnretainedValue()
            registry.update(socket: socket, readable: readable != 0, writable: writable != 0)
        }
        options.setSocketStateCallback(
            with: Unmanaged.passUnretained(socketRegistry).toOpaque(),
            socketStateCallback
        )

        // Initialize c-ares
        try checkAresResult { ares_library_init(ARES_LIB_INIT_ALL) }

        // Initialize channel with options
        let pointer = UnsafeMutablePointer<ares_channel?>.allocate(capacity: 1)
        try checkAresResult { ares_init_options(pointer, options.pointer, options.optionMasks) }

        // Additional options that require channel
        if let serversCSV = options.servers?.joined(separator: ",") {
            try checkAresResult { ares_set_servers_ports_csv(pointer.pointee, serversCSV) }
        }

        if let sortlist = options.sortlist?.joined(separator: " ") {
            try checkAresResult { ares_set_sortlist(pointer.pointee, sortlist) }
        }

        self.socketRegistry = socketRegistry
        self.locked_pointer = pointer
    }

    func withChannel(_ body: (ares_channel) -> Void) {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard let underlying = self.underlying else {
            fatalError("ares_channel not initialized")
        }
        body(underlying)
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
private func checkAresResult(body: () -> Int32) throws {
    let result = body()
    guard ares_status_t(result) == ARES_SUCCESS else {
        throw AsyncDNSResolver.Error(cAresCode: result, "failed to initialize channel")
    }
}

// MARK: - socket registry

/// Tracks the sockets c-ares is interested in, and their read/write interest, as
/// reported by the channel's `sock_state_cb`. Consumed by `Ares.QueryProcessor.poll()`
/// to drive `ares_process_fd`, replacing the deprecated `ares_getsock`.
final class SocketRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var locked_sockets: [Socket: (readable: Bool, writable: Bool)] = [:]

    func update(socket: Socket, readable: Bool, writable: Bool) {
        self.lock.lock()
        defer { self.lock.unlock() }
        if !readable, !writable {
            self.locked_sockets.removeValue(forKey: socket)
        } else {
            self.locked_sockets[socket] = (readable, writable)
        }
    }

    func snapshot() -> [(socket: Socket, readable: Bool, writable: Bool)] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.locked_sockets.map { (socket: $0.key, readable: $0.value.readable, writable: $0.value.writable) }
    }

    /// Asks the OS which of `sockets` are ready, without blocking, and returns those with
    /// `readable`/`writable` narrowed to what is actually ready.
    ///
    /// `sock_state_cb` only reports what c-ares is *interested* in. It must not be told about
    /// a socket before it's ready: c-ares takes a writable TCP socket to mean that `connect`
    /// finished and sends on it straight away. While the handshake is still in progress that
    /// `send` fails with `ENOTCONN` on Darwin, and c-ares gives up on the connection.
    static func readySockets(
        in sockets: [(socket: Socket, readable: Bool, writable: Bool)]
    ) -> [(socket: Socket, readable: Bool, writable: Bool)] {
        #if os(Windows)
        // On Windows `POLLIN` is a composite macro; `POLLRDNORM` covers data on a socket.
        let readEvent = CShort(POLLRDNORM)
        let writeEvent = CShort(POLLWRNORM)
        #else
        let readEvent = CShort(POLLIN)
        let writeEvent = CShort(POLLOUT)
        #endif
        // Reported whether or not they were requested. c-ares has to attempt the I/O it was
        // waiting for in order to find out what went wrong (e.g. a refused connection).
        let failureEvents = CShort(POLLERR) | CShort(POLLHUP)

        var descriptors = sockets.map { entry in
            pollfd(
                fd: entry.socket,
                events: (entry.readable ? readEvent : 0) | (entry.writable ? writeEvent : 0),
                revents: 0
            )
        }

        #if os(Windows)
        let result = WSAPoll(&descriptors, ULONG(descriptors.count), 0)
        #else
        let result = poll(&descriptors, nfds_t(descriptors.count), 0)
        #endif
        // On failure nothing is known to be ready; the next poll tries again.
        guard result > 0 else {
            return []
        }

        return zip(sockets, descriptors).compactMap { entry, descriptor in
            let readable = entry.readable && descriptor.revents & (readEvent | failureEvents) != 0
            let writable = entry.writable && descriptor.revents & (writeEvent | failureEvents) != 0
            return readable || writable ? (socket: entry.socket, readable: readable, writable: writable) : nil
        }
    }
}
