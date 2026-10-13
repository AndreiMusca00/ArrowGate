import SwiftUI

struct CollectionView: View {
    @ObservedObject var store: ProgressStore
    @Binding var selectedChapter: ChapterDefinition?
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("COLLECTION")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("collectionPage")
                Text("\(store.completedLevels.count) collected")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(GameStyle.muted)
            }
            .frame(maxWidth: .infinity).frame(height: 82)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(LevelRepository.chapters) { chapter in
                        ChapterCollectionCard(
                            chapter: chapter,
                            completed: completedCount(in: chapter),
                            unlocked: isUnlocked(chapter)
                        ) {
                            guard chapter.assembly != nil else { return }
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                                selectedChapter = chapter
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
        .background(GameStyle.background.ignoresSafeArea())
    }

    private func completedCount(in chapter: ChapterDefinition) -> Int {
        let identifiers = Set(LevelRepository.levels(in: chapter).map(\.id))
        return store.completedLevels.intersection(identifiers).count
    }

    private func isUnlocked(_ chapter: ChapterDefinition) -> Bool {
        guard let first = LevelRepository.firstLevel(in: chapter) else { return false }
        return store.unlocked >= first.id
    }

}

struct CollectionArtworkOverlay: View {
    let chapter: ChapterDefinition
    let assembly: ChapterAssemblyDefinition
    @ObservedObject var store: ProgressStore
    let close: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(geometry.size.width - 40, 440)
            let artworkWidth = cardWidth - 44
            let artworkHeight = artworkWidth / max(assembly.aspectRatio, 0.1)
            let screenCenterY = UIScreen.main.bounds.midY - geometry.frame(in: .global).minY

            ZStack {
                GameStyle.ink.opacity(0.10)
                    .ignoresSafeArea()
                    .transition(.opacity)

                Button(action: close) {
                    Color.clear
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close enlarged picture")
                .accessibilityIdentifier("expandedCollectionArtwork")

                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white)

                    ChapterAssemblyFigure(
                        assembly: assembly,
                        revealedPieces: revealedPieces,
                        revealsFinalArtwork: revealsFinalArtwork
                    )
                    .frame(width: artworkWidth, height: artworkHeight)
                }
                .frame(width: cardWidth, height: artworkHeight + 44)
                .shadow(color: GameStyle.ink.opacity(0.16), radius: 28, y: 14)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .onTapGesture(perform: close)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Enlarged collection picture")
                .accessibilityIdentifier("expandedCollectionCard")
                .position(x: geometry.size.width / 2, y: screenCenterY)
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var revealedPieces: Set<Int> {
        Set(LevelRepository.levels(in: chapter).prefix(assembly.pieceCount).enumerated().compactMap { index, level in
            store.completedLevels.contains(level.id) ? index : nil
        })
    }

    private var revealsFinalArtwork: Bool {
        guard let finalLevel = LevelRepository.levels(in: chapter).last else { return false }
        return store.completedLevels.contains(finalLevel.id)
    }
}
