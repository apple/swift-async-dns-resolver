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

#ifndef C_ASYNC_RESOLVER_H
#define C_ASYNC_RESOLVER_H

#if defined(_WIN32)
#include <winsock2.h> // socket types, hostent
#include <ws2tcpip.h> // inet_ntop, socklen_t, INET6_ADDRSTRLEN
// c-ares is linked statically into this module, so its public API must be
// declared without __declspec(dllimport). This must be visible everywhere
// ares.h is consumed, including from the Swift importer.
#define CARES_STATICLIB
#else
#include <arpa/inet.h> // inet_ntop
#include <netdb.h> // hostent
#endif

#include "ares_build.h"
#include "ares_config.h"
#include "../c-ares/include/ares.h"

#endif
