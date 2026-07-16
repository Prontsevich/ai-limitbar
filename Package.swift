// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AILimitBar",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "AILimitBar", targets: ["AILimitBar"]),
        .executable(name: "AILimitBarClaudeStatusLine", targets: ["AILimitBarClaudeStatusLine"]),
        .library(name: "AILimitBarCore", targets: ["AILimitBarCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.10.0")
    ],
    targets: [
        .executableTarget(
            name: "AILimitBar",
            dependencies: ["AILimitBarCore"],
            path: "Sources/AILimitBar",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "AILimitBarClaudeStatusLine",
            dependencies: ["AILimitBarCore"],
            path: "Sources/AILimitBarClaudeStatusLine"
        ),
        .target(
            name: "AILimitBarCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/AILimitBarCore"
        ),
        .testTarget(
            name: "AILimitBarCoreTests",
            dependencies: ["AILimitBarCore"],
            path: "Tests/AILimitBarCoreTests",
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "AILimitBarTests",
            dependencies: ["AILimitBar"],
            path: "Tests/AILimitBarTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
