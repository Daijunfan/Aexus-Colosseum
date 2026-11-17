// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AexusColosseum",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", exact: "1.99.3")
    ],
    targets: [
        .executableTarget(
            name: "AexusColosseum",
            dependencies: [.product(name: "SwiftTerm", package: "SwiftTerm")],
            path: "Sources/AexusColosseum",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "AexusColosseumTests",
            dependencies: ["AexusColosseum"],
            path: "Tests/AexusColosseumTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
