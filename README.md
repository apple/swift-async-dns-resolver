# Swift Asynchronous DNS Resolver

A Swift library for asynchronous DNS requests, wrapping [c-ares](https://github.com/c-ares/c-ares) with Swift-friendly APIs and data structures.

## Project status

This is the beginning of a community-driven open-source project actively seeking contributions, be it code, documentation, or ideas.

## Getting started

If you have a server-side Swift application or a cross-platform (e.g. Linux, macOS) application that needs DNS resolution, Swift Asynchronous DNS Resolver is a great idea. Below you will find all you need to know to get started.

### Adding the dependency

To add a dependency on the package, declare it in your `Package.swift`:

```swift
.package(url: "https://github.com/apple/swift-async-dns-resolver.git", from: "0.1.0"),
```

and to your application target, add `AsyncDNSResolver` to your dependencies:

```swift
.target(name: "MyApplication", dependencies: ["AsyncDNSResolver"]),
```

###  Using a DNS resolver

```swift
// import the package
import AsyncDNSResolver

// initialize the DNS resolver
let resolver = AsyncDNSResolver()

// run a query
self.resolver.query(.A(name: "apple.com") { result in
    switch result {
    case .success(let aRecords):
        // process the ARecords
    case .failure(let error):
        // process the error
    }
})
```

## Detailed design

The main types in the library are `AsyncDNSResolver`, `AsyncDNSResolver.Query`, and `AsyncDNSResolver.Options`.

`AsyncDNSResolver` uses the C-library [c-ares](https://github.com/c-ares/c-ares) underneath and delegates all queries to it.

`AsyncDNSResolver.Query` defines the supported DNS query types, while `AsyncDNSResolver.Options` provides different options for configuring `AsyncDNSResolver`.

The current implementation relies on a `DispatchQueue` to process queries asynchronously. An implementation that makes use of an event loop might be better. 

---

Do not hesitate to get in touch, over on https://forums.swift.org/c/server.
