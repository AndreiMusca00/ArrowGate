import SwiftUI

/// All chapter-specific styling lives here so a chapter can be restyled
/// consistently in the collection, detail gallery, and Journey map.
struct ChapterThemeStyle {
    let primary: Color
    let secondary: Color
    let background: Color
    let decorations: [String]

    static func style(for theme: ChapterTheme) -> ChapterThemeStyle {
        switch theme {
        case .emoji:
            return ChapterThemeStyle(
                primary: Color(red: 0.91, green: 0.58, blue: 0.12),
                secondary: Color(red: 0.91, green: 0.35, blue: 0.39),
                background: Color(red: 1.00, green: 0.95, blue: 0.82),
                decorations: ["☺︎", "✦", "♡"]
            )
        case .fruit:
            return ChapterThemeStyle(
                primary: Color(red: 0.20, green: 0.58, blue: 0.34),
                secondary: Color(red: 0.91, green: 0.31, blue: 0.24),
                background: Color(red: 0.88, green: 0.96, blue: 0.87),
                decorations: ["🍃", "•", "✦"]
            )
        }
    }
}

/// A chapter as it appears in the two-column Gallery collection.
struct ChapterGalleryCard: View {
    let chapter: ChapterDefinition
    let completed: Int
    let unlocked: Bool
    let action: () -> Void

    private var style: ChapterThemeStyle { .style(for: chapter.theme) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(
                        colors: unlocked ? [style.background, Color.white] : [Color.white, GameStyle.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                if unlocked {
                    unlockedContent
                } else {
                    lockedContent
                }
            }
            .frame(height: 210)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke((unlocked ? style.primary : GameStyle.muted).opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlocked
            ? "Chapter \(chapter.id), \(chapter.name), \(completed) of \(chapter.levelCount) collected"
            : "Chapter \(chapter.id), locked")
        .accessibilityIdentifier("chapterCard\(chapter.id)")
    }

    private var unlockedContent: some View {
        ZStack(alignment: .topLeading) {
            Text(style.decorations.joined(separator: "  "))
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(style.secondary.opacity(0.22))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(14)

            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.72))
                    Image(systemName: chapter.symbol).foregroundColor(style.primary)
                }
                .frame(width: 42, height: 42)

                Spacer(minLength: 0)

                Text("CHAPTER \(chapter.id)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(style.primary)
                Text(chapter.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(GameStyle.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                HStack {
                    Text("\(completed) / \(chapter.levelCount)")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(GameStyle.muted)
            }
            .padding(16)
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(GameStyle.muted.opacity(0.45))
            Text("CHAPTER \(chapter.id)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundColor(GameStyle.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The collectible grid shown after opening a chapter.
struct ChapterGalleryDetail: View {
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
                        GalleryCollectibleCard(
                            level: level,
                            collected: store.completedLevels.contains(level.id)
                        )
                    }
                }
                .padding(20)
            }
            .background(style.background.opacity(0.42).ignoresSafeArea())
            .navigationTitle(chapter.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

/// A chapter background section in the Journey map.
struct JourneyChapterBackdrop: View {
    let chapter: ChapterDefinition
    let locked: Bool

    private var style: ChapterThemeStyle { .style(for: chapter.theme) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 32)
                .fill(LinearGradient(
                    colors: [style.background.opacity(0.78), Color.white.opacity(0.30)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 32).stroke(style.primary.opacity(0.10)))

            HStack(spacing: 10) {
                Image(systemName: locked ? "lock.fill" : chapter.symbol)
                    .foregroundColor(style.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHAPTER \(chapter.id)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                    Text(chapter.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(GameStyle.ink)
            .padding(.horizontal, 22)
            .padding(.top, 18)

            Text(style.decorations.joined(separator: "   "))
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(style.secondary.opacity(0.20))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 22)
                .padding(.trailing, 20)
        }
        .opacity(locked ? 0.72 : 1)
        .accessibilityHidden(true)
    }
}
