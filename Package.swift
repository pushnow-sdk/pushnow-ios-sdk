// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// PushFly — the official iOS companion SDK for the PushFly push notification
// service. See README.md for usage.

import PackageDescription

let package = Package(
    name: "PushFly",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PushFly",
            targets: ["PushFly"]
        )
    ],
    targets: [
        .target(
            name: "PushFly",
            path: "Sources/PushFly"
        ),
        .testTarget(
            name: "PushFlyTests",
            dependencies: ["PushFly"],
            path: "Tests/PushFlyTests"
        )
    ]
)
