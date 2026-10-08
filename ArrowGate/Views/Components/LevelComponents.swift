import SwiftUI

/// Visual rules for level difficulty. Changing these values updates every
/// difficulty node on the Journey map from one place.
struct LevelDifficultyStyle {
    let color: Color?
    let label: String?

    static func style(for difficulty: LevelDifficulty?) -> LevelDifficultyStyle {
        switch difficulty {
        case .hard:
            return LevelDifficultyStyle(
                color: Color(red: 0.91, green: 0.38, blue: 0.07),
                label: "HARD"
            )
        case .veryHard:
            return LevelDifficultyStyle(
                color: Color(red: 0.51, green: 0.24, blue: 0.75),
                label: "VERY HARD"
            )
        case .nightmare:
            return LevelDifficultyStyle(
                color: Color(red: 0.30, green: 0.06, blue: 0.30),
                label: "NIGHTMARE"
            )
        default:
            return LevelDifficultyStyle(color: nil, label: nil)
        }
    }
}

struct JourneyLevelNode: View {
    let level: LevelDefinition
    let completed: Bool
    let current: Bool
    let locked: Bool
    let action: () -> Void

    private var style: LevelDifficultyStyle { .style(for: level.difficulty) }
    private var nodeStroke: Color {
        current ? GameStyle.accent : style.color ?? Color(uiColor: GameStyle.guideDot).opacity(0.55)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                LevelDifficultyAura(difficulty: level.difficulty)
                Circle()
                    .fill(locked ? (style.color?.opacity(0.13) ?? Color.white.opacity(0.90)) : Color.white)
                    .overlay(Circle().stroke(
                        nodeStroke,
                        lineWidth: current ? 5 : style.color == nil ? 2 : 3
                    ))
                    .shadow(
                        color: (style.color ?? .black).opacity(completed || current ? 0.14 : 0.04),
                        radius: 9,
                        y: 3
                    )

                if completed {
                    LevelRewardView(level: level, size: 52)
                } else if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(style.color ?? GameStyle.muted.opacity(0.55))
                } else {
                    Text(String(level.id))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(style.color ?? GameStyle.accent)
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
            .overlay(alignment: .bottom) {
                if let label = style.label, let color = style.color {
                    Text(label)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.35)
                        .foregroundColor(color)
                        .padding(.horizontal, 7)
                        .frame(height: 19)
                        .background(color.opacity(0.12), in: Capsule())
                        .offset(y: 17)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel(
            "Level \(level.id), \(level.difficulty?.title ?? "Normal"), \(locked ? "locked" : completed ? "complete" : "current")"
        )
        .accessibilityIdentifier(current ? "mapPlay" : "mapLevel\(level.id)")
    }
}

private struct LevelDifficultyAura: View {
    let difficulty: LevelDifficulty?

    var body: some View {
        switch difficulty {
        case .hard:
            ZStack {
                Image(systemName: "flame.fill").offset(y: -35)
                Image(systemName: "flame.fill").font(.system(size: 10)).offset(x: -24, y: -27)
                Image(systemName: "flame.fill").font(.system(size: 10)).offset(x: 24, y: -27)
            }
            .foregroundColor(Color(red: 0.95, green: 0.38, blue: 0.06))
        case .veryHard, .nightmare:
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<6, id: \.self) { index in
                        Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "diamond.fill")
                            .font(.system(size: index.isMultiple(of: 2) ? 10 : 5, weight: .bold))
                            .offset(y: -37 - CGFloat(sin(phase * 3 + Double(index))) * 3)
                            .rotationEffect(.degrees(
                                Double(index) * 60 + phase * (difficulty == .nightmare ? 38 : 24)
                            ))
                    }
                }
                .foregroundColor(
                    difficulty == .nightmare
                        ? Color(red: 0.44, green: 0.10, blue: 0.45)
                        : Color(red: 0.58, green: 0.31, blue: 0.82)
                )
            }
        default:
            EmptyView()
        }
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
