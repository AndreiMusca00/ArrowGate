import SwiftUI

/// Reveal each piece after completion and unlock puzzles in calendar order.
struct EventLevelsView: View {
    @EnvironmentObject private var state: AppState
    let event: GameEventDefinition
    @ObservedObject var store: ProgressStore
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private var style: GameEventVisualStyle { GameEventVisualStyle(event.style) }
    private var puzzles: [EventPuzzleDefinition] { LevelRepository.eventPuzzles(for: event.id) }
    private var artworkRevealed: Bool {
        !puzzles.isEmpty && puzzles.allSatisfy { store.completedEventLevels[event.id, default: []].contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MinimalIconButton(icon: "chevron.left", label: "Back") { state.closeEvent() }
                Spacer()
                Text(event.title).font(.system(size: 22, weight: .bold, design: .rounded))
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            ScrollView {
                VStack(spacing: 16) {
                    if artworkRevealed, let artwork = event.reward.assetName {
                        Image(artwork).resizable().scaledToFit().frame(height: 165)
                            .accessibilityLabel(event.reward.title)
                            .accessibilityIdentifier("eventFinalArtwork")
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "gift.fill").font(.system(size: 48))
                            Text("Complete every challenge to reveal your reward")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(style.primary)
                        .frame(maxWidth: .infinity).frame(height: 165)
                        .background(style.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityIdentifier("eventHiddenArtwork")
                    }
                    Text("NOVEMBER 2026")
                        .font(.system(size: 12, weight: .bold, design: .rounded)).tracking(1)
                        .foregroundStyle(style.primary)
                    Text("Complete each challenge to unlock the next and reveal its picture.")
                        .font(.system(size: 13, design: .rounded)).foregroundStyle(GameStyle.muted)
                        .multilineTextAlignment(.center)
                    if event.schedule.testingStartsAt != nil, Date() < (event.startDate ?? .distantPast) {
                        Text("Preview access is open for testing")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(style.primary)
                    }
                    EventProgressBar(value: store.progress(for: event), goal: event.progress.goal, color: style.primary)
                    Text("\(store.progress(for: event)) / \(event.progress.goal) completed")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(GameStyle.muted)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(puzzles) { puzzle in
                            dayButton(puzzle)
                        }
                    }
                }
                .padding(20)
            }
            .accessibilityIdentifier("eventLevelList")
        }
        .background(style.background.opacity(0.4).ignoresSafeArea())
    }

    private func dayButton(_ puzzle: EventPuzzleDefinition) -> some View {
        let completed = store.completedEventLevels[event.id, default: []].contains(puzzle.id)
        let unlocked = store.isEventLevelUnlocked(event.id, levelID: puzzle.id)
        return Button { state.playEvent(event.id, day: puzzle.day) } label: {
            VStack(spacing: 7) {
                if completed, let asset = puzzle.level.completionArtwork {
                    Image(asset).resizable().scaledToFit().frame(height: 48)
                        .accessibilityIdentifier("eventPieceArtwork\(puzzle.day)")
                } else {
                    Image(systemName: unlocked ? "questionmark" : "lock.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(style.primary.opacity(unlocked ? 0.8 : 0.4))
                        .frame(height: 48)
                }
                Text("NOV \(puzzle.day)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Label(completed ? "Completed" : (unlocked ? "Nightmare" : "Locked"), systemImage: completed ? "checkmark.circle.fill" : (unlocked ? "flame.fill" : "lock.fill"))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(completed ? style.primary : style.secondary)
            }
            .foregroundStyle(GameStyle.ink)
            .frame(maxWidth: .infinity).frame(height: 112)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(style.primary.opacity(completed ? 0.35 : 0.12)))
        }
        .buttonStyle(.plain)
        .disabled(event.lifecycle() != .active || !unlocked)
        .accessibilityLabel("November \(puzzle.day), \(completed ? "completed" : (unlocked ? "nightmare challenge" : "locked"))")
        .accessibilityIdentifier("\(event.id)Day\(puzzle.day)")
    }
}
