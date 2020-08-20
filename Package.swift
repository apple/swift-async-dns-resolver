// swift-tools-version:5.0
import PackageDescription

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
            exclude: [
                "./c-ares/acountry.c",
                "./c-ares/adig.c",
                "./c-ares/ahost.c",
                "./c-ares/ares_android.c",
                "./c-ares/windows_port.c",
                "./c-ares/CMakeFiles/",
                "./c-ares/test/",
            ],
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
