import SwiftUI

struct EmojiGalleryView: View {
    @ObservedObject var store: ProgressStore
    @State private var selectedChapter: ChapterDefinition?
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("GALLERY")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("emojiGallery")
                Text("\(store.completedLevels.count) collected")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(GameStyle.muted)
            }
            .frame(maxWidth: .infinity).frame(height: 82)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(LevelRepository.chapters) { chapter in
                        ChapterGalleryCard(
                            chapter: chapter,
                            completed: completedCount(in: chapter),
                            unlocked: isUnlocked(chapter)
                        ) {
                            selectedChapter = chapter
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
        .background(GameStyle.background.ignoresSafeArea())
        .sheet(item: $selectedChapter) { chapter in
            ChapterGalleryDetail(chapter: chapter, store: store)
        }
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
