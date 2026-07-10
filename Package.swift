// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AILimitBar",
    platforms: [
        .macOS(.v26)
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
        ),
        .testTarget(
            name: "AILimitBarTests",
            dependencies: ["AILimitBar"],
            path: "Tests/AILimitBarTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
