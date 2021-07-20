// swift-tools-version:5.0

import class Foundation.FileManager
import PackageDescription

var caresExclude = [
    "./c-ares/acountry.c",
    "./c-ares/adig.c",
    "./c-ares/ahost.c",
    "./c-ares/ares_android.c",
    "./c-ares/windows_port.c",
    "./c-ares/test/",
]

do {
    if !(try FileManager.default.contentsOfDirectory(atPath: "./Sources/CAsyncDNSResolver/c-ares/CMakeFiles").isEmpty) {
        caresExclude.append("./c-ares/CMakeFiles/")
    }
} catch {
    // Assume CMakeFiles does not exist so no need to exclude it
}

let package = Package(
    name: "swift-async-dns-resolver",
    products: [
        .library(name: "AsyncDNSResolver", targets: ["AsyncDNSResolver"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "CAsyncDNSResolver", dependencies: [],
            exclude: caresExclude,
            sources: ["./c-ares"],
            cSettings: [
                .headerSearchPath("./c-ares"),
                .define("HAVE_CONFIG_H", to: "1"),
            ]
        ),
        .target(name: "AsyncDNSResolver", dependencies: ["CAsyncDNSResolver", "Logging"]),
        .testTarget(name: "AsyncDNSResolverTests", dependencies: ["AsyncDNSResolver"]),
    ],
    cLanguageStandard: .gnu11
)
