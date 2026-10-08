import SwiftUI

struct JourneyView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: ProgressStore

    private var completed: Int { store.completedLevels.count }
    private var current: Int? { completed == LevelRepository.count ? nil : store.unlocked }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                Text("JOURNEY")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("journeyMap")
                Text("\(completed) / \(LevelRepository.count)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(GameStyle.muted)
                ProgressView(value: Double(completed), total: Double(LevelRepository.count))
                    .tint(GameStyle.accent)
                    .frame(width: 154)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 92)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    JourneyMapView(store: store, current: current) { level in
                        state.play(level.id)
                    }
                        .padding(.vertical, 12)
                }
                .onAppear {
                    guard let current, current > 4 else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.45)) { proxy.scrollTo(current, anchor: .center) }
                    }
                }
            }
        }
        .background(GameStyle.background.ignoresSafeArea())
    }
}
