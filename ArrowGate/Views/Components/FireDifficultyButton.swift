import Combine
import SpriteKit
import SwiftUI
import UIKit

/// A SwiftUI button with a lightweight SpriteKit fire treatment.
///
/// The button owns no game state. `isAnimating` lets a parent suspend the
/// particle scenes while the control is outside the visible interface.
struct FireDifficultyButton<Label: View>: View {
    let difficulty: LevelDifficulty
    let flameHeight: CGFloat?
    let flameIntensity: CGFloat?
    let sparkBirthRate: CGFloat?
    let glowIntensity: CGFloat?
    let pulseSpeed: Double?
    let isAnimating: Bool
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init(
        difficulty: LevelDifficulty,
        flameHeight: CGFloat? = nil,
        flameIntensity: CGFloat? = nil,
        sparkBirthRate: CGFloat? = nil,
        glowIntensity: CGFloat? = nil,
        pulseSpeed: Double? = nil,
        isAnimating: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.difficulty = difficulty
        self.flameHeight = flameHeight
        self.flameIntensity = flameIntensity
        self.sparkBirthRate = sparkBirthRate
        self.glowIntensity = glowIntensity
        self.pulseSpeed = pulseSpeed
        self.isAnimating = isAnimating
        self.action = action
        self.label = label
    }

    private var settings: FireDifficultySettings {
        FireDifficultySettings(
            difficulty: difficulty,
            flameHeight: flameHeight,
            flameIntensity: flameIntensity,
            sparkBirthRate: sparkBirthRate,
            glowIntensity: glowIntensity,
            pulseSpeed: pulseSpeed
        )
    }

    private var shouldAnimate: Bool {
        isAnimating && scenePhase == .active && !reduceMotion
    }

    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                ZStack {
                    FireParticleLayer(
                        layer: .flames,
                        settings: settings,
                        isAnimating: shouldAnimate
                    )

                    RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                        .fill(settings.backgroundGradient)
                        .overlay {
                            EmberSurface(
                                settings: settings,
                                isAnimating: shouldAnimate,
                                reduceMotion: reduceMotion
                            )
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: settings.cornerRadius,
                                    style: .continuous
                                )
                            )
                        }
                        .overlay {
                            FireGlowBorder(
                                settings: settings,
                                isAnimating: shouldAnimate,
                                reduceMotion: reduceMotion
                            )
                        }

                    FireParticleLayer(
                        layer: .sparks,
                        settings: settings,
                        isAnimating: shouldAnimate
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: settings.cornerRadius,
                            style: .continuous
                        )
                    )

                    label()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(maxWidth: .infinity)
            .frame(height: settings.buttonHeight)
            .contentShape(
                RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
            )
        }
        .buttonStyle(FireDifficultyPressStyle())
    }
}

private struct FireDifficultySettings: Equatable {
    let difficulty: LevelDifficulty
    let flameHeight: CGFloat
    let flameIntensity: CGFloat
    let sparkBirthRate: CGFloat
    let glowIntensity: CGFloat
    let pulseSpeed: Double

    let buttonHeight: CGFloat = 58
    let cornerRadius: CGFloat = 17

    init(
        difficulty: LevelDifficulty,
        flameHeight: CGFloat?,
        flameIntensity: CGFloat?,
        sparkBirthRate: CGFloat?,
        glowIntensity: CGFloat?,
        pulseSpeed: Double?
    ) {
        let preset = Self.preset(for: difficulty)
        self.difficulty = difficulty
        self.flameHeight = max(4, flameHeight ?? preset.flameHeight)
        self.flameIntensity = min(1.5, max(0, flameIntensity ?? preset.flameIntensity))
        self.sparkBirthRate = min(30, max(0, sparkBirthRate ?? preset.sparkBirthRate))
        self.glowIntensity = min(1.5, max(0, glowIntensity ?? preset.glowIntensity))
        self.pulseSpeed = min(5, max(0.2, pulseSpeed ?? preset.pulseSpeed))
    }

    private static func preset(for difficulty: LevelDifficulty) -> FireDifficultySettings {
        switch difficulty {
        case .veryHard:
            return FireDifficultySettings(
                rawDifficulty: difficulty,
                flameHeight: 22,
                flameIntensity: 1.0,
                sparkBirthRate: 18,
                glowIntensity: 1.0,
                pulseSpeed: 2.15
            )
        default:
            return FireDifficultySettings(
                rawDifficulty: difficulty,
                flameHeight: 13,
                flameIntensity: 0.58,
                sparkBirthRate: 8,
                glowIntensity: 0.55,
                pulseSpeed: 1.35
            )
        }
    }

    private init(
        rawDifficulty: LevelDifficulty,
        flameHeight: CGFloat,
        flameIntensity: CGFloat,
        sparkBirthRate: CGFloat,
        glowIntensity: CGFloat,
        pulseSpeed: Double
    ) {
        difficulty = rawDifficulty
        self.flameHeight = flameHeight
        self.flameIntensity = flameIntensity
        self.sparkBirthRate = sparkBirthRate
        self.glowIntensity = glowIntensity
        self.pulseSpeed = pulseSpeed
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: difficulty == .veryHard
                ? [
                    Color(red: 0.43, green: 0.055, blue: 0.015),
                    Color(red: 0.79, green: 0.19, blue: 0.015),
                    Color(red: 0.36, green: 0.025, blue: 0.01)
                ]
                : [
                    Color(red: 0.72, green: 0.25, blue: 0.015),
                    Color(red: 0.92, green: 0.43, blue: 0.025),
                    Color(red: 0.54, green: 0.12, blue: 0.01)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var hotColor: Color {
        difficulty == .veryHard
            ? Color(red: 1.0, green: 0.67, blue: 0.08)
            : Color(red: 1.0, green: 0.56, blue: 0.035)
    }
}

private struct FireDifficultyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

private enum FireParticleLayerKind {
    case flames
    case sparks
}

private struct FireParticleLayer: View {
    let layer: FireParticleLayerKind
    let settings: FireDifficultySettings
    let isAnimating: Bool

    @StateObject private var controller = FireParticleController()

    private var padding: CGFloat {
        layer == .flames ? settings.flameHeight + 12 : 0
    }

    var body: some View {
        GeometryReader { geometry in
            let buttonSize = geometry.size
            let sceneSize = CGSize(
                width: buttonSize.width + padding * 2,
                height: buttonSize.height + padding * 2
            )

            SpriteView(
                scene: controller.scene,
                preferredFramesPerSecond: 30,
                options: [.allowsTransparency]
            )
            .frame(width: sceneSize.width, height: sceneSize.height)
            .offset(x: -padding, y: -padding)
            .onAppear {
                controller.update(
                    layer: layer,
                    buttonSize: buttonSize,
                    padding: padding,
                    settings: settings,
                    isAnimating: isAnimating
                )
            }
            .onChange(of: buttonSize) { newSize in
                controller.update(
                    layer: layer,
                    buttonSize: newSize,
                    padding: padding,
                    settings: settings,
                    isAnimating: isAnimating
                )
            }
            .onChange(of: settings) { newSettings in
                controller.update(
                    layer: layer,
                    buttonSize: buttonSize,
                    padding: padding,
                    settings: newSettings,
                    isAnimating: isAnimating
                )
            }
            .onChange(of: isAnimating) { active in
                controller.setAnimating(active)
            }
            .onDisappear {
                controller.setAnimating(false)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private final class FireParticleController: ObservableObject {
    let scene = FireParticleScene()

    func update(
        layer: FireParticleLayerKind,
        buttonSize: CGSize,
        padding: CGFloat,
        settings: FireDifficultySettings,
        isAnimating: Bool
    ) {
        scene.configure(
            layer: layer,
            buttonSize: buttonSize,
            padding: padding,
            settings: settings
        )
        scene.isPaused = !isAnimating
    }

    func setAnimating(_ isAnimating: Bool) {
        scene.isPaused = !isAnimating
    }
}

private final class FireParticleScene: SKScene {
    private var signature: ConfigurationSignature?

    override init() {
        super.init(size: CGSize(width: 1, height: 1))
        scaleMode = .resizeFill
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        layer: FireParticleLayerKind,
        buttonSize: CGSize,
        padding: CGFloat,
        settings: FireDifficultySettings
    ) {
        guard buttonSize.width > 1, buttonSize.height > 1 else { return }
        let newSignature = ConfigurationSignature(
            layer: layer,
            buttonSize: buttonSize,
            padding: padding,
            settings: settings
        )
        guard signature != newSignature else { return }
        signature = newSignature

        size = CGSize(
            width: buttonSize.width + padding * 2,
            height: buttonSize.height + padding * 2
        )
        removeAllChildren()

        switch layer {
        case .flames:
            addFlameEmitters(buttonSize: buttonSize, padding: padding, settings: settings)
        case .sparks:
            addSparkEmitter(buttonSize: buttonSize, settings: settings)
        }
        let prewarmDuration = layer == .flames ? 0.32 : 0.18
        children
            .compactMap { $0 as? SKEmitterNode }
            .forEach { $0.advanceSimulationTime(prewarmDuration) }
    }

    private func addFlameEmitters(
        buttonSize: CGSize,
        padding: CGFloat,
        settings: FireDifficultySettings
    ) {
        let rect = CGRect(origin: CGPoint(x: padding, y: padding), size: buttonSize)
        let inset = settings.cornerRadius + 3
        let horizontalRange = max(0, rect.width - inset * 2)
        let verticalRange = max(0, rect.height - inset * 2)

        addChild(makeFlameEmitter(
            position: CGPoint(x: rect.midX, y: rect.maxY),
            positionRange: CGVector(dx: horizontalRange, dy: 0),
            angle: .pi / 2,
            weight: 0.42,
            settings: settings
        ))
        addChild(makeFlameEmitter(
            position: CGPoint(x: rect.midX, y: rect.minY),
            positionRange: CGVector(dx: horizontalRange, dy: 0),
            angle: -.pi / 2,
            weight: 0.20,
            settings: settings
        ))
        addChild(makeFlameEmitter(
            position: CGPoint(x: rect.minX, y: rect.midY),
            positionRange: CGVector(dx: 0, dy: verticalRange),
            angle: .pi * 0.82,
            weight: 0.19,
            settings: settings
        ))
        addChild(makeFlameEmitter(
            position: CGPoint(x: rect.maxX, y: rect.midY),
            positionRange: CGVector(dx: 0, dy: verticalRange),
            angle: .pi * 0.18,
            weight: 0.19,
            settings: settings
        ))
    }

    private func makeFlameEmitter(
        position: CGPoint,
        positionRange: CGVector,
        angle: CGFloat,
        weight: CGFloat,
        settings: FireDifficultySettings
    ) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.particlePositionRange = positionRange
        emitter.particleTexture = FireParticleTextures.flame
        emitter.particleBlendMode = .add
        emitter.particleBirthRate = 78 * settings.flameIntensity * weight
        emitter.particleLifetime = 0.42 + settings.flameHeight / 48
        emitter.particleLifetimeRange = emitter.particleLifetime * 0.32
        emitter.emissionAngle = angle
        emitter.emissionAngleRange = .pi * 0.22
        emitter.particleSpeed = settings.flameHeight * 1.32
        emitter.particleSpeedRange = settings.flameHeight * 0.72
        emitter.particleRotationRange = .pi
        emitter.particleScale = settings.difficulty == .veryHard ? 0.34 : 0.25
        emitter.particleScaleRange = settings.difficulty == .veryHard ? 0.18 : 0.12
        emitter.particleScaleSpeed = -0.18
        emitter.particleAlpha = 0.82
        emitter.particleAlphaRange = 0.16
        emitter.particleAlphaSpeed = -0.72
        emitter.yAcceleration = settings.difficulty == .veryHard ? 18 : 11
        emitter.particleColorBlendFactor = 1
        emitter.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor(red: 1.0, green: 0.88, blue: 0.25, alpha: 1),
                UIColor(red: 1.0, green: 0.38, blue: 0.025, alpha: 1),
                UIColor(red: 0.56, green: 0.045, blue: 0.008, alpha: 0)
            ],
            times: [0, 0.42, 1]
        )
        return emitter
    }

    private func addSparkEmitter(buttonSize: CGSize, settings: FireDifficultySettings) {
        let emitter = SKEmitterNode()
        emitter.position = CGPoint(x: buttonSize.width / 2, y: 7)
        emitter.particlePositionRange = CGVector(
            dx: max(0, buttonSize.width - 30),
            dy: max(0, buttonSize.height - 18)
        )
        emitter.particleTexture = FireParticleTextures.spark
        emitter.particleBlendMode = .add
        emitter.particleBirthRate = settings.sparkBirthRate
        emitter.particleLifetime = settings.difficulty == .veryHard ? 1.15 : 0.92
        emitter.particleLifetimeRange = 0.42
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi * 0.13
        emitter.particleSpeed = settings.difficulty == .veryHard ? 29 : 21
        emitter.particleSpeedRange = 16
        emitter.particleScale = settings.difficulty == .veryHard ? 0.21 : 0.15
        emitter.particleScaleRange = 0.10
        emitter.particleScaleSpeed = -0.09
        emitter.particleAlpha = 0.94
        emitter.particleAlphaRange = 0.12
        emitter.particleAlphaSpeed = -0.72
        emitter.particleColor = UIColor(red: 1.0, green: 0.76, blue: 0.18, alpha: 1)
        emitter.particleColorBlendFactor = 1
        addChild(emitter)
    }

    private struct ConfigurationSignature: Equatable {
        let layer: FireParticleLayerKind
        let buttonSize: CGSize
        let padding: CGFloat
        let settings: FireDifficultySettings
    }
}

private enum FireParticleTextures {
    static let flame: SKTexture = texture(size: CGSize(width: 22, height: 30), inset: 2)
    static let spark: SKTexture = texture(size: CGSize(width: 9, height: 16), inset: 1)

    private static func texture(size: CGSize, inset: CGFloat) -> SKTexture {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: rect)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }
}

private struct EmberSurface: View {
    let settings: FireDifficultySettings
    let isAnimating: Bool
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            embers(at: 0.4)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 18.0, paused: !isAnimating)) { timeline in
                embers(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func embers(at time: TimeInterval) -> some View {
        Canvas { context, size in
            let count = settings.difficulty == .veryHard ? 28 : 18
            for index in 0..<count {
                let seed = Double(index + 1)
                let x = pseudoRandom(seed * 12.9898) * size.width
                let y = pseudoRandom(seed * 78.233) * size.height
                let pulse = 0.5 + 0.5 * sin(time * settings.pulseSpeed + seed * 1.71)
                let radius = CGFloat(0.7 + pulse * (settings.difficulty == .veryHard ? 2.0 : 1.35))
                let opacity = (0.08 + pulse * 0.22) * settings.glowIntensity
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(settings.hotColor.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func pseudoRandom(_ value: Double) -> CGFloat {
        CGFloat(abs(sin(value) * 43_758.5453).truncatingRemainder(dividingBy: 1))
    }
}

private struct FireGlowBorder: View {
    let settings: FireDifficultySettings
    let isAnimating: Bool
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            border(at: 0.5)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 18.0, paused: !isAnimating)) { timeline in
                border(at: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func border(at time: TimeInterval) -> some View {
        let wave = 0.5 + 0.5 * sin(time * settings.pulseSpeed)
        let intensity = settings.glowIntensity * (0.58 + wave * 0.42)
        return RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.yellow.opacity(0.82 * intensity),
                        settings.hotColor.opacity(0.48 * intensity),
                        Color.orange.opacity(0.70 * intensity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: settings.difficulty == .veryHard ? 2.1 : 1.4
            )
            .shadow(
                color: settings.hotColor.opacity(0.38 * intensity),
                radius: settings.difficulty == .veryHard ? 13 : 8
            )
            .allowsHitTesting(false)
    }
}

/// Both presets shown together for tuning in Xcode without entering the game flow.
struct FireDifficultyButtonPrototype: View {
    var body: some View {
        VStack(spacing: 34) {
            FireDifficultyButton(difficulty: .hard, action: {}) {
                prototypeLabel(title: "Hard", level: 10)
            }
            FireDifficultyButton(difficulty: .veryHard, action: {}) {
                prototypeLabel(title: "Very Hard", level: 20)
            }
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GameStyle.background)
    }

    private func prototypeLabel(title: String, level: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                Text("Level \(level)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            Spacer()
            Image(systemName: "play.fill")
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
    }
}

#Preview("Fire Difficulty Buttons") {
    FireDifficultyButtonPrototype()
}
