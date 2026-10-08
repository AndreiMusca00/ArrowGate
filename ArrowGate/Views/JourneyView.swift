import SwiftUI

struct JourneyView: View {
    @ObservedObject var store: ProgressStore

    private var completed: Int { store.completedLevels.count }
    private var current: Int? { completed == LevelRepository.count ? nil : store.unlocked }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                Text("JOURNEY")
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
            .frame(height: 92)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    JourneyPath(store: store, current: current)
                        .padding(.vertical, 12)
                }
                .onAppear {
                    guard let current, current > 4 else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.45)) { proxy.scrollTo(current, anchor: .center) }
                    }
                }
            }
        }
        .background(GameStyle.background.ignoresSafeArea())
    }
}

private struct JourneyPath: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: ProgressStore
    let current: Int?
    private let step: CGFloat = 92
    private let chapterGap: CGFloat = 104
    private let top: CGFloat = 132

    private var totalHeight: CGFloat {
        top * 2 + step * CGFloat(LevelRepository.count - 1) + chapterGap * CGFloat(max(0, LevelRepository.chapters.count - 1))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(LevelRepository.chapters) { chapter in
                    JourneyChapterBackdrop(chapter: chapter, locked: store.unlocked < chapter.firstLevel)
                        .frame(width: max(0, geometry.size.width - 20), height: backdropHeight(for: chapter))
                        .position(x: geometry.size.width / 2, y: backdropCenterY(for: chapter))
                }

                Canvas { context, _ in
                    let points = LevelRepository.levels.map {
                        CGPoint(x: geometry.size.width / 2 + xOffset(for: $0.id), y: yPosition(for: $0.id))
                    }
                    guard let first = points.first else { return }
                    var path = Path(); path.move(to: first)
                    for index in 1..<points.count {
                        let previous = points[index - 1], point = points[index]
                        let middleY = (previous.y + point.y) / 2
                        path.addCurve(to: point,
                                      control1: CGPoint(x: previous.x, y: middleY),
                                      control2: CGPoint(x: point.x, y: middleY))
                    }
                    context.stroke(path, with: .color(Color(uiColor: GameStyle.guideDot).opacity(0.5)),
                                   style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }

                ForEach(LevelRepository.levels) { level in
                    JourneyLevelNode(level: level,
                                     completed: store.completedLevels.contains(level.id),
                                     current: current == level.id,
                                     locked: level.id > store.unlocked) {
                        state.play(level.id)
                    }
                    .position(x: geometry.size.width / 2 + xOffset(for: level.id), y: yPosition(for: level.id))
                    .id(level.id)

                    if let reward = level.completionReward {
                        MilestoneBadge(level: level.id, reward: reward,
                                       claimed: store.completedLevels.contains(level.id))
                            .position(x: geometry.size.width / 2 + xOffset(for: level.id) + (level.id.isMultiple(of: 10) ? 106 : -106),
                                      y: yPosition(for: level.id))
                    }
                }
            }
        }
        .frame(height: totalHeight)
    }

    private func chapterIndex(for level: Int) -> Int {
        LevelRepository.chapters.firstIndex { $0.levelRange.contains(level) } ?? 0
    }
    private func yPosition(for level: Int) -> CGFloat {
        top + CGFloat(level - 1) * step + CGFloat(chapterIndex(for: level)) * chapterGap
    }
    private func backdropHeight(for chapter: ChapterDefinition) -> CGFloat {
        CGFloat(chapter.levelCount - 1) * step + top + 70
    }
    private func backdropCenterY(for chapter: ChapterDefinition) -> CGFloat {
        let firstY = yPosition(for: chapter.firstLevel)
        let lastY = yPosition(for: chapter.lastLevel)
        return (firstY + lastY) / 2 + 4
    }
    private func xOffset(for level: Int) -> CGFloat {
        let offsets: [CGFloat] = [-18, 22, 38, 5, -34, -22, 20, 36, 10, -28]
        return offsets[(level - 1) % offsets.count]
    }
}

private struct JourneyChapterBackdrop: View {
    let chapter: ChapterDefinition
    let locked: Bool
    private var style: ChapterThemeStyle { .style(for: chapter.theme) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32)
                .fill(LinearGradient(colors: [style.background.opacity(0.78), Color.white.opacity(0.30)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(style.primary.opacity(0.10)))
            HStack(spacing: 10) {
                Image(systemName: locked ? "lock.fill" : chapter.symbol).foregroundColor(style.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHAPTER \(chapter.id)")
                        .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1)
                    Text(chapter.name).font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(GameStyle.ink)
            .padding(.horizontal, 22).padding(.top, 18)
            Text(style.decorations.joined(separator: "   "))
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(style.secondary.opacity(0.20))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 22).padding(.trailing, 20)
        }
        .opacity(locked ? 0.72 : 1)
        .accessibilityHidden(true)
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
                DifficultyAura(difficulty: level.difficulty)
                Circle()
                    .fill(locked ? (difficultyColor?.opacity(0.13) ?? Color.white.opacity(0.90)) : Color.white)
                    .overlay(Circle().stroke(nodeStroke, lineWidth: current ? 5 : difficultyColor == nil ? 2 : 3))
                    .shadow(color: (difficultyColor ?? .black).opacity(completed || current ? 0.14 : 0.04), radius: 9, y: 3)
                if completed {
                    LevelRewardView(level: level, size: 52)
                } else if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(difficultyColor ?? GameStyle.muted.opacity(0.55))
                } else {
                    Text(String(level.id))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(difficultyColor ?? GameStyle.accent)
                }
            }
            .frame(width: current ? 68 : 58, height: current ? 68 : 58)
            .overlay(alignment: .trailing) {
                if current {
                    Text("PLAY").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.white)
                        .frame(width: 88, height: 42).background(GameStyle.accent, in: Capsule()).offset(x: 96)
                }
            }
            .overlay(alignment: .bottom) {
                if let difficultyLabel, let difficultyColor {
                    Text(difficultyLabel)
                        .font(.system(size: 8, weight: .bold, design: .rounded)).tracking(0.35)
                        .foregroundColor(difficultyColor).padding(.horizontal, 7).frame(height: 19)
                        .background(difficultyColor.opacity(0.12), in: Capsule()).offset(y: 17)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .accessibilityLabel("Level \(level.id), \(level.difficulty?.title ?? "Normal"), \(locked ? "locked" : completed ? "complete" : "current")")
        .accessibilityIdentifier(current ? "mapPlay" : "mapLevel\(level.id)")
    }

    private var nodeStroke: Color { current ? GameStyle.accent : difficultyColor ?? Color(uiColor: GameStyle.guideDot).opacity(0.55) }
    private var difficultyColor: Color? {
        switch level.difficulty {
        case .hard: return Color(red: 0.91, green: 0.38, blue: 0.07)
        case .veryHard: return Color(red: 0.51, green: 0.24, blue: 0.75)
        case .nightmare: return Color(red: 0.30, green: 0.06, blue: 0.30)
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

private struct DifficultyAura: View {
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
                            .rotationEffect(.degrees(Double(index) * 60 + phase * (difficulty == .nightmare ? 38 : 24)))
                    }
                }
                .foregroundColor(difficulty == .nightmare ? Color(red: 0.44, green: 0.10, blue: 0.45) : Color(red: 0.58, green: 0.31, blue: 0.82))
            }
        default:
            EmptyView()
        }
    }
}

private struct MilestoneBadge: View {
    let level: Int
    let reward: LevelCompletionReward
    let claimed: Bool

    private var icon: String { reward.kind == .life ? "heart.fill" : "lightbulb.fill" }
    private var color: Color { reward.kind == .life ? GameStyle.color(.red) : GameStyle.color(.yellow) }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: claimed ? "checkmark.circle.fill" : icon).foregroundColor(claimed ? GameStyle.accent : color)
            Text(claimed ? "CLAIMED" : "+\(reward.amount)")
                .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(GameStyle.muted)
        }
        .padding(.horizontal, 11).frame(height: 34)
        .background(Color.white.opacity(0.90), in: Capsule())
        .overlay(Capsule().stroke(color.opacity(0.16)))
        .accessibilityLabel("Level \(level) reward, \(claimed ? "claimed" : reward.kind.rawValue)")
    }
}
