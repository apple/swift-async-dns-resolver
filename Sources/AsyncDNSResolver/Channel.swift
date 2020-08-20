import CAsyncDNSResolver
import Dispatch

// MARK: - ares_channel

class AresChannel {
    let pointer: UnsafeMutablePointer<ares_channel?>?

    private var _ares_channel: ares_channel? {
        self.pointer?.pointee
    }

    private let semaphore = DispatchSemaphore(value: 1)

    deinit {
        self.pointer?.deallocate()
        ares_destroy(self._ares_channel)
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

        self.pointer = pointer
    }

    func withChannel(_ body: (ares_channel) -> Void) {
        self.semaphore.wait()
        defer { self.semaphore.signal() }

        guard let _ares_channel = self._ares_channel else {
            fatalError("ares_channel not initialized")
        }

        body(_ares_channel)
    }
}

private func checkAresResult(body: () -> Int32) throws {
    let result = body()
    guard result == ARES_SUCCESS else {
        throw AsyncDNSResolver.Error(code: result, "Failed to initialize channel")
    }
}
