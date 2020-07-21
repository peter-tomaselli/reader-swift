// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "Reader",
    products: [
        .library(
            name: "Reader",
            targets: ["Reader"]
        ),
    ],
    dependencies: [
        .package(
            name: "Prelude",
            url: "https://github.com/peter-tomaselli/prelude",
            .branch("master")
        )
    ],
    targets: [
        .target(
            name: "Reader",
            dependencies: ["Prelude"]
        ),
        .testTarget(
            name: "ReaderTests",
            dependencies: ["Reader"]
        ),
    ]
)
