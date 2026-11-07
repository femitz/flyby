// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Flyby",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Flyby",
            targets: ["Flyby"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Flyby",
            dependencies: [],
            path: "Sources/Flyby"
        )
    ]
)