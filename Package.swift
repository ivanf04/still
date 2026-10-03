// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusTimer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Still", targets: ["FocusTimer"])],
    targets: [
        .executableTarget(name: "FocusTimer")
    ]
)
