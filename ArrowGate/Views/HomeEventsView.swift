import SwiftUI

struct HomeEventsView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: ProgressStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let events = LevelRepository.events.filter { $0.appearsOnHome(at: timeline.date) }
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("EVENTS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                    Spacer()
                    Text(summary(events, at: timeline.date))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(GameStyle.muted)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(events) { event in
                            Button { state.openEvent(event) } label: {
                                HomeEventCard(event: event, progress: store.progress(for: event), date: timeline.date)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("openEvent-\(event.id)")
                            .disabled(event.lifecycle(at: timeline.date) != .active || LevelRepository.eventPuzzles(for: event.id).isEmpty)
                        }
                    }
                }
                .accessibilityIdentifier("homeEvents")
            }
        }
    }

    private func summary(_ events: [GameEventDefinition], at date: Date) -> String {
        let live = events.filter { $0.lifecycle(at: date) == .active }.count
        let upcoming = events.filter { $0.lifecycle(at: date) == .comingSoon }.count
        if live > 0 && upcoming > 0 { return "\(live) LIVE  ·  \(upcoming) SOON" }
        if live > 0 { return "\(live) LIVE" }
        if upcoming > 0 { return "\(upcoming) COMING SOON" }
        return "ARCHIVE"
    }
}
