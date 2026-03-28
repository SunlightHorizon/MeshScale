// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MeshScale",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MeshScaleControlPlaneRuntime",
            targets: ["MeshScaleControlPlaneRuntime"]
        ),
        .library(
            name: "MeshScaleStore",
            targets: ["MeshScaleStore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.1"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.21.1"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.6.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.10.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.97.1")
    ],
    targets: [
        // Executables
        .executableTarget(
            name: "MeshScaleCLI",
            dependencies: [
                "MeshScaleControlPlaneRuntime",
                "MeshScaleWorkerRuntime",
                "MeshScaleStore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "/usr/local/lib"], .when(platforms: [.macOS]))
            ]
        ),
        
        .executableTarget(
            name: "MeshScaleControlPlane",
            dependencies: [
                "MeshScaleControlPlaneRuntime",
                "MeshScaleWorkerRuntime",
                "MeshScaleStore",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
                .product(name: "NIOCore", package: "swift-nio")
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "/usr/local/lib"], .when(platforms: [.macOS]))
            ]
        ),
        
        .executableTarget(
            name: "MeshScaleWorker",
            dependencies: [
                "MeshScaleWorkerRuntime",
                "MeshScaleStore"
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "/usr/local/lib"], .when(platforms: [.macOS]))
            ]
        ),
        
        // Libraries
        .target(
            name: "CFoundationDBShim",
            dependencies: [],
            path: "Sources/CFoundationDBShim",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("fdb_c")
            ]
        ),

        .target(
            name: "MeshScaleStore",
            dependencies: ["CFoundationDBShim"]
        ),
        
        .target(
            name: "MeshScaleControlPlaneRuntime",
            dependencies: ["MeshScaleStore"]
        ),
        
        .target(
            name: "MeshScaleWorkerRuntime",
            dependencies: ["MeshScaleStore"]
        )
    ]
)
