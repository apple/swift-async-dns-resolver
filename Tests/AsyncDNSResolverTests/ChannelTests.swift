//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftAsyncDNSResolver open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftAsyncDNSResolver project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftAsyncDNSResolver project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import AsyncDNSResolver
import CAsyncDNSResolver
import XCTest

final class ChannelTests: XCTestCase {
    func test_AresChannel() {
        let options = AresOptions()

        let servers = ["[2001:4860:4860::8888]:53", "130.155.0.1:53"]
        options.setServers(servers)

        let sortlist = ["130.155.160.0/255.255.240.0", "130.155.0.0"]
        options.setSortlist(sortlist)

        guard let channel = try? AresChannel(options: options) else {
            return XCTFail("Channel not initialized")
        }
        XCTAssertNotNil(channel.pointer?.pointee)
    }
}
