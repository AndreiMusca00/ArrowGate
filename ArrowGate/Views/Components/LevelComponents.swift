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

                LevelDifficultyAura(
                    difficulty: level.difficulty,
                    nodeDiameter: nodeDiameter,
                    reduceMotion: reduceMotion
                )

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

/// The Home action mirrors the difficulty treatment across the complete button.
struct HomePlayButton: View {
    let level: LevelDefinition
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var backgroundGradient: LinearGradient {
        let colors: [Color]
        switch level.difficulty {
        case .hard:
            colors = [
                Color(red: 0.98, green: 0.70, blue: 0.08),
                Color(red: 0.82, green: 0.42, blue: 0.02)
            ]
        case .veryHard:
            colors = [
                Color(red: 0.76, green: 0.035, blue: 0.10),
                Color(red: 0.35, green: 0.005, blue: 0.045)
            ]
        case .nightmare:
            colors = [
                Color(red: 0.48, green: 0.07, blue: 0.61),
                Color(red: 0.13, green: 0.01, blue: 0.22)
            ]
        default:
            colors = [GameStyle.accent, GameStyle.accent]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        if level.difficulty == .hard || level.difficulty == .veryHard {
            FireDifficultyButton(
                difficulty: level.difficulty ?? .hard,
                action: action
            ) {
                homeLabel
            }
            .frame(width: 190)
            .accessibilityLabel("Level \(level.id)")
            .accessibilityIdentifier("play")
        } else {
            standardButton
                .frame(width: 190)
        }
    }

    private var standardButton: some View {
        Button(action: action) {
            ZStack {
                GeometryReader { geometry in
                    HomeButtonDifficultyAura(
                        difficulty: level.difficulty,
                        buttonSize: geometry.size,
                        reduceMotion: reduceMotion
                    )
                }
                .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 18)
                    .fill(backgroundGradient)
                    .shadow(color: buttonShadow, radius: 12, y: 5)

                homeLabel
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .foregroundColor(.white)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Level \(level.id)")
        .accessibilityIdentifier("play")
    }

    private var homeLabel: some View {
        VStack(spacing: difficultyLabel == nil ? 0 : 2) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 30, height: 30)

                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .offset(x: 1)
                }
                Text("Level \(level.id)")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }

            if let difficultyLabel {
                Text(difficultyLabel)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .tracking(1.15)
                    .opacity(0.66)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
    }

    private var difficultyLabel: String? {
        switch level.difficulty {
        case .hard: return "HARD"
        case .veryHard: return "VERY HARD"
        case .nightmare: return "NIGHTMARE"
        default: return nil
        }
    }

    private var buttonShadow: Color {
        switch level.difficulty {
        case .hard: return Color(red: 0.86, green: 0.48, blue: 0.02).opacity(0.24)
        case .veryHard: return Color(red: 0.50, green: 0.01, blue: 0.06).opacity(0.30)
        case .nightmare: return Color(red: 0.25, green: 0.02, blue: 0.38).opacity(0.32)
        default: return GameStyle.accent.opacity(0.18)
        }
    }
}

private struct LevelDifficultyAura: View {
    let difficulty: LevelDifficulty?
    let nodeDiameter: CGFloat
    let reduceMotion: Bool

    @ViewBuilder
    var body: some View {
        if difficulty == .hard || difficulty == .veryHard || difficulty == .nightmare {
            if reduceMotion {
                StaticDifficultyAura(difficulty: difficulty, nodeDiameter: nodeDiameter)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                    AnimatedDifficultyAura(
                        difficulty: difficulty,
                        nodeDiameter: nodeDiameter,
                        time: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            }
        }
    }
}

private struct StaticDifficultyAura: View {
    let difficulty: LevelDifficulty?
    let nodeDiameter: CGFloat

    @ViewBuilder
    var body: some View {
        switch difficulty {
        case .hard:
            JourneySparkRingAura(
                time: 0.35,
                nodeDiameter: nodeDiameter,
                difficulty: .hard
            )
        case .veryHard:
            JourneySparkRingAura(
                time: 0.35,
                nodeDiameter: nodeDiameter,
                difficulty: .veryHard
            )
        case .nightmare:
            RisingFlameAura(
                time: 0.35,
                nodeDiameter: nodeDiameter,
                palette: .nightmare,
                thickness: 0.94
            )
        default:
            EmptyView()
        }
    }
}

private struct AnimatedDifficultyAura: View {
    let difficulty: LevelDifficulty?
    let nodeDiameter: CGFloat
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
        JourneySparkRingAura(
            time: time,
            nodeDiameter: nodeDiameter,
            difficulty: .hard
        )
    }

    private var bloodFlames: some View {
        JourneySparkRingAura(
            time: time,
            nodeDiameter: nodeDiameter,
            difficulty: .veryHard
        )
    }

    private var nightmareVortex: some View {
        RisingFlameAura(
            time: time,
            nodeDiameter: nodeDiameter,
            palette: .nightmare,
            thickness: 0.94
        )
    }
}

private struct JourneySparkRingAura: View {
    let time: TimeInterval
    let nodeDiameter: CGFloat
    let difficulty: LevelDifficulty

    private var isVeryHard: Bool { difficulty == .veryHard }
    private var primary: Color {
        isVeryHard
            ? Color(red: 0.76, green: 0.025, blue: 0.075)
            : Color(red: 0.96, green: 0.43, blue: 0.025)
    }
    private var hot: Color {
        isVeryHard
            ? Color(red: 1.0, green: 0.16, blue: 0.12)
            : Color(red: 1.0, green: 0.67, blue: 0.08)
    }

    var body: some View {
        let frameSide = nodeDiameter + 50

        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let ringRadius = nodeDiameter / 2 + 4.5
            let ringRect = CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2
            )
            let ring = Path(ellipseIn: ringRect)

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: isVeryHard ? 5.5 : 3.5))
                glow.stroke(
                    ring,
                    with: .color(primary.opacity(isVeryHard ? 0.55 : 0.38)),
                    lineWidth: isVeryHard ? 3.2 : 2.2
                )
            }
            context.stroke(
                ring,
                with: .color(primary.opacity(isVeryHard ? 0.82 : 0.68)),
                lineWidth: isVeryHard ? 1.8 : 1.25
            )

            let count = isVeryHard ? 18 : 10
            for index in 0..<count {
                let seed = Double(index + 1)
                let speed = isVeryHard ? 0.86 : 0.62
                let rawProgress = time * speed + seed * 0.217
                let progress = rawProgress - floor(rawProgress)
                let angle = seed / Double(count) * Double.pi * 2
                    + sin(time * 0.38 + seed) * 0.035
                let outward = CGFloat(2.5 + progress * (isVeryHard ? 10 : 7))
                let rise = CGFloat(progress) * (isVeryHard ? 11 : 7)
                let shimmer = 0.5 + 0.5 * sin(time * 5.2 + seed * 2.3)
                let opacity = sin(progress * .pi) * (0.52 + shimmer * 0.48)
                let particleSize = CGFloat(isVeryHard ? 1.8 : 1.35)
                    + CGFloat(shimmer) * (isVeryHard ? 1.8 : 1.15)
                let particleCenter = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * (ringRadius + outward)
                        + CGFloat(sin(time * 2.4 + seed)) * 1.1,
                    y: center.y + CGFloat(sin(angle)) * (ringRadius + outward) - rise
                )

                context.drawLayer { sparkGlow in
                    sparkGlow.addFilter(.blur(radius: isVeryHard ? 2.2 : 1.4))
                    sparkGlow.fill(
                        sparkPath(center: particleCenter, size: particleSize * 1.8),
                        with: .color(primary.opacity(opacity * 0.52))
                    )
                }
                context.fill(
                    sparkPath(center: particleCenter, size: particleSize),
                    with: .color((index.isMultiple(of: 3) ? hot : primary).opacity(opacity))
                )
            }
        }
        .frame(width: frameSide, height: frameSide)
        .accessibilityHidden(true)
    }

    private func sparkPath(center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - size))
        path.addLine(to: CGPoint(x: center.x + size * 0.55, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + size))
        path.addLine(to: CGPoint(x: center.x - size * 0.55, y: center.y))
        path.closeSubpath()
        return path
    }
}

private struct FlamePalette {
    let dark: Color
    let middle: Color
    let hot: Color

    static let blood = FlamePalette(
        dark: Color(red: 0.34, green: 0.005, blue: 0.045),
        middle: Color(red: 0.66, green: 0.025, blue: 0.09),
        hot: Color(red: 0.93, green: 0.09, blue: 0.14)
    )
    static let nightmare = FlamePalette(
        dark: Color(red: 0.10, green: 0.005, blue: 0.16),
        middle: Color(red: 0.31, green: 0.035, blue: 0.45),
        hot: Color(red: 0.65, green: 0.14, blue: 0.78)
    )
}

private func risingFlameHeight(
    time: TimeInterval,
    verticalProgress: Double,
    sidePhase: Double,
    thickness: CGFloat
) -> CGFloat {
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
    return CGFloat(
        1.4 + envelope * (
            3.2 + broadWave * 4.2 + fineWave * 1.6
                + sharpTongue * 10 + travellingFlare * 4.5
        )
    ) * thickness
}

private struct HomeButtonDifficultyAura: View {
    let difficulty: LevelDifficulty?
    let buttonSize: CGSize
    let reduceMotion: Bool

    @ViewBuilder
    var body: some View {
        if difficulty == .hard || difficulty == .veryHard || difficulty == .nightmare {
            if reduceMotion {
                aura(at: 0.35)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
                    aura(at: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    @ViewBuilder
    private func aura(at time: TimeInterval) -> some View {
        switch difficulty {
        case .hard:
            HomeStarBorderAura(time: time, buttonSize: buttonSize)
        case .veryHard:
            HomeFlameBorderAura(
                time: time,
                buttonSize: buttonSize,
                palette: .blood,
                thickness: 0.66
            )
        case .nightmare:
            HomeFlameBorderAura(
                time: time,
                buttonSize: buttonSize,
                palette: .nightmare,
                thickness: 0.94
            )
        default:
            EmptyView()
        }
    }
}

private struct HomeStarBorderAura: View {
    let time: TimeInterval
    let buttonSize: CGSize

    private let gold = Color(red: 0.96, green: 0.64, blue: 0.04)
    private let paleGold = Color(red: 1.00, green: 0.84, blue: 0.24)

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(starPositions.enumerated()), id: \.offset) { index, point in
                let pulse = 0.5 + 0.5 * sin(time * 4.0 + Double(index) * 1.65)
                let drift = CGFloat(sin(time * 2.1 + Double(index))) * 1.3
                Image(systemName: index.isMultiple(of: 3) ? "sparkle" : "star.fill")
                    .font(.system(
                        size: CGFloat(index.isMultiple(of: 3) ? 8.5 : 5.5) + CGFloat(pulse) * 1.5,
                        weight: .bold
                    ))
                    .foregroundColor(index.isMultiple(of: 2) ? paleGold : gold)
                    .scaleEffect(0.72 + CGFloat(pulse) * 0.34)
                    .position(x: point.x, y: point.y + drift)
            }
        }
        .frame(width: buttonSize.width, height: buttonSize.height)
    }

    private var starPositions: [CGPoint] {
        let horizontalCount = max(6, Int(buttonSize.width / 42))
        let sideCount = 2
        let horizontalInset: CGFloat = 22
        var result: [CGPoint] = []

        for index in 0..<horizontalCount {
            let fraction = CGFloat(index) / CGFloat(max(1, horizontalCount - 1))
            let x = horizontalInset + fraction * max(0, buttonSize.width - horizontalInset * 2)
            result.append(CGPoint(x: x, y: -2.5))
            result.append(CGPoint(x: x, y: buttonSize.height + 2.5))
        }
        for index in 0..<sideCount {
            let fraction = CGFloat(index + 1) / CGFloat(sideCount + 1)
            let y = 12 + fraction * max(0, buttonSize.height - 24)
            result.append(CGPoint(x: -2.5, y: y))
            result.append(CGPoint(x: buttonSize.width + 2.5, y: y))
        }
        return result
    }
}

private struct HomeFlameBorderAura: View {
    let time: TimeInterval
    let buttonSize: CGSize
    let palette: FlamePalette
    let thickness: CGFloat

    private struct PerimeterSample {
        let point: CGPoint
        let normal: CGVector
    }

    var body: some View {
        let padding: CGFloat = 28
        let canvasSize = CGSize(
            width: buttonSize.width + padding * 2,
            height: buttonSize.height + padding * 2
        )

        Canvas { context, _ in
            let buttonRect = CGRect(
                x: padding,
                y: padding,
                width: buttonSize.width,
                height: buttonSize.height
            )
            let flame = flameRing(around: buttonRect)

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 5.5))
                glow.fill(flame, with: .color(palette.middle.opacity(0.46)))
            }

            context.fill(
                flame,
                with: .linearGradient(
                    Gradient(colors: [palette.hot, palette.middle, palette.dark]),
                    startPoint: CGPoint(x: buttonRect.midX, y: buttonRect.minY - 20),
                    endPoint: CGPoint(x: buttonRect.midX, y: buttonRect.maxY + 9)
                )
            )
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .offset(x: -padding, y: -padding)
        .accessibilityHidden(true)
    }

    private func flameRing(around rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let perimeter = 2 * (rect.width + rect.height - 4 * radius) + 2 * .pi * radius
        let samples = max(160, Int(perimeter / 2.2))
        var outer: [CGPoint] = []
        var inner: [CGPoint] = []

        for index in 0...samples {
            let fraction = CGFloat(index) / CGFloat(samples)
            let sample = perimeterSample(on: rect, cornerRadius: radius, fraction: fraction)
            let verticalProgress = Double(
                min(1, max(0, (rect.maxY - sample.point.y) / max(1, rect.height)))
            )
            let sidePhase = Double(
                (sample.point.x - rect.midX) / max(1, rect.width / 2)
            ) * 1.35
            let height = risingFlameHeight(
                time: time,
                verticalProgress: verticalProgress,
                sidePhase: sidePhase,
                thickness: thickness
            )
            outer.append(CGPoint(
                x: sample.point.x + sample.normal.dx * height,
                y: sample.point.y + sample.normal.dy * height
            ))
            inner.append(CGPoint(
                x: sample.point.x - sample.normal.dx * 1.5,
                y: sample.point.y - sample.normal.dy * 1.5
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

    private func perimeterSample(
        on rect: CGRect,
        cornerRadius radius: CGFloat,
        fraction: CGFloat
    ) -> PerimeterSample {
        let horizontal = max(0, rect.width - radius * 2)
        let vertical = max(0, rect.height - radius * 2)
        let arc = .pi * radius / 2
        let perimeter = horizontal * 2 + vertical * 2 + arc * 4
        var distance = min(max(fraction, 0), 1) * perimeter

        if distance <= horizontal {
            return PerimeterSample(
                point: CGPoint(x: rect.minX + radius + distance, y: rect.minY),
                normal: CGVector(dx: 0, dy: -1)
            )
        }
        distance -= horizontal
        if distance <= arc {
            let angle = -.pi / 2 + distance / arc * (.pi / 2)
            return arcSample(
                center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                radius: radius,
                angle: angle
            )
        }
        distance -= arc
        if distance <= vertical {
            return PerimeterSample(
                point: CGPoint(x: rect.maxX, y: rect.minY + radius + distance),
                normal: CGVector(dx: 1, dy: 0)
            )
        }
        distance -= vertical
        if distance <= arc {
            let angle = distance / arc * (.pi / 2)
            return arcSample(
                center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                radius: radius,
                angle: angle
            )
        }
        distance -= arc
        if distance <= horizontal {
            return PerimeterSample(
                point: CGPoint(x: rect.maxX - radius - distance, y: rect.maxY),
                normal: CGVector(dx: 0, dy: 1)
            )
        }
        distance -= horizontal
        if distance <= arc {
            let angle = .pi / 2 + distance / arc * (.pi / 2)
            return arcSample(
                center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                radius: radius,
                angle: angle
            )
        }
        distance -= arc
        if distance <= vertical {
            return PerimeterSample(
                point: CGPoint(x: rect.minX, y: rect.maxY - radius - distance),
                normal: CGVector(dx: -1, dy: 0)
            )
        }
        distance -= vertical
        let angle = .pi + distance / arc * (.pi / 2)
        return arcSample(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            angle: angle
        )
    }

    private func arcSample(center: CGPoint, radius: CGFloat, angle: CGFloat) -> PerimeterSample {
        let normal = CGVector(dx: cos(angle), dy: sin(angle))
        return PerimeterSample(
            point: CGPoint(
                x: center.x + normal.dx * radius,
                y: center.y + normal.dy * radius
            ),
            normal: normal
        )
    }
}

/// A fluid ring attached directly to the level node. The flame begins as a
/// thin edge at the bottom and grows while its waves travel upward.
private struct RisingFlameAura: View {
    let time: TimeInterval
    let nodeDiameter: CGFloat
    let palette: FlamePalette
    let thickness: CGFloat

    var body: some View {
        let canvasWidth = max(112, nodeDiameter + 80)
        let canvasHeight = max(128, nodeDiameter + 92)

        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = nodeDiameter / 2 + 2.25
            let crown = fireCrown(center: center, radius: radius)

            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 5.5))
                glow.fill(crown, with: .color(palette.middle.opacity(0.46)))
            }

            context.fill(
                crown,
                with: .linearGradient(
                    Gradient(colors: [palette.hot, palette.middle, palette.dark]),
                    startPoint: CGPoint(x: center.x, y: center.y - radius - 20),
                    endPoint: CGPoint(x: center.x, y: center.y - radius + 9)
                )
            )
        }
        .frame(width: canvasWidth, height: canvasHeight)
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
            let height = risingFlameHeight(
                time: time,
                verticalProgress: verticalProgress,
                sidePhase: sidePhase,
                thickness: thickness
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

    @ViewBuilder
    var body: some View {
        if claimed {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(GameStyle.accent)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.92), in: Circle())
                .overlay(Circle().stroke(GameStyle.accent.opacity(0.18), lineWidth: 1.2))
                .accessibilityLabel("Level \(level) reward, claimed")
        } else {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text("+\(reward.amount)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(GameStyle.muted)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Color.white.opacity(0.90), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(0.16)))
            .accessibilityLabel("Level \(level) reward, \(reward.kind.rawValue)")
        }
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
