import SwiftUI

struct JourneyView: View {
    @ObservedObject var store: ProgressStore

    private var completed: Int { store.completedLevels.count }
    private var current: Int? { completed == LevelRepository.count ? nil : store.unlocked }

    var body: some View {
        VStack(spacing: 0) {
            journeyHeader
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    JourneyPath(store: store, current: current)
                        .padding(.vertical, 18)
                }
                .onAppear {
                    guard let current, current > 4 else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            proxy.scrollTo(current, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(GameStyle.background.ignoresSafeArea())
    }

    private var journeyHeader: some View {
        ZStack {
            VStack(spacing: 5) {
                Text("EMOJI WORLD")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("journeyMap")
                Text("\(completed) / \(LevelRepository.count)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(GameStyle.muted)
                ProgressView(value: Double(completed), total: Double(LevelRepository.count))
                    .tint(GameStyle.accent)
                    .frame(width: 154)
            }
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
        }
        .frame(height: 92)
    }
}

private struct JourneyPath: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: ProgressStore
    let current: Int?
    private let step: CGFloat = 92
    private let top: CGFloat = 48

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { geometry in
                Canvas { context, size in
                    var path = Path()
                    let points = (1...LevelRepository.count).map {
                        CGPoint(x: geometry.size.width / 2 + xOffset(for: $0),
                                y: top + CGFloat($0 - 1) * step)
                    }
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for index in 1..<points.count {
                        let previous = points[index - 1], point = points[index]
                        let middleY = (previous.y + point.y) / 2
                        path.addCurve(to: point,
                                      control1: CGPoint(x: previous.x, y: middleY),
                                      control2: CGPoint(x: point.x, y: middleY))
                    }
                    context.stroke(path, with: .color(Color(uiColor: GameStyle.guideDot).opacity(0.55)),
                                   style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }

            VStack(spacing: step - 68) {
                ForEach(1...LevelRepository.count, id: \.self) { id in
                    ZStack {
                        JourneyLevelNode(level: LevelRepository.level(id),
                                         completed: store.completedLevels.contains(id),
                                         current: current == id,
                                         locked: id > store.unlocked) {
                            state.play(id)
                        }
                        .offset(x: xOffset(for: id))

                        if id.isMultiple(of: 5) {
                            MilestoneBadge(level: id)
                                .offset(x: xOffset(for: id) + (id.isMultiple(of: 10) ? 102 : -102))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 68)
                    .id(id)
                }
            }
            .padding(.top, top - 34)
            .padding(.bottom, top - 34)
        }
        .frame(height: top * 2 + step * CGFloat(LevelRepository.count - 1))
    }

    private func xOffset(for level: Int) -> CGFloat {
        let offsets: [CGFloat] = [-18, 22, 38, 5, -34, -22, 20, 36, 10, -28]
        return offsets[(level - 1) % offsets.count]
    }
}

private struct JourneyLevelNode: View {
    let level: LevelDefinition
    let completed: Bool
    let current: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(locked ? (difficultyColor?.opacity(0.11) ?? Color.white) : Color.white)
                    .overlay(Circle().stroke(nodeStroke,
                                             lineWidth: current ? 5 : difficultyColor == nil ? 2 : 3))
                    .shadow(color: .black.opacity(completed || current ? 0.07 : 0), radius: 8, y: 3)
                if completed {
                    LevelRewardView(level: level, size: 52)
                } else if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(difficultyColor ?? GameStyle.muted.opacity(0.55))
                } else {
                    Text(String(level.id))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(GameStyle.accent)
                }
            }
            .frame(width: current ? 68 : 58, height: current ? 68 : 58)
            .overlay(alignment: .trailing) {
                if current {
                    Text("PLAY")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(width: 88, height: 42)
                        .background(GameStyle.accent, in: Capsule())
                        .offset(x: 96)
                }
            }
            .overlay(alignment: .bottom) {
                if let difficultyLabel, let difficultyColor {
                    Text(difficultyLabel)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.35)
                        .foregroundColor(difficultyColor)
                        .padding(.horizontal, 7)
                        .frame(height: 19)
                        .background(difficultyColor.opacity(0.11), in: Capsule())
                        .offset(y: 17)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel("Level \(level.id), \(level.difficulty?.title ?? "Normal"), \(locked ? "locked" : completed ? "complete" : "current")")
        .accessibilityIdentifier(current ? "mapPlay" : "mapLevel\(level.id)")
    }

    private var nodeStroke: Color {
        current ? GameStyle.accent : difficultyColor ?? Color(uiColor: GameStyle.guideDot).opacity(0.55)
    }

    private var difficultyColor: Color? {
        switch level.difficulty {
        case .hard: return Color(red: 0.82, green: 0.42, blue: 0.08)
        case .veryHard: return Color(red: 0.47, green: 0.28, blue: 0.69)
        case .nightmare: return Color(red: 0.34, green: 0.10, blue: 0.34)
        default: return nil
        }
    }

    private var difficultyLabel: String? {
        switch level.difficulty {
        case .hard: return "HARD"
        case .veryHard: return "VERY HARD"
        case .nightmare: return "NIGHTMARE"
        default: return nil
        }
    }
}

private struct MilestoneBadge: View {
    let level: Int
    private var icon: String { level.isMultiple(of: 10) ? "heart.fill" : "lightbulb.fill" }
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(level.isMultiple(of: 10) ? GameStyle.color(.red) : GameStyle.color(.yellow))
            Text(String(level))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(GameStyle.muted)
        }
        .padding(.horizontal, 12).frame(height: 34)
        .background(Color.white.opacity(0.88), in: Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.04)))
        .accessibilityLabel("Level \(level) reward")
    }
}
