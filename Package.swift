// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17), .watchOS(.v10)],
    products: [
        .library(
            name: "Arch",
            targets: ["Arch"]
        ),
        .library(
            name: "ArchAsync",
            targets: ["ArchAsync"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Arch",
            exclude: ["Docs"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "ArchTests",
            dependencies: ["Arch"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .target(
            name: "ArchAsync",
            exclude: ["Docs"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "ArchAsyncTests",
            dependencies: ["ArchAsync"],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
    ]
) 