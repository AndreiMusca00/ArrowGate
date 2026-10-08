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
                            completed: store.completedLevels.filter { chapter.levelRange.contains($0) }.count,
                            unlocked: store.unlocked >= chapter.firstLevel
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
}

private struct ChapterGalleryCard: View {
    let chapter: ChapterDefinition
    let completed: Int
    let unlocked: Bool
    let action: () -> Void
    private var style: ChapterThemeStyle { .style(for: chapter.theme) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(colors: unlocked ? [style.background, Color.white] : [Color.white, GameStyle.background],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                if unlocked {
                    Text(style.decorations.joined(separator: "  "))
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(style.secondary.opacity(0.22))
                        .frame(maxWidth: .infinity, alignment: .trailing).padding(14)

                    VStack(alignment: .leading, spacing: 10) {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.72))
                            Image(systemName: chapter.symbol).foregroundColor(style.primary)
                        }
                        .frame(width: 42, height: 42)
                        Spacer(minLength: 0)
                        Text("CHAPTER \(chapter.id)")
                            .font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1)
                            .foregroundColor(style.primary)
                        Text(chapter.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(GameStyle.ink).multilineTextAlignment(.leading).lineLimit(2)
                        HStack {
                            Text("\(completed) / \(chapter.levelCount)")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(GameStyle.muted)
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .semibold)).foregroundColor(GameStyle.muted.opacity(0.45))
                        Text("CHAPTER \(chapter.id)")
                            .font(.system(size: 14, weight: .bold, design: .rounded)).tracking(0.8)
                            .foregroundColor(GameStyle.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 210)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke((unlocked ? style.primary : GameStyle.muted).opacity(0.10)))
        }
        .buttonStyle(.plain).disabled(!unlocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlocked ? "Chapter \(chapter.id), \(chapter.name), \(completed) of \(chapter.levelCount) collected" : "Chapter \(chapter.id), locked")
        .accessibilityIdentifier("chapterCard\(chapter.id)")
    }
}

private struct ChapterGalleryDetail: View {
    let chapter: ChapterDefinition
    @ObservedObject var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
    private var style: ChapterThemeStyle { .style(for: chapter.theme) }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(LevelRepository.levels(in: chapter)) { level in
                        GalleryCollectibleCard(level: level, collected: store.completedLevels.contains(level.id))
                    }
                }
                .padding(20)
            }
            .background(style.background.opacity(0.42).ignoresSafeArea())
            .navigationTitle(chapter.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.light)
    }
}

private struct GalleryCollectibleCard: View {
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
                .foregroundColor(collected ? GameStyle.ink : GameStyle.muted).lineLimit(1)
        }
        .frame(maxWidth: .infinity).frame(height: 132)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.035)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(collected ? "\(level.rewardName ?? "Collectible \(level.id)"), collected" : "Level \(level.id), locked")
    }
}
