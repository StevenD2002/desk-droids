// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeskDroids",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "DeskDroids", path: "Sources/DeskDroids"),
    ]
)
