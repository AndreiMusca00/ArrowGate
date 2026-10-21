import SwiftUI

struct GameEventVisualStyle {
    let primary: Color
    let secondary: Color
    let background: Color

    init(_ definition: GameEventStyleDefinition) {
        primary = Color(catalogHex: definition.primaryColor)
        secondary = Color(catalogHex: definition.secondaryColor)
        background = Color(catalogHex: definition.backgroundColor)
    }
}

struct HomeEventCard: View {
    let event: GameEventDefinition
    let progress: Int
    let date: Date

    private var style: GameEventVisualStyle { GameEventVisualStyle(event.style) }
    private var lifecycle: GameEventLifecycleState { event.lifecycle(at: date) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(backgroundGradient)
            EventFrameDecoration(kind: event.style.decoration, primary: style.primary, secondary: style.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.72))
                        Image(systemName: event.style.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(style.primary)
                    }
                    .frame(width: 38, height: 38)
                    Spacer(minLength: 8)
                    EventStatusPill(state: lifecycle, color: style.primary)
                }

                Spacer(minLength: 0)
                Text(event.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(GameStyle.ink)
                    .lineLimit(1)
                Text(event.subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(GameStyle.muted)
                    .lineLimit(1)

                footer
            }
            .padding(13)
        }
        .frame(width: 204, height: 142)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(style.primary.opacity(lifecycle == .ended ? 0.10 : 0.18), lineWidth: 1)
        )
        .opacity(lifecycle == .ended ? 0.72 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityIdentifier(event.id)
    }

    @ViewBuilder private var footer: some View {
        switch lifecycle {
        case .active:
            VStack(spacing: 4) {
                EventProgressBar(value: progress, goal: event.progress.goal, color: style.primary)
                HStack {
                    Text("\(progress) / \(event.progress.goal) \(event.progress.unitName)")
                    Spacer()
                    Text(timeText(to: event.endDate))
                }
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(GameStyle.muted)
            }
        case .comingSoon:
            Label(timeText(to: event.startDate), systemImage: "clock")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(style.primary)
        case .ended:
            Label(progress >= event.progress.goal ? "Reward collected" : "Saved in Events", systemImage: progress >= event.progress.goal ? "checkmark.circle.fill" : "archivebox.fill")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(GameStyle.muted)
        case .hidden:
            EmptyView()
        }
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: lifecycle == .ended
                ? [Color.white, GameStyle.background]
                : [style.background, Color.white.opacity(0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func timeText(to target: Date?) -> String {
        guard let target else { return "TODAY" }
        let interval = target.timeIntervalSince(date)
        guard interval > 0 else { return "ENDED" }
        let days = Int(ceil(interval / 86_400))
        if days > 1 { return lifecycle == .comingSoon ? "IN \(days) DAYS" : "\(days) DAYS LEFT" }
        let hours = max(1, Int(ceil(interval / 3_600)))
        return lifecycle == .comingSoon ? "IN \(hours)H" : "\(hours)H LEFT"
    }

    private var accessibilityDescription: String {
        "\(event.title), \(lifecycle == .active ? "active" : lifecycle == .comingSoon ? "coming soon" : "ended"), \(progress) of \(event.progress.goal)"
    }
}

struct EventStatusPill: View {
    let state: GameEventLifecycleState
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            if state == .active {
                Circle().fill(color).frame(width: 5, height: 5)
            }
            Text(title)
        }
        .font(.system(size: 8, weight: .bold, design: .rounded))
        .tracking(0.5)
        .foregroundStyle(state == .ended ? GameStyle.muted : color)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background((state == .ended ? GameStyle.muted : color).opacity(0.10), in: Capsule())
    }

    private var title: String {
        switch state {
        case .active: return "LIVE"
        case .comingSoon: return "SOON"
        case .ended: return "ENDED"
        case .hidden: return ""
        }
    }
}

struct EventProgressBar: View {
    let value: Int
    let goal: Int
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [color, color.opacity(0.62)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: 5)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: value)
    }

    private var fraction: CGFloat {
        guard goal > 0 else { return 0 }
        return min(1, max(0, CGFloat(value) / CGFloat(goal)))
    }
}

struct EventFrameDecoration: View {
    let kind: GameEventDecoration
    let primary: Color
    let secondary: Color

    var body: some View {
        GeometryReader { geometry in
            switch kind {
            case .orbitDots:
                orbitDots(in: geometry.size)
            case .spiderWeb:
                SpiderWebDecoration(primary: primary, secondary: secondary)
            case .fallingLeaves:
                leaves(in: geometry.size)
            case .none:
                Color.clear
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func orbitDots(in size: CGSize) -> some View {
        ZStack {
            Circle().fill(secondary.opacity(0.24)).frame(width: 9, height: 9).position(x: size.width - 23, y: size.height - 22)
            Circle().fill(primary.opacity(0.12)).frame(width: 20, height: 20).position(x: size.width - 38, y: size.height - 13)
            Circle().stroke(primary.opacity(0.10), lineWidth: 1).frame(width: 54, height: 54).position(x: size.width - 17, y: size.height - 5)
        }
    }

    private func leaves(in size: CGSize) -> some View {
        ZStack {
            Image(systemName: "leaf.fill").font(.system(size: 17)).foregroundStyle(primary.opacity(0.10)).rotationEffect(.degrees(-28)).position(x: size.width - 25, y: 25)
            Image(systemName: "leaf.fill").font(.system(size: 11)).foregroundStyle(secondary.opacity(0.13)).rotationEffect(.degrees(35)).position(x: size.width - 45, y: 47)
            Image(systemName: "leaf.fill").font(.system(size: 14)).foregroundStyle(primary.opacity(0.08)).rotationEffect(.degrees(62)).position(x: 28, y: size.height - 19)
        }
    }
}

private struct SpiderWebDecoration: View {
    let primary: Color
    let secondary: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let corner = CGPoint(x: size.width, y: 0)
            let radii: [CGFloat] = [23, 41, 61]
            for radius in radii {
                path.addArc(center: corner, radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            }
            for angle in stride(from: 95.0, through: 175.0, by: 20.0) {
                let radians = angle * .pi / 180
                path.move(to: corner)
                path.addLine(to: CGPoint(x: corner.x + 72 * cos(radians), y: corner.y + 72 * sin(radians)))
            }
            context.stroke(path, with: .color(primary.opacity(0.16)), lineWidth: 1)

            var thread = Path()
            thread.move(to: CGPoint(x: 0, y: size.height - 17))
            thread.addCurve(to: CGPoint(x: 42, y: size.height), control1: CGPoint(x: 15, y: size.height - 4), control2: CGPoint(x: 25, y: size.height + 2))
            context.stroke(thread, with: .color(secondary.opacity(0.13)), lineWidth: 1)
        }
    }
}
