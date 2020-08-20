@testable import AsyncDNSResolver
import CAsyncDNSResolver
import XCTest

final class OptionsTests: XCTestCase {
    private typealias Options = AsyncDNSResolver.Options
    private typealias Flags = AsyncDNSResolver.Options.Flags

    func test_Flags() {
        let flags: Flags = [.NOALIASES, .IGNTC, .NOSEARCH]
        let expected = Flags.NOALIASES.rawValue | Flags.IGNTC.rawValue | Flags.NOSEARCH.rawValue
        XCTAssertEqual(flags.rawValue, expected, "Expected value to be \(expected), got \(flags.rawValue)")
        XCTAssertTrue(flags.contains(.IGNTC))
        XCTAssertFalse(flags.contains(.NORECURSE))
    }

    func test_OptionsToAresOptions() {
        var options = Options()
        options.flags = .STAYOPEN
        options.timeoutMillis = 200
        options.attempts = 3
        options.numberOfDots = 7
        options.udpPort = 59
        options.tcpPort = 95
        options.socketSendBufferSize = 1024
        options.socketReceiveBufferSize = 2048
        options.ednsPacketSize = 512
        options.resolvConfPath = "/foo/bar"
        options.lookups = "bf"
        options.domains = ["foo", "bar", "baz"]
        options.servers = ["dns-one.local", "dns-two.local"]
        options.sortlist = ["130.155.160.0/255.255.240.0", "130.155.0.0"]

        // Verify `ares_options`
        let aresOptions = options.aresOptions

        self.assertKeyPathValue(options: aresOptions, keyPath: \.flags, expected: options.flags.rawValue)
        self.ensureOptionMaskSet(aresOptions, .FLAGS)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.timeout, expected: options.timeoutMillis)
        self.ensureOptionMaskSet(aresOptions, .TIMEOUT)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.tries, expected: options.attempts)
        self.ensureOptionMaskSet(aresOptions, .TRIES)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.ndots, expected: options.numberOfDots)
        self.ensureOptionMaskSet(aresOptions, .NDOTS)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.udp_port, expected: options.udpPort)
        self.ensureOptionMaskSet(aresOptions, .UDP_PORT)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.tcp_port, expected: options.tcpPort)
        self.ensureOptionMaskSet(aresOptions, .TCP_PORT)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.socket_send_buffer_size, expected: options.socketSendBufferSize!)
        self.ensureOptionMaskSet(aresOptions, .SOCK_SNDBUF)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.socket_receive_buffer_size, expected: options.socketReceiveBufferSize!)
        self.ensureOptionMaskSet(aresOptions, .SOCK_RCVBUF)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.ednspsz, expected: options.ednsPacketSize!)
        self.ensureOptionMaskSet(aresOptions, .EDNSPSZ)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.resolvconf_path, expected: options.resolvConfPath!)
        self.ensureOptionMaskSet(aresOptions, .RESOLVCONF)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.lookups, expected: options.lookups!)
        self.ensureOptionMaskSet(aresOptions, .LOOKUPS)

        self.assertKeyPathValue(options: aresOptions, keyPath: \.domains, expected: options.domains!)
        self.assertKeyPathValue(options: aresOptions, keyPath: \.ndomains, expected: CInt(options.domains!.count))
        self.ensureOptionMaskSet(aresOptions, .DOMAINS)

        XCTAssertNotNil(aresOptions.servers)
        XCTAssertEqual(aresOptions.servers, options.servers, "Expected servers to be \(options.servers!), got \(aresOptions.servers!)")

        XCTAssertNotNil(aresOptions.sortlist)
        XCTAssertEqual(aresOptions.sortlist, options.sortlist, "Expected sortList to be \(options.sortlist!), got \(aresOptions.sortlist!)")
    }

    func test_Options_rotateNotSet() {
        var options = Options()
        options.rotate = nil

        let aresOptions = options.aresOptions
        XCTAssertFalse(aresOptions._optionMasks.contains(.ROTATE))
        XCTAssertFalse(aresOptions._optionMasks.contains(.NOROTATE))
    }

    func test_Options_rotateTrue() {
        var options = Options()
        options.rotate = true

        let aresOptions = options.aresOptions
        XCTAssertTrue(aresOptions._optionMasks.contains(.ROTATE))
        XCTAssertFalse(aresOptions._optionMasks.contains(.NOROTATE))
    }

    func test_Options_rotateFalse() {
        var options = Options()
        options.rotate = false

        let aresOptions = options.aresOptions
        XCTAssertFalse(aresOptions._optionMasks.contains(.ROTATE))
        XCTAssertTrue(aresOptions._optionMasks.contains(.NOROTATE))
    }

    func test_AresOptions_socketStateCallback() {
        let options = AresOptions()

        let dataPointer = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
        defer { dataPointer.deallocate() }

        options.setSocketStateCallback(with: dataPointer) { _, _, _, _ in }
        XCTAssertNotNil(options._ares_options.sock_state_cb, "Expected sock_state_cb to be non nil")
        XCTAssertNotNil(options._ares_options.sock_state_cb_data, "Expected sock_state_cb_data to be non nil")
        self.ensureOptionMaskSet(options, .SOCK_STATE_CB)
    }

    private func assertKeyPathValue<T>(options: AresOptions, keyPath: KeyPath<ares_options, T>, expected: T) where T: Equatable {
        let actual = options._ares_options[keyPath: keyPath]
        XCTAssertEqual(actual, expected, "Expected \(keyPath) to be \(expected), got \(actual)")
    }

    private func assertKeyPathValue(options: AresOptions, keyPath: KeyPath<ares_options, UnsafeMutablePointer<CChar>?>, expected: String) {
        let actualPointer = options._ares_options[keyPath: keyPath]
        XCTAssertNotNil(actualPointer, "Expected \(keyPath) to be non nil")
        let actual = String(cString: actualPointer!) // !-safe since we check for nil
        XCTAssertEqual(actual, expected, "Expected \(keyPath) to be \(expected), got \(actual)")
    }

    private func assertKeyPathValue(options: AresOptions, keyPath: KeyPath<ares_options, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>, expected: [String]) {
        let actualPointer = options._ares_options[keyPath: keyPath]
        XCTAssertNotNil(actualPointer, "Expected \(keyPath) to be non nil")
        let actual = Array(UnsafeBufferPointer(start: actualPointer!, count: expected.count))
            .map { $0.map { String(cString: $0) } }
        XCTAssertEqual(actual, expected, "Expected \(keyPath) to be \(expected), got \(actual)")
    }

    private func ensureOptionMaskSet(_ options: AresOptions, _ mask: AresOptionMasks) {
        XCTAssertTrue(options._optionMasks.contains(mask), "Expected \(mask) to be set")
    }
}
