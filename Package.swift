// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "CodexBar",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "CodexBar", targets: ["CodexBar"])
    ],
    targets: [
        .executableTarget(
            name: "CodexBar",
            path: "Sources"
        )
    ]
)
