// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SPTPersistentCache",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_13),
        .tvOS(.v13),
        .watchOS(.v4),
    ],
    products: [
        .library(name: "SPTPersistentCache", targets: ["SPTPersistentCache"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SPTPersistentCache",
            path: "Sources",
            cSettings: []
        ),
        .testTarget(
            name: "SPTPersistentCacheTests",
            dependencies: ["SPTPersistentCache"],
            path: "Tests",
            resources: [.process("Resources")],
            cSettings: [.headerSearchPath("../Sources")]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
