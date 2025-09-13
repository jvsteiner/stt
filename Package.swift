// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "stt",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .executable(
            name: "stt",
            targets: ["stt"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "stt",
            dependencies: [
                "FluidAudio",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        )
    ]
)
