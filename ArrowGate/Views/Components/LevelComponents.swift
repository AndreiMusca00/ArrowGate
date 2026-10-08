import SwiftUI

/// Visual rules for level difficulty. Changing these values updates every
/// difficulty node on the Journey map from one place.
struct LevelDifficultyStyle {
    let color: Color?

    static func style(for difficulty: LevelDifficulty?) -> LevelDifficultyStyle {
        switch difficulty {
        case .hard:
            return LevelDifficultyStyle(
                color: Color(red: 0.84, green: 0.50, blue: 0.05)
            )
        case .veryHard:
            return LevelDifficultyStyle(
                color: Color(red: 0.50, green: 0.03, blue: 0.10)
            )
        case .nightmare:
            return LevelDifficultyStyle(
                color: Color(red: 0.19, green: 0.04, blue: 0.28)
            )
        default:
            return LevelDifficultyStyle(color: nil)
        }
    }
}

struct JourneyLevelNode: View {
    let level: LevelDefinition
    let chapterColor: Color
    let completed: Bool
    let current: Bool
    let locked: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var style: LevelDifficultyStyle { .style(for: level.difficulty) }
    private var emphasisColor: Color { style.color ?? chapterColor }
    private var nodeStroke: Color {
        if current { return emphasisColor }
        if completed { return chapterColor.opacity(0.42) }
        return style.color ?? Color(uiColor: GameStyle.guideDot).opacity(0.55)
    }
    private var nodeDiameter: CGFloat {
        if level.difficulty == .veryHard && !completed {
            return current ? 58 : 52
        }
        return current ? 68 : 58
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if current {
                    CurrentLevelPulse(color: emphasisColor, reduceMotion: reduceMotion)
                }

                if !completed {
                    LevelDifficultyAura(
                        difficulty: level.difficulty,
                        reduceMotion: reduceMotion
                    )
                }

                Circle()
                    .fill(locked ? Color.white.opacity(0.82) : Color.white)
                    .overlay(Circle().stroke(
                        nodeStroke,
                        lineWidth: current ? 4.5 : style.color == nil ? 2 : 3
                    ))
                    .shadow(
                        color: emphasisColor.opacity(completed || current ? 0.16 : 0.04),
                        radius: current ? 11 : 8,
                        y: 3
                    )
                    .frame(width: nodeDiameter, height: nodeDiameter)

                if completed {
                    LevelRewardView(level: level, size: 52)
                } else if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(style.color ?? GameStyle.muted.opacity(0.55))
                } else {
                    Text(String(level.id))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(emphasisColor)
                }
            }
            .frame(width: current ? 68 : 58, height: current ? 68 : 58)
            .overlay(alignment: .trailing) {
                if current {
                    Text("PLAY")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 88, height: 42)
                        .background(GameStyle.accent, in: Capsule())
                        .offset(x: 96)
                }
            }
        }
        .buttonStyle(JourneyLevelButtonStyle())
        .disabled(locked)
        .accessibilityLabel(
            "Level \(level.id), \(level.difficulty?.title ?? "Normal"), \(locked ? "locked" : completed ? "complete" : "current")"
        )
        .accessibilityIdentifier(current ? "mapPlay" : "mapLevel\(level.id)")
    }

}

/// Repeating waves begin at the edge of the current node and dissolve outward.
private struct CurrentLevelPulse: View {
    let color: Color
    let reduceMotion: Bool

    var body: some View {
        if reduceMotion {
            Circle()
                .stroke(color.opacity(0.24), lineWidth: 2)
                .scaleEffect(1.13)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        let raw = time / 1.8 + Double(index) / 3.0
                        let progress = raw - floor(raw)
                        Circle()
                            .stroke(
                                color.opacity(0.36 * (1 - progress)),
                                lineWidth: CGFloat(2.6 - progress)
                            )
                            .scaleEffect(1.02 + CGFloat(progress) * 0.58)
                    }
                }
            }
        }
    }
}

private struct JourneyLevelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

private struct LevelDifficultyAura: View {
    let difficulty: LevelDifficulty?
    let reduceMotion: Bool

    @ViewBuilder
    var body: some View {
        if difficulty == .hard || difficulty == .veryHard || difficulty == .nightmare {
            if reduceMotion {
                StaticDifficultyAura(difficulty: difficulty)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                    AnimatedDifficultyAura(
                        difficulty: difficulty,
                        time: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            }
        }
    }
}

private struct StaticDifficultyAura: View {
    let difficulty: LevelDifficulty?

    @ViewBuilder
    var body: some View {
        switch difficulty {
        case .hard:
            Circle()
                .stroke(Color(red: 0.96, green: 0.66, blue: 0.08), style: StrokeStyle(lineWidth: 2, dash: [3, 6]))
                .frame(width: 72, height: 72)
        case .veryHard:
            BloodFireAura(time: 0.35)
        case .nightmare:
            Circle()
                .stroke(Color(red: 0.30, green: 0.07, blue: 0.43), lineWidth: 4)
                .frame(width: 70, height: 70)
        default:
            EmptyView()
        }
    }
}

private struct AnimatedDifficultyAura: View {
    let difficulty: LevelDifficulty?
    let time: TimeInterval

    @ViewBuilder
    var body: some View {
        switch difficulty {
        case .hard:
            hardEnergy
        case .veryHard:
            bloodFlames
        case .nightmare:
            nightmareVortex
        default:
            EmptyView()
        }
    }

    private var hardEnergy: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [.clear, Color(red: 1.00, green: 0.78, blue: 0.16), .clear],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [8, 9])
                )
                .frame(width: 73, height: 73)
                .rotationEffect(.degrees(time * 42))

            ForEach(0..<4, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "bolt.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 9 : 7, weight: .bold))
                    .foregroundColor(Color(red: 0.94, green: 0.58, blue: 0.04))
                    .scaleEffect(0.82 + CGFloat(sin(time * 4 + Double(index))) * 0.12)
                    .offset(y: -39)
                    .rotationEffect(.degrees(Double(index) * 90 + time * 35))
            }
        }
    }

    private var bloodFlames: some View {
        BloodFireAura(time: time)
    }

    private var nightmareVortex: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 0.12, green: 0.01, blue: 0.18),
                            Color(red: 0.48, green: 0.12, blue: 0.62),
                            Color(red: 0.18, green: 0.02, blue: 0.28),
                            Color(red: 0.68, green: 0.20, blue: 0.78),
                            Color(red: 0.12, green: 0.01, blue: 0.18)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [15, 7])
                )
                .frame(width: 72, height: 72)
                .rotationEffect(.degrees(-time * 54))

            ForEach(0..<6, id: \.self) { index in
                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "diamond.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 9 : 5, weight: .bold))
                    .foregroundColor(
                        index.isMultiple(of: 2)
                            ? Color(red: 0.61, green: 0.23, blue: 0.73)
                            : Color(red: 0.24, green: 0.04, blue: 0.34)
                    )
                    .scaleEffect(0.72 + CGFloat(sin(time * 3.6 + Double(index))) * 0.18)
                    .offset(y: -41)
                    .rotationEffect(.degrees(Double(index) * 60 + time * 31))
            }
        }
    }
}

/// A fluid ring of fire attached directly to the level node. The flame begins
/// as a thin edge at the bottom and grows while its waves travel upward.
private struct BloodFireAura: View {
    let time: TimeInterval

    private let darkBlood = Color(red: 0.34, green: 0.005, blue: 0.045)
    private let blood = Color(red: 0.66, green: 0.025, blue: 0.09)
    private let hotBlood = Color(red: 0.93, green: 0.09, blue: 0.14)

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // The locked Very Hard node has a 26 pt radius and a 3 pt stroke.
            // Starting the crown at 26 pt lets the node cover its inner edge,
            // while the visible flame meets the outside of the stroke exactly.
            let radius: CGFloat = 27.5
            let crown = fireCrown(center: center, radius: radius)

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 6))
                glow.fill(crown, with: .color(blood.opacity(0.54)))
            }

            context.fill(
                crown,
                with: .linearGradient(
                    Gradient(colors: [hotBlood, blood, darkBlood]),
                    startPoint: CGPoint(x: center.x, y: center.y - radius - 20),
                    endPoint: CGPoint(x: center.x, y: center.y - radius + 9)
                )
            )
        }
        .frame(width: 112, height: 128)
        .accessibilityHidden(true)
    }

    private func fireCrown(center: CGPoint, radius: CGFloat) -> Path {
        let samples = 128
        var outer: [CGPoint] = []
        var inner: [CGPoint] = []

        for index in 0...samples {
            let fraction = Double(index) / Double(samples)
            let angle = fraction * Double.pi * 2
            let verticalProgress = (1 - sin(angle)) / 2
            let sidePhase = cos(angle) * 1.35
            let risingPhase = verticalProgress * 14 - time * 4.2
            let envelope = pow(verticalProgress, 0.82)
            let broadWave = 0.5 + 0.5 * sin(risingPhase + sidePhase)
            let fineWave = 0.5 + 0.5 * sin(
                verticalProgress * 27 - time * 7.0 - sidePhase * 1.7
            )
            let sharpTongue = pow(
                max(0, sin(verticalProgress * 22 - time * 4.8 + sidePhase)),
                8
            )
            let travellingFlare = pow(
                max(0, sin(verticalProgress * 11 - time * 3.1 - sidePhase)),
                6
            )
            let height = CGFloat(
                1.4 + envelope * (
                    3.2 + broadWave * 4.2 + fineWave * 1.6
                        + sharpTongue * 10 + travellingFlare * 4.5
                )
            )
            let radial = CGVector(dx: cos(angle), dy: sin(angle))

            outer.append(CGPoint(
                x: center.x + radial.dx * (radius + height),
                y: center.y + radial.dy * (radius + height)
            ))
            inner.append(CGPoint(
                x: center.x + radial.dx * (radius - 1.5),
                y: center.y + radial.dy * (radius - 1.5)
            ))
        }

        var path = Path()
        guard let first = outer.first else { return path }
        path.move(to: first)
        outer.dropFirst().forEach { path.addLine(to: $0) }
        inner.reversed().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }
}

struct LevelMilestoneBadge: View {
    let level: Int
    let reward: LevelCompletionReward
    let claimed: Bool

    private var icon: String { reward.kind == .life ? "heart.fill" : "lightbulb.fill" }
    private var color: Color { reward.kind == .life ? GameStyle.color(.red) : GameStyle.color(.yellow) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: claimed ? "checkmark.circle.fill" : icon)
                .foregroundColor(claimed ? GameStyle.accent : color)
            Text(claimed ? "CLAIMED" : "+\(reward.amount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(GameStyle.muted)
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(Color.white.opacity(0.90), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.16)))
        .accessibilityLabel("Level \(level) reward, \(claimed ? "claimed" : reward.kind.rawValue)")
    }
}

struct GalleryCollectibleCard: View {
    let level: LevelDefinition
    let collected: Bool

    var body: some View {
        VStack(spacing: 10) {
            if collected {
                LevelRewardView(level: level, size: 82)
            } else {
                ZStack {
                    Circle().fill(GameStyle.background).frame(width: 76, height: 76)
                    Image(systemName: "lock.fill").foregroundColor(GameStyle.muted.opacity(0.45))
                }
            }

            Text(collected ? (level.rewardName ?? "Collectible \(level.id)") : "Level \(level.id)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(collected ? GameStyle.ink : GameStyle.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.035)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            collected
                ? "\(level.rewardName ?? "Collectible \(level.id)"), collected"
                : "Level \(level.id), locked"
        )
    }
}
