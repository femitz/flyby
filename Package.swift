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
        ),
        // Unit tests import the app target directly (`@testable import Flyby`), so the code
        // stays in one executable target. They cover logic only, never UI or system services.
        .testTarget(
            name: "FlybyTests",
            dependencies: ["Flyby"],
            path: "Tests/FlybyTests"
        )
    ]
)
