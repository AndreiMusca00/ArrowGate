import SwiftUI

struct CollectionView: View {
    @ObservedObject var store: ProgressStore
    @Binding var selectedChapter: ChapterDefinition?
    @State private var section: CollectionSection = .chapters
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("COLLECTION")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("collectionPage")
                CollectionSectionPicker(selection: $section)
            }
            .frame(maxWidth: .infinity).frame(height: 112)

            if section == .chapters {
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
            } else {
                EventCollectionView(store: store)
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

private enum CollectionSection: String, CaseIterable {
    case chapters = "CHAPTERS"
    case events = "EVENTS"
}

private struct CollectionSectionPicker: View {
    @Binding var selection: CollectionSection

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CollectionSection.allCases, id: \.self) { section in
                Button {
                    withAnimation(.easeInOut(duration: 0.24)) { selection = section }
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(selection == section ? GameStyle.ink : GameStyle.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(selection == section ? Color.white : Color.clear, in: Capsule())
                        .shadow(color: selection == section ? GameStyle.ink.opacity(0.06) : .clear, radius: 5, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(section == .events ? "collectionEventsTab" : "collectionChaptersTab")
            }
        }
        .padding(3)
        .frame(width: 224)
        .background(GameStyle.ink.opacity(0.055), in: Capsule())
    }
}

private struct EventCollectionView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: ProgressStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(LevelRepository.events.filter { $0.lifecycle() != .ended || store.progress(for: $0) > 0 }) { event in
                    if event.kind == .dailyChallenge {
                        MonthlyTrophyCard(event: event, store: store)
                    } else {
                        Button { state.openEvent(event) } label: {
                            SeasonalEventCollectionCard(event: event, progress: store.progress(for: event))
                        }
                        .buttonStyle(.plain)
                        .disabled(event.lifecycle() != .active || LevelRepository.eventPuzzles(for: event.id).isEmpty)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 98)
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .accessibilityIdentifier("eventsCollection")
    }
}

private struct MonthlyTrophyCard: View {
    let event: GameEventDefinition
    @ObservedObject var store: ProgressStore
    private let calendar = Calendar.current

    private var style: GameEventVisualStyle { GameEventVisualStyle(event.style) }
    private var currentMonth: Int { calendar.component(.month, from: Date()) }
    private var currentYear: Int { calendar.component(.year, from: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(style.primary.opacity(0.11))
                    Image(systemName: event.reward.systemSymbol)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(style.primary)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("DAILY TROPHIES")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(style.primary)
                    Text(verbatim: "\(currentYear) Collection")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(GameStyle.ink)
                    Text("A new trophy every month")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(GameStyle.muted)
                }
                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 6), spacing: 10) {
                ForEach(1...12, id: \.self) { month in
                    monthBadge(month)
                }
            }

            VStack(spacing: 5) {
                EventProgressBar(value: store.progress(for: event), goal: event.progress.goal, color: style.primary)
                HStack {
                    Text(monthName(currentMonth))
                    Spacer()
                    Text("\(store.progress(for: event)) / \(event.progress.goal) days")
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(GameStyle.muted)
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [style.background, Color.white], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(EventFrameDecoration(kind: event.style.decoration, primary: style.primary, secondary: style.secondary).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous)))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(style.primary.opacity(0.13)))
    }

    private func monthBadge(_ month: Int) -> some View {
        let key = String(format: "%04d-%02d", currentYear, month)
        let collected = store.hasTrophy(for: event, monthKey: key)
        let current = month == currentMonth
        return VStack(spacing: 4) {
            ZStack {
                Circle().fill(collected ? style.secondary.opacity(0.18) : Color.white.opacity(0.76))
                Circle().stroke(current ? style.primary : style.primary.opacity(0.08), lineWidth: current ? 2 : 1)
                Image(systemName: collected ? "trophy.fill" : month > currentMonth ? "lock.fill" : "trophy")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(collected ? style.secondary : GameStyle.muted.opacity(month > currentMonth ? 0.25 : 0.42))
            }
            .frame(width: 35, height: 35)
            Text(shortMonthName(month))
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(current ? style.primary : GameStyle.muted)
        }
    }

    private func monthName(_ month: Int) -> String {
        DateFormatter().monthSymbols[max(0, min(month - 1, 11))]
    }

    private func shortMonthName(_ month: Int) -> String {
        String(DateFormatter().shortMonthSymbols[max(0, min(month - 1, 11))].prefix(3)).uppercased()
    }
}

private struct SeasonalEventCollectionCard: View {
    let event: GameEventDefinition
    let progress: Int
    private var style: GameEventVisualStyle { GameEventVisualStyle(event.style) }
    private var lifecycle: GameEventLifecycleState { event.lifecycle() }

    var body: some View {
        HStack(spacing: 18) {
            EventRewardArtwork(event: event, progress: progress)
                .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 7) {
                EventStatusPill(state: lifecycle, color: style.primary)
                Text(event.reward.title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(GameStyle.ink)
                Text(event.reward.subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(GameStyle.muted)
                    .lineLimit(2)
                EventProgressBar(value: progress, goal: event.progress.goal, color: style.primary)
                Text("\(progress) / \(event.progress.goal) pieces")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(GameStyle.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(17)
        .frame(maxWidth: .infinity, minHeight: 146)
        .background(
            LinearGradient(colors: [style.background, Color.white], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(EventFrameDecoration(kind: event.style.decoration, primary: style.primary, secondary: style.secondary).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous)))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(style.primary.opacity(0.13)))
        .opacity(lifecycle == .ended && progress == 0 ? 0.70 : 1)
    }
}

private struct EventRewardArtwork: View {
    let event: GameEventDefinition
    let progress: Int
    private var style: GameEventVisualStyle { GameEventVisualStyle(event.style) }
    private var fraction: CGFloat { min(1, max(0, CGFloat(progress) / CGFloat(event.reward.pieceCount))) }

    private var rewardImage: Image {
        if let asset = event.reward.assetName { return ContentAssetRegistry.image(named: asset) }
        return Image(systemName: event.reward.systemSymbol)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.72))
            rewardImage
                .resizable()
                .scaledToFit()
                .padding(24)
                .foregroundStyle(style.primary.opacity(0.13))
                .opacity(event.reward.assetName == nil ? 1 : 0.12)
            GeometryReader { geometry in
                rewardImage
                    .resizable()
                    .scaledToFit()
                    .padding(24)
                    .foregroundStyle(LinearGradient(colors: [style.secondary, style.primary], startPoint: .top, endPoint: .bottom))
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: geometry.size.height * fraction)
                    }
            }
            if event.lifecycle() == .comingSoon {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(style.primary)
                    .padding(7)
                    .background(.white.opacity(0.9), in: Circle())
                    .offset(x: 35, y: 35)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(style.primary.opacity(0.10)))
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
