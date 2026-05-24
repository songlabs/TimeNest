// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TimeNest",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "TimeNest",
            targets: ["TimeNest"]
        ),
    ],
    targets: [
        .target(
            name: "TimeNest",
            path: "TimeNest",
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
