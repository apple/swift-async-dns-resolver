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

import Testing

@testable import AsyncDNSResolver

#if canImport(Darwin)

@Suite("DNSSDReplyHandlerTests")
struct DNSSDReplyHandlerTests {
    /// length == 0 means there is no rdata at all; the handler must throw.
    @Test
    func parseTXTZeroLengthShouldThrow() throws {
        let bytes: [UInt8] = [0]
        _ = bytes.withUnsafeBufferPointer { ptr in
            #expect(throws: (any Error).self) {
                try DNSSD.TXTQueryReplyHandler.instance.parseRecord(
                    data: ptr.baseAddress,
                    length: 0
                )
            }
        }
    }

    /// A well-formed single-string TXT record: one length-prefix byte
    /// followed by exactly that many ASCII bytes.
    @Test
    func parseTXTWellFormed() throws {
        let bytes: [UInt8] = [3, UInt8(ascii: "a"), UInt8(ascii: "b"), UInt8(ascii: "c")]
        try bytes.withUnsafeBufferPointer { buf in
            let record = try DNSSD.TXTQueryReplyHandler.instance.parseRecord(
                data: buf.baseAddress,
                length: UInt16(buf.count)
            )
            #expect(record?.txt == "abc")
        }
    }

    @Test
    func parseTXTLengthPrefixExceedsBufferShouldThrow() throws {
        // rdata: [10, 'a', 'b'] — prefix claims 10 bytes but only 2 follow
        let bytes: [UInt8] = [10, 97, 98]
        _ = bytes.withUnsafeBufferPointer { buf in
            #expect(throws: (any Error).self) {
                try DNSSD.TXTQueryReplyHandler.instance.parseRecord(
                    data: buf.baseAddress,
                    length: UInt16(buf.count)
                )
            }
        }
    }
}

#endif
