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
        .library(
            name: "RussianCornerUI",
            targets: ["RussianCornerUI"]
        ),
        .executable(
            name: "RussianCornerApp",
            targets: ["RussianCornerApp"]
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
        .target(
            name: "RussianCornerUI",
            dependencies: [
                "RussianCornerCore",
                "RussianCornerPlatform",
            ]
        ),
        .executableTarget(
            name: "RussianCornerApp",
            dependencies: [
                "RussianCornerCore",
                "RussianCornerPlatform",
                "RussianCornerUI",
            ]
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
        .testTarget(
            name: "RussianCornerAppTests",
            dependencies: [
                "RussianCornerCore",
                "RussianCornerPlatform",
                "RussianCornerUI",
            ]
        ),
    ]
)
