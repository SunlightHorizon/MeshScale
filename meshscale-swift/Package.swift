// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MeshScale",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "1.8.0")
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
            ]
        ),
        
        .executableTarget(
            name: "MeshScaleControlPlane",
            dependencies: [
                "MeshScaleControlPlaneRuntime",
                "MeshScaleStore",
                .product(name: "Hummingbird", package: "hummingbird")
            ]
        ),
        
        .executableTarget(
            name: "MeshScaleWorker",
            dependencies: [
                "MeshScaleWorkerRuntime",
                "MeshScaleStore"
            ]
        ),
        
        // Libraries
        .target(
            name: "MeshScaleStore",
            dependencies: []
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
