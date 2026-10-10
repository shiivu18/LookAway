// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LookAway",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LookAway", targets: ["LookAway"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "LookAway",
            dependencies: [],
            path: "Sources"
        )
    ]
)
