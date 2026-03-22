// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusTimer",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "FocusTimer",
            path: "Sources/FocusTimer",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
