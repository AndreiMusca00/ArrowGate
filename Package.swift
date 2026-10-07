// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ArrowGateRules",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "ArrowGateRules",
            path: "ArrowGate",
            exclude: [
                "Assets.xcassets", "Views", "GameScene.swift", "GameViewModel.swift",
                "Info.plist", "ArrowGateApp.swift", "AppState.swift", "Services/AudioHapticsManager.swift"
            ],
            sources: [
                "Models/ArrowMotion.swift", "Models/MistakeTracker.swift", "Models/LevelDefinition.swift",
                "Models/PuzzleRules.swift", "Models/LevelRepository.swift",
                "Services/ProgressStore.swift", "Services/LocalDatabase.swift"
            ],
            resources: [.copy("Levels/levels.json")]
        ),
        .testTarget(name: "ArrowGateRulesTests", dependencies: ["ArrowGateRules"], path: "Tests")
    ]
)
