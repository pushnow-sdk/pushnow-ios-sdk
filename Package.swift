// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// PushNow — the official iOS companion SDK for the PushNow push notification
// service. See README.md for usage.

import PackageDescription

let package = Package(
    name: "PushNow",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PushNow",
            targets: ["PushNow"]
        )
    ],
    targets: [
        .target(
            name: "PushNow",
            path: "Sources/PushNow"
        ),
        .testTarget(
            name: "PushNowTests",
            dependencies: ["PushNow"],
            path: "Tests/PushNowTests"
        )
    ]
)
