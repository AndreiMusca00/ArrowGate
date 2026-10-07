import SwiftUI
import SpriteKit

struct PuzzleBoardView: UIViewRepresentable {
    let scene: GameScene
    let paused: Bool
    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.preferredFramesPerSecond = 60; view.ignoresSiblingOrder = true
        view.backgroundColor = GameStyle.sceneBackground
        view.presentScene(scene)
        return view
    }
    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
        scene.isPaused = paused
        view.isAccessibilityElement = !paused
        view.accessibilityValue = scene.accessibilitySummary
    }
    static func dismantleUIView(_ view: SKView, coordinator: ()) { view.presentScene(nil) }
}
