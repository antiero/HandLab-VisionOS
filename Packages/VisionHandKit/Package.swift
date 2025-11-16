// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VisionHandKit",
    platforms: [
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "VisionHandKit",
            targets: ["VisionHandKit"]
        )
    ],
    targets: [
        .target(
            name: "VisionHandKit",
            dependencies: [],
            path: "Sources/VisionHandKit"
        )
    ]
)
