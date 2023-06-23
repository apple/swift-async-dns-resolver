# ``AsyncDNSResolver``

A Swift library for asynchronous DNS queries.

## Overview

This library wraps around the [dnssd](https://developer.apple.com/documentation/dnssd) framework and 
the [c-ares](https://github.com/c-ares/c-ares) C library with Swift-friendly APIs and data structures.

## Usage

Add the package dependency in your `Package.swift`:

```swift
.package(
    url: "https://github.com/apple/swift-async-dns-resolver", 
    .upToNextMajor(from: "0.1.0")
),
```

Next, in your target, add `AsyncDNSResolver` to your dependencies:

```swift
.target(name: "MyTarget", dependencies: [
    .product(name: "AsyncDNSResolver", package: "swift-async-dns-resolver"),
],
```

###  Using the resolver

```swift
// import the package
import AsyncDNSResolver

// Initialize a resolver
let resolver = AsyncDNSResolver()

// Run a query
let aRecords = try await resolver.queryA(name: "apple.com")

// Process the `ARecord`s
...
```
