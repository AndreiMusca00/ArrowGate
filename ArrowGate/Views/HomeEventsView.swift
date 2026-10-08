import SwiftUI

struct HomeEventsView: View {
    private let events: [HomeEvent] = [
        HomeEvent(
            id: "eventDailySprint",
            title: "Daily Sprint",
            subtitle: "Beat today's clock",
            badge: "TODAY",
            icon: "timer",
            color: GameStyle.accent
        ),
        HomeEvent(
            id: "eventHalloween",
            title: "Halloween Night",
            subtitle: "12 spooky puzzles",
            badge: "LIMITED",
            emoji: "🎃",
            color: Color(red: 0.83, green: 0.39, blue: 0.08)
        ),
        HomeEvent(
            id: "eventSpeedRun",
            title: "Speed Run",
            subtitle: "Three rapid levels",
            badge: "WEEKLY",
            icon: "bolt.fill",
            color: GameStyle.color(.red)
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("EVENTS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                Spacer()
                Text("3 ACTIVE")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(GameStyle.muted)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(events) { event in
                        HomeEventCard(event: event)
                    }
                }
            }
            .accessibilityIdentifier("homeEvents")
        }
    }
}

private struct HomeEvent: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let badge: String
    var icon: String? = nil
    var emoji: String? = nil
    let color: Color

}

private struct HomeEventCard: View {
    let event: HomeEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().fill(event.color.opacity(0.12))
                    if let emoji = event.emoji {
                        Text(emoji).font(.system(size: 21))
                    } else if let icon = event.icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(event.color)
                    }
                }
                .frame(width: 38, height: 38)

                Spacer(minLength: 8)

                Text(event.badge)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .foregroundColor(event.color)
                    .padding(.horizontal, 7)
                    .frame(height: 21)
                    .background(event.color.opacity(0.09), in: Capsule())
            }

            Text(event.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(GameStyle.ink)
                .lineLimit(1)
            Text(event.subtitle)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(GameStyle.muted)
                .lineLimit(1)
        }
        .padding(13)
        .frame(width: 172, height: 112, alignment: .topLeading)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(event.color.opacity(0.13), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title), \(event.subtitle), \(event.badge)")
        .accessibilityIdentifier(event.id)
    }
}
