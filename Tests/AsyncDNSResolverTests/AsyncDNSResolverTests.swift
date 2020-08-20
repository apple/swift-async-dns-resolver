@testable import AsyncDNSResolver
import CAsyncDNSResolver
import Dispatch
import XCTest

final class AsyncDNSResolverTests: XCTestCase {
    var resolver: AsyncDNSResolver!

    override func setUp() {
        super.setUp()

//        var options = AsyncDNSResolver.Options()
//        options.servers = ["8.8.8.8"]
//        self.resolver = try! AsyncDNSResolver(options: options)
        self.resolver = try! AsyncDNSResolver()
    }

    override func tearDown() {
        super.tearDown()

        self.resolver = nil // FIXME: for tsan
    }

    func test_queryA() throws {
        self.resolver.query(.A(name: "apple.com") { result in
            switch result {
            case .success(let r):
                print("A records: \(r)")
            case .failure(let error):
                print("Error: \(error)")
            }
        })

        self.untilFinishOrTimeout(timeout: .seconds(3))
    }

    func test_queryAAAA() throws {
        self.resolver.query(.AAAA(name: "google.com") { result in
            switch result {
            case .success(let r):
                print("AAAA records: \(r)")
            case .failure(let error):
                print("Error: \(error)")
            }
        })

        self.untilFinishOrTimeout(timeout: .seconds(3))
    }

    func test_queryNS() throws {
        self.resolver.query(.NS(name: "apple.com") { result in
            switch result {
            case .success(let r):
                print("NS records: \(r)")
            case .failure(let error):
                print("Error: \(error)")
            }
        })

        self.untilFinishOrTimeout(timeout: .seconds(3))
    }

    func test_queryCNAME() throws {
        self.resolver.query(.CNAME(name: "www.apple.com") { result in
            switch result {
            case .success(let r):
                print("CNAME record: \(r)")
            case .failure(let error):
                print("Error: \(error)")
            }
        })

        self.untilFinishOrTimeout(timeout: .seconds(3))
    }

    func test_querySOA() throws {
        self.resolver.query(.SOA(name: "apple.com") { result in
            switch result {
            case .success(let r):
                print("SOA records: \(r)")
            case .failure(let error):
                print("Error: \(error)")
            }
        })

        self.untilFinishOrTimeout(timeout: .seconds(3))
    }

    func test_queryPTR() throws {
        self.resolver.query(.PTR(name: "47.224.172.17.in-addr.arpa") { result in
            switch result {
            case .success(let r):
                print("PTR records: \(r)")
            case .failure(let error):
                print("Error: \(error)")
            }
        })

        self.untilFinishOrTimeout(timeout: .seconds(3))
    }

    func test_queryMX() throws {
        self.resolver.query(.MX(name: "apple.com") { result in
            switch result {
            case .success(let r):
                print("MX records: \(r)")
            case .failure(let error):
                print("Error: \(error)")
            }
        })

        self.untilFinishOrTimeout(timeout: .seconds(3))
    }

    func test_queryTXT() throws {
        self.resolver.query(.TXT(name: "apple.com") { result in
            switch result {
            case .success(let r):
                print("TXT records: \(r)")
            case .failure(let error):
                print("Error: \(error)")
            }
        })

        self.untilFinishOrTimeout(timeout: .seconds(3))
    }

    func test_querySRV() throws {
        self.resolver.query(.SRV(name: "_caldavs._tcp.google.com") { result in
            switch result {
            case .success(let r):
                print("SRV records: \(r)")
            case .failure(let e):
                print("Error: \(e)")
            }
        })

        self.untilFinishOrTimeout(timeout: .seconds(3))
    }

    func test_queryNAPTR() throws {
        self.resolver.query(.NAPTR(name: "apple.com") { result in
            switch result {
            case .success(let r):
                print("NAPTR records: \(r)")
            case .failure(let e):
                print("Error: \(e)")
            }
        })

        self.untilFinishOrTimeout(timeout: .seconds(3))
    }

    func test_concurrency() throws {
        func run(times: Int = 100, timeout: DispatchTimeInterval = .seconds(5), _ query: (_ index: Int) -> Void) {
            for i in 1 ... times {
                query(i)
            }
            self.untilFinishOrTimeout(timeout: timeout)
        }

        run { i in
            self.resolver.query(.A(name: "apple.com") { result in
                print("[A] Run #\(i) result: \(result)")
            })
        }
        run { i in
            self.resolver.query(.AAAA(name: "google.com") { result in
                print("[AAAA] Run #\(i) result: \(result)")
            })
        }
        run { i in
            self.resolver.query(.NS(name: "apple.com") { result in
                print("[NS] Run #\(i) result: \(result)")
            })
        }
        run { i in
            self.resolver.query(.CNAME(name: "www.apple.com") { result in
                print("[CNAME] Run #\(i) result: \(result)")
            })
        }
        run { i in
            self.resolver.query(.SOA(name: "apple.com") { result in
                print("[SOA] Run #\(i) result: \(result)")
            })
        }
        run { i in
            self.resolver.query(.PTR(name: "47.224.172.17.in-addr.arpa") { result in
                print("[PTR] Run #\(i) result: \(result)")
            })
        }
        run { i in
            self.resolver.query(.MX(name: "apple.com") { result in
                print("[MX] Run #\(i) result: \(result)")
            })
        }
        run { i in
            self.resolver.query(.TXT(name: "apple.com") { result in
                print("[TXT] Run #\(i) result: \(result)")
            })
        }
        run { i in
            self.resolver.query(.SRV(name: "_caldavs._tcp.google.com") { result in
                print("[SRV] Run #\(i) result: \(result)")
            })
        }
        run { i in
            self.resolver.query(.NAPTR(name: "apple.com") { result in
                print("[NAPTR] Run #\(i) result: \(result)")
            })
        }
    }

    /// Waits until channel has no more pending queries or times out.
    ///
    /// - SeeAlso: // https://c-ares.haxx.se/ares_process.html
    private func untilFinishOrTimeout(timeout: DispatchTimeInterval) {
        let read = UnsafeMutablePointer<fd_set>.allocate(capacity: 1)
        let write = UnsafeMutablePointer<fd_set>.allocate(capacity: 1)
        defer {
            read.deallocate()
            write.deallocate()
        }

        let start = DispatchTime.now()
        let deadline = start + timeout
        var done = false

        while !done {
            if DispatchTime.now() >= deadline {
                return XCTFail("Query timed out")
            }

            // Allow some time for query to start
            usleep(100_000)

            read.pointee = fd_set()
            write.pointee = fd_set()

            self.resolver.ares.channel.withChannel { channel in
                if ares_fds(channel, read, write) == 0 {
                    done = true
                    return
                }
                // No need to "poke" ares because we have QueryProcessor
                // ares_process(channel, read, write)
            }
        }
    }
}
