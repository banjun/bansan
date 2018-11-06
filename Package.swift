// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "bansan",
    products: [
        .executable(name: "bansan", targets: ["bansan"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/SourceKitten", .upToNextMajor(from: "0.18.2")),
    ],
    targets: [
        .target(
            name: "bansan",
            dependencies: ["SourceKittenFramework"],
            path: ".",
            sources: ["main.swift"]),
    ]
)
