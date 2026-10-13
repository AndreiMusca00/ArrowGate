import SwiftUI

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
