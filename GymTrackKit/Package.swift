// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "GymTrackKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "GymTrackKit", targets: ["GymTrackKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "GymTrackKit",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(
            name: "GymTrackKitTests",
            dependencies: ["GymTrackKit"]
        ),
    ]
)
