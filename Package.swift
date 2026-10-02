// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyeBreak",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "EyeBreak", targets: ["EyeBreak"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "EyeBreak",
            dependencies: [],
            path: "Sources"
        )
    ]
)
