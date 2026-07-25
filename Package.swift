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
    ],
    targets: [
        .target(
            name: "RussianCornerCore",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "RussianCornerCoreTests",
            dependencies: ["RussianCornerCore"]
        ),
    ]
)
