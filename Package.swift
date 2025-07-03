// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9)],
    products: [
        .library(
            name: "Arch",
            targets: ["Arch"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Arch",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "ArchTests",
            dependencies: ["Arch"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
    ]
) 