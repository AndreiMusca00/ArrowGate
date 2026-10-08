import SwiftUI

/// Owns the geometry and layout of the Journey path. The parent decides what
/// opening a level means, keeping the map independent from app navigation.
struct JourneyMapView: View {
    @ObservedObject var store: ProgressStore
    let current: Int?
    let onSelectLevel: (LevelDefinition) -> Void

    private let step: CGFloat = 92
    private let chapterGap: CGFloat = 104
    private let top: CGFloat = 132

    private var totalHeight: CGFloat {
        top * 2
            + step * CGFloat(LevelRepository.count - 1)
            + chapterGap * CGFloat(max(0, LevelRepository.chapters.count - 1))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                chapterBackgrounds(width: geometry.size.width)
                journeyLine(width: geometry.size.width)
                levelNodes(width: geometry.size.width)
            }
        }
        .frame(height: totalHeight)
    }

    @ViewBuilder
    private func chapterBackgrounds(width: CGFloat) -> some View {
        ForEach(LevelRepository.chapters) { chapter in
            JourneyChapterBackdrop(
                chapter: chapter,
                locked: isLocked(chapter)
            )
            .frame(width: max(0, width - 20), height: backdropHeight(for: chapter))
            .position(x: width / 2, y: backdropCenterY(for: chapter))
        }
    }

    private func journeyLine(width: CGFloat) -> some View {
        Canvas { context, _ in
            let points = LevelRepository.levels.map {
                CGPoint(x: width / 2 + xOffset(for: $0.id), y: yPosition(for: $0.id))
            }
            guard let first = points.first else { return }

            var path = Path()
            path.move(to: first)
            for index in 1..<points.count {
                let previous = points[index - 1]
                let point = points[index]
                let middleY = (previous.y + point.y) / 2
                path.addCurve(
                    to: point,
                    control1: CGPoint(x: previous.x, y: middleY),
                    control2: CGPoint(x: point.x, y: middleY)
                )
            }
            context.stroke(
                path,
                with: .color(Color(uiColor: GameStyle.guideDot).opacity(0.5)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
        }
    }

    @ViewBuilder
    private func levelNodes(width: CGFloat) -> some View {
        ForEach(LevelRepository.levels) { level in
            JourneyLevelNode(
                level: level,
                chapterColor: Color(catalogHex: LevelRepository.chapter(level.chapterID).style.primaryColor),
                completed: store.completedLevels.contains(level.id),
                current: current == level.id,
                locked: level.id > store.unlocked
            ) {
                onSelectLevel(level)
            }
            .position(x: width / 2 + xOffset(for: level.id), y: yPosition(for: level.id))
            .id(level.id)

            if let reward = level.completionReward {
                LevelMilestoneBadge(
                    level: level.id,
                    reward: reward,
                    claimed: store.completedLevels.contains(level.id)
                )
                .position(
                    x: width / 2 + xOffset(for: level.id) + (level.id.isMultiple(of: 10) ? 106 : -106),
                    y: yPosition(for: level.id)
                )
            }
        }
    }

    private func chapterIndex(for level: Int) -> Int {
        guard let chapterID = LevelRepository.levels.first(where: { $0.id == level })?.chapterID else { return 0 }
        return LevelRepository.chapters.firstIndex { $0.id == chapterID } ?? 0
    }

    private func yPosition(for level: Int) -> CGFloat {
        let index = LevelRepository.levels.firstIndex { $0.id == level } ?? 0
        return top + CGFloat(index) * step + CGFloat(chapterIndex(for: level)) * chapterGap
    }

    private func backdropHeight(for chapter: ChapterDefinition) -> CGFloat {
        CGFloat(max(0, LevelRepository.levels(in: chapter).count - 1)) * step + top + 70
    }

    private func backdropCenterY(for chapter: ChapterDefinition) -> CGFloat {
        let levels = LevelRepository.levels(in: chapter)
        guard let first = levels.first, let last = levels.last else { return 0 }
        return (yPosition(for: first.id) + yPosition(for: last.id)) / 2 + 4
    }

    private func xOffset(for level: Int) -> CGFloat {
        let offsets: [CGFloat] = [-18, 22, 38, 5, -34, -22, 20, 36, 10, -28]
        let chapter = LevelRepository.chapter(containing: level)
        let localIndex = LevelRepository.levels(in: chapter).firstIndex { $0.id == level } ?? 0
        return offsets[localIndex % offsets.count]
    }

    private func isLocked(_ chapter: ChapterDefinition) -> Bool {
        guard let first = LevelRepository.firstLevel(in: chapter) else { return true }
        return store.unlocked < first.id
    }
}
