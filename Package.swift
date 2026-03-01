// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MeshScale",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        // Executables
        .executableTarget(
            name: "MeshScaleCLI",
            dependencies: [
                "MeshScaleControlPlaneRuntime",
                "MeshScaleWorkerRuntime",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        
        .executableTarget(
            name: "MeshScaleControlPlane",
            dependencies: [
                "MeshScaleControlPlaneRuntime"
            ]
        ),
        
        .executableTarget(
            name: "MeshScaleWorker",
            dependencies: [
                "MeshScaleWorkerRuntime"
            ]
        ),
        
        // Libraries
        .target(
            name: "MeshScaleControlPlaneRuntime",
            dependencies: []
        ),
        
        .target(
            name: "MeshScaleWorkerRuntime",
            dependencies: []
        )
    ]
)
