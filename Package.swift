// swift-tools-version:5.9

import PackageDescription

import class Foundation.FileManager

var caresExclude = [
    "./c-ares/src/lib/cares.rc",
    "./c-ares/src/lib/CMakeLists.txt",
    "./c-ares/src/lib/ares_config.h.cmake",
    "./c-ares/src/lib/Makefile.am",
    "./c-ares/src/lib/Makefile.inc",
]

do {
    if try !(FileManager.default.contentsOfDirectory(atPath: "./Sources/CAsyncDNSResolver/c-ares/CMakeFiles").isEmpty) {
        caresExclude.append("./c-ares/CMakeFiles/")
    }
} catch {
    // Assume CMakeFiles does not exist so no need to exclude it
}

let package = Package(
    name: "swift-async-dns-resolver",
    products: [
        .library(name: "AsyncDNSResolver", targets: ["AsyncDNSResolver"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CAsyncDNSResolver",
            dependencies: [],
            exclude: caresExclude,
            sources: ["./c-ares/src/lib"],
            cSettings: [
                .headerSearchPath("./c-ares/include"),
                .headerSearchPath("./c-ares/src/lib"),
                .define("HAVE_CONFIG_H", to: "1"),
            ]
        ),

        .target(
            name: "AsyncDNSResolver",
            dependencies: [
                "CAsyncDNSResolver"
            ]
        ),

        .testTarget(name: "AsyncDNSResolverTests", dependencies: ["AsyncDNSResolver"]),
    ],
    cLanguageStandard: .gnu11
)

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency=complete"))
    target.swiftSettings = settings
}
