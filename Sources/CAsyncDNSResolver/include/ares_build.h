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

#ifdef _WIN32

/* On Windows the socket length type is a plain `int`, and the required system
 * headers (winsock2.h / ws2tcpip.h) are pulled in by ares_setup.h / the
 * CAsyncDNSResolver umbrella header, so we must not include the POSIX
 * <sys/socket.h> here. */
#define CARES_TYPEOF_ARES_SOCKLEN_T int

#ifdef _WIN64
#  define CARES_TYPEOF_ARES_SSIZE_T __int64
#else
#  define CARES_TYPEOF_ARES_SSIZE_T long
#endif

#else /* !_WIN32 */

#define CARES_TYPEOF_ARES_SOCKLEN_T socklen_t
#define CARES_TYPEOF_ARES_SSIZE_T ssize_t

/* Prefix names with CARES_ to make sure they don't conflict with other config.h
 * files.  We need to include some dependent headers that may be system specific
 * for C-Ares */
#define CARES_HAVE_SYS_TYPES_H
#define CARES_HAVE_SYS_SOCKET_H

#ifdef CARES_HAVE_SYS_TYPES_H
#  include <sys/types.h>
#endif

#ifdef CARES_HAVE_SYS_SOCKET_H
#  include <sys/socket.h>
#endif

#endif /* _WIN32 */


typedef CARES_TYPEOF_ARES_SOCKLEN_T ares_socklen_t;
typedef CARES_TYPEOF_ARES_SSIZE_T ares_ssize_t;

#endif /* __CARES_BUILD_H */
