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

#ifndef __CARES_BUILD_H
#define __CARES_BUILD_H

#define CARES_TYPEOF_ARES_SOCKLEN_T socklen_t
#define CARES_TYPEOF_ARES_SSIZE_T ssize_t

/* Prefix names with CARES_ to make sure they don't conflict with other config.h
 * files.  We need to include some dependent headers that may be system specific
 * for C-Ares */
#define CARES_HAVE_SYS_TYPES_H
#define CARES_HAVE_SYS_SOCKET_H
/* #undef CARES_HAVE_WINDOWS_H */
/* #undef CARES_HAVE_WS2TCPIP_H */
/* #undef CARES_HAVE_WINSOCK2_H */
/* #undef CARES_HAVE_WINDOWS_H */

#ifdef CARES_HAVE_SYS_TYPES_H
#  include <sys/types.h>
#endif

#ifdef CARES_HAVE_SYS_SOCKET_H
#  include <sys/socket.h>
#endif

#ifdef CARES_HAVE_WINSOCK2_H
#  include <winsock2.h>
#endif

#ifdef CARES_HAVE_WS2TCPIP_H
#  include <ws2tcpip.h>
#endif

#ifdef CARES_HAVE_WINDOWS_H
#  include <windows.h>
#endif


typedef CARES_TYPEOF_ARES_SOCKLEN_T ares_socklen_t;
typedef CARES_TYPEOF_ARES_SSIZE_T ares_ssize_t;

#endif /* __CARES_BUILD_H */
