// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacGlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacGlowCore", targets: ["MacGlowCore"]),
        .executable(name: "MacGlowApp", targets: ["MacGlowApp"]),
        .executable(name: "MacGlowBenchmark", targets: ["MacGlowBenchmark"])
    ],
    targets: [
        .target(name: "MacGlowCore"),
        .executableTarget(
            name: "MacGlowApp",
            dependencies: ["MacGlowCore"]
        ),
        .executableTarget(
            name: "MacGlowBenchmark",
            dependencies: ["MacGlowCore"]
        ),
        .testTarget(
            name: "MacGlowCoreTests",
            dependencies: ["MacGlowCore"]
        )
    ]
)
