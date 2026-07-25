// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "RussianCorner",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "RussianCornerCore",
            targets: ["RussianCornerCore"]
        ),
        .library(
            name: "RussianCornerPlatform",
            targets: ["RussianCornerPlatform"]
        ),
    ],
    targets: [
        .target(
            name: "RussianCornerCore",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "RussianCornerPlatform",
            dependencies: ["RussianCornerCore"]
        ),
        .testTarget(
            name: "RussianCornerCoreTests",
            dependencies: ["RussianCornerCore"]
        ),
        .testTarget(
            name: "RussianCornerPlatformTests",
            dependencies: [
                "RussianCornerCore",
                "RussianCornerPlatform",
            ]
        ),
    ]
)
