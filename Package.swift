// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Wormhole",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "Wormhole",
            targets: ["Wormhole"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Wormhole",
            dependencies: [],
            path: "Sources/Wormhole"
        ),
        .testTarget(
            name: "WormholeTests",
            dependencies: ["Wormhole"],
            path: "Tests/WormholeTests"
        )
    ]
)
