// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "SwiftApp",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "SwiftApp",
            targets: ["SwiftApp"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SwiftApp",
            dependencies: [],
            path: "Sources/App"
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["SwiftApp"],
            path: "Tests/AppTests"
        )
    ]
)
