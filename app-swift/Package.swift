// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ShowreelStudio",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ShowreelKit", targets: ["ShowreelKit"])
    ],
    targets: [
        // Everything that does not need a window: tools, agent loop, project model, history, parsers.
        .target(name: "ShowreelKit", path: "Sources/ShowreelKit"),
        .executableTarget(name: "ShowreelStudio", dependencies: ["ShowreelKit"], path: "Sources/ShowreelStudio"),
        .testTarget(name: "ShowreelKitTests", dependencies: ["ShowreelKit"], path: "Tests/ShowreelKitTests"),
    ]
)
