// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AIKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AIKit",
            targets: ["AIKit"]
        ),
        .executable(
            name: "AIKitPlayground",
            targets: ["AIKitPlayground"]
        )
    ],
    targets: [
        .target(
            name: "AIKit"
        ),
        .executableTarget(
            name: "AIKitPlayground",
            dependencies: ["AIKit"]
        ),
        .testTarget(
            name: "AIKitTests",
            dependencies: ["AIKit"]
        )
    ]
)
