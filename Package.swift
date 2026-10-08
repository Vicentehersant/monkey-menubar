// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Monkey",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Monkey",
            path: "Sources/Monkey",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
