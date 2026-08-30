// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "QuilNode",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "QuilNodeShared", targets: ["QuilNodeShared"]),
        .library(name: "QuilNodeCore", targets: ["QuilNodeCore"]),
        .library(name: "QuilNodeHelperKit", targets: ["QuilNodeHelperKit"]),
        .executable(name: "QuilNode", targets: ["QuilNodeApp"]),
        .executable(name: "QuilNodeHelper", targets: ["QuilNodeHelperCLI"]),
        .executable(name: "quilnode-probe", targets: ["QuilNodeProbe"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            exact: "2.9.6"
        )
    ],
    targets: [
        .target(name: "QuilNodeShared"),
        .target(name: "QuilNodeCore", dependencies: ["QuilNodeShared"]),
        .executableTarget(
            name: "QuilNodeApp",
            dependencies: [
                "QuilNodeCore",
                "QuilNodeShared",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .target(name: "QuilNodeHelperKit", dependencies: ["QuilNodeShared"]),
        .executableTarget(name: "QuilNodeHelperCLI", dependencies: ["QuilNodeHelperKit"]),
        .executableTarget(
            name: "QuilNodeProbe",
            dependencies: ["QuilNodeCore"]
        ),
        .testTarget(
            name: "QuilNodeCoreTests",
            dependencies: ["QuilNodeCore", "QuilNodeShared"]
        ),
        .testTarget(
            name: "QuilNodeAppTests",
            dependencies: ["QuilNodeApp", "QuilNodeCore", "QuilNodeShared"]
        ),
        .testTarget(name: "QuilNodeSharedTests", dependencies: ["QuilNodeShared"]),
        .testTarget(name: "QuilNodeHelperKitTests", dependencies: ["QuilNodeHelperKit", "QuilNodeShared"]),
    ]
)
