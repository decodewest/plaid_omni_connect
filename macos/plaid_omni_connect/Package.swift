// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "plaid_omni_connect",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "plaid-omni-connect", targets: ["plaid_omni_connect"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "plaid_omni_connect",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
