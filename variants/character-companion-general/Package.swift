// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CharacterCompanion",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CharacterCompanion", targets: ["Companion"])
    ],
    targets: [
        .executableTarget(
            name: "Companion",
            resources: [
                .copy("Assets/EfficiencyIsland"),
                .copy("Assets/Tracker")
            ]
        )
    ]
)
