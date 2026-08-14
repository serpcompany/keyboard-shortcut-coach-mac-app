// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeylumeClone",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "KeylumeClone", targets: ["KeylumeClone"])
    ],
    targets: [
        .executableTarget(
            name: "KeylumeClone",
            path: "Sources/KeylumeClone"
        ),
        .testTarget(
            name: "KeylumeCloneTests",
            dependencies: ["KeylumeClone"],
            path: "Tests/KeylumeCloneTests"
        )
    ]
)
