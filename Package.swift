// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ArrowGateRules",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "PictarrowContentFixtures",
            path: "Backend/ContentSource",
            exclude: ["Artwork"],
            sources: ["ContentFixtureBundle.swift"],
            resources: [.copy("Levels")]
        ),
        .target(
            name: "ArrowGateRules",
            dependencies: ["PictarrowContentFixtures"],
            path: "ArrowGate",
            exclude: [
                "Assets.xcassets", "Views", "GameScene.swift", "GameViewModel.swift",
                "Info.plist", "LaunchScreen.storyboard", "ArrowGate.entitlements", "ArrowGateApp.swift", "AppState.swift",
                "Services/AudioHapticsManager.swift", "Services/FirebaseBootstrap.swift",
                "Services/FirebaseStorageContentTransport.swift", "Services/RemoteContentService.swift",
                "Services/ContentAssetRegistry.swift", "GoogleService-Info.plist"
            ],
            sources: [
                "Models/ArrowMotion.swift", "Models/MistakeTracker.swift", "Models/GameCatalog.swift", "Models/LevelDefinition.swift",
                "Models/PuzzleRules.swift", "Models/LevelRepository.swift", "Models/RemoteContentCatalog.swift",
                "Services/ProgressStore.swift", "Services/LocalDatabase.swift", "Services/ContentTransport.swift",
                "Services/ContentLifecycleManager.swift"
            ]
        ),
        .testTarget(name: "ArrowGateRulesTests", dependencies: ["ArrowGateRules"], path: "Tests")
    ]
)
