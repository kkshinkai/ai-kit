// swift-tools-version: 6.0

import PackageDescription
import CompilerPluginSupport

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
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0")
    ],
    targets: [
        .target(
            name: "AIKit",
            dependencies: ["AIKitMacros"]
        ),
        .macro(
            name: "AIKitMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax")
            ]
        ),
        .executableTarget(
            name: "AIKitPlayground",
            dependencies: ["AIKit"]
        ),
        .testTarget(
            name: "AIKitTests",
            dependencies: [
                "AIKit",
                "AIKitMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        )
    ]
)
