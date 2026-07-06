// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AILimitBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AILimitBar", targets: ["AILimitBar"]),
        .library(name: "AILimitBarCore", targets: ["AILimitBarCore"])
    ],
    targets: [
        .executableTarget(
            name: "AILimitBar",
            dependencies: ["AILimitBarCore"],
            path: "Sources/AILimitBar"
        ),
        .target(
            name: "AILimitBarCore",
            path: "Sources/AILimitBarCore"
        ),
        .testTarget(
            name: "AILimitBarCoreTests",
            dependencies: ["AILimitBarCore"],
            path: "Tests/AILimitBarCoreTests"
        )
    ]
)
