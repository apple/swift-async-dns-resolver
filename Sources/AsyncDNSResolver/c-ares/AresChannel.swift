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

// MARK: - ares_channel

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final class AresChannel: @unchecked Sendable {
    private let locked_pointer: UnsafeMutablePointer<ares_channel?>
    private let lock = NSLock()

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
    guard result == Int32(ARES_SUCCESS.rawValue) else {
        throw AsyncDNSResolver.Error(cAresCode: result, "failed to initialize channel")
    }
}
