import SwiftUI

struct EmojiGalleryView: View {
    @ObservedObject var store: ProgressStore
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            galleryHeader
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(LevelRepository.levels) { level in
                        GalleryCard(level: level, unlocked: store.completedLevels.contains(level.id))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background(GameStyle.background.ignoresSafeArea())
    }

    private var galleryHeader: some View {
        ZStack {
            VStack(spacing: 4) {
                Text("GALLERY")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("emojiGallery")
                Text("\(store.completedLevels.count) collected")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(GameStyle.muted)
            }
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
        }
        .frame(height: 82)
    }
}

private struct GalleryCard: View {
    let level: LevelDefinition
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 10) {
            if unlocked {
                LevelRewardView(level: level, size: 82)
            } else {
                ZStack {
                    Circle().fill(GameStyle.background).frame(width: 76, height: 76)
                    Image(systemName: "lock.fill").foregroundColor(GameStyle.muted.opacity(0.45))
                }
            }
            Text(unlocked ? (level.rewardName ?? "Emoji \(level.id)") : "Emoji \(level.id)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(unlocked ? GameStyle.ink : GameStyle.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.black.opacity(0.035)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlocked ? "\(level.rewardName ?? "Emoji \(level.id)"), collected" : "Emoji \(level.id), locked")
    }
}
