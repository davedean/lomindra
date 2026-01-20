// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "VikunjaSyncLib",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "VikunjaSyncLib",
            targets: ["VikunjaSyncLib"]
        ),
        .executable(
            name: "mvp_sync",
            targets: ["mvp_sync"]
        )
    ],
    targets: [
        .target(
            name: "VikunjaSyncLib",
            dependencies: []
        ),
        .executableTarget(
            name: "mvp_sync",
            dependencies: ["VikunjaSyncLib"]
        ),
        .testTarget(
            name: "VikunjaSyncLibTests",
            dependencies: ["VikunjaSyncLib"]
        )
    ]
)
