// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RestBell",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "RestBell"),
        .testTarget(name: "RestBellTests", dependencies: ["RestBell"])
    ]
)
