//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAsyncDNSResolver open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftAsyncDNSResolver project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAsyncDNSResolver project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AsyncDNSResolver
import XCTest

#if canImport(Darwin)
final class DNSDArraySliceTests: XCTestCase {
    func testReadUnsignedInteger() {
        // [UInt8(0), UInt16(.max), UInt32(0), UInt64(.max)]
        let bytes: [UInt8] = [0, 255, 255, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255]
        var slice = bytes[...]

        XCTAssertEqual(slice.readInteger(as: UInt8.self), 0)
        XCTAssertEqual(slice.readInteger(as: UInt16.self), .max)
        XCTAssertEqual(slice.readInteger(as: UInt32.self), 0)
        XCTAssertEqual(slice.readInteger(as: UInt64.self), .max)

        XCTAssertNil(slice.readInteger(as: UInt8.self))
    }

    func testReadSignedInteger() {
        // [Int8(0), Int16(-1), Int32(0), Int64(-1)]
        let bytes: [UInt8] = [0, 255, 255, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 255, 255]
        var slice = bytes[...]

        XCTAssertEqual(slice.readInteger(as: Int8.self), 0)
        XCTAssertEqual(slice.readInteger(as: Int16.self), -1)
        XCTAssertEqual(slice.readInteger(as: Int32.self), 0)
        XCTAssertEqual(slice.readInteger(as: Int64.self), -1)

        XCTAssertNil(slice.readInteger(as: Int8.self))
    }

    func testReadString() {
        let bytes = Array("hello, world!".utf8)
        var slice = bytes[...]

        XCTAssertEqual(slice.readString(length: 13), "hello, world!")
        XCTAssertEqual(slice.readString(length: 0), "")
        XCTAssertNil(slice.readString(length: 1))
    }
}
#endif
