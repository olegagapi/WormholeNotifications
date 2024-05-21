// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "MMWormhole",
    platforms: [
        .iOS(.v9),
        .macOS(.v10_10),
        .watchOS(.v2)
    ],
    products: [
        .library(
            name: "MMWormhole",
            targets: ["MMWormhole"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MMWormhole",
            dependencies: [],
            path: "Source",
            publicHeadersPath: "."
        )
    ]
)