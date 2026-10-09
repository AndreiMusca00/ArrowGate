import SwiftUI

struct JourneyView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: ProgressStore
    @State private var scrollTarget: String?

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

            GeometryReader { viewport in
                if #available(iOS 17.0, *) {
                    journeyScroll(viewportHeight: viewport.size.height)
                        .scrollPosition(id: $scrollTarget, anchor: .center)
                        .onAppear {
                            positionJourney(on: store.unlocked)
                        }
                        .onChange(of: state.homeScreen) { screen in
                            guard screen == .journey else { return }
                            positionJourney(on: store.unlocked)
                        }
                        .onChange(of: store.unlocked) { level in
                            guard state.homeScreen == .journey else { return }
                            positionJourney(on: level)
                        }
                } else {
                    ScrollViewReader { proxy in
                        journeyScroll(viewportHeight: viewport.size.height)
                            .onAppear {
                                centerJourney(on: store.unlocked, using: proxy)
                            }
                            .onChange(of: state.homeScreen) { screen in
                                guard screen == .journey else { return }
                                centerJourney(on: store.unlocked, using: proxy)
                            }
                            .onChange(of: store.unlocked) { level in
                                guard state.homeScreen == .journey else { return }
                                centerJourney(on: level, using: proxy)
                            }
                        }
                    }
                }
            }
        .background(GameStyle.background.ignoresSafeArea())
    }

    private func journeyScroll(viewportHeight: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Color.clear
                    .frame(height: centerInset(for: viewportHeight))

                JourneyMapView(store: store, current: current) { level in
                    if store.completedLevels.contains(level.id) {
                        state.selectCompletedLevel(level.id)
                    } else if level.id == store.unlocked {
                        state.play(level.id)
                    }
                }
                .padding(.vertical, 12)

                Color.clear
                    .frame(height: centerInset(for: viewportHeight))
            }
        }
    }

    private func centerInset(for viewportHeight: CGFloat) -> CGFloat {
        // JourneyMap keeps its first and last nodes 132 pt inside its bounds,
        // plus the 12 pt map padding applied above.
        max(0, viewportHeight / 2 - 144)
    }

    @available(iOS 17.0, *)
    private func positionJourney(on level: Int) {
        scrollTarget = nil
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.58)) {
                scrollTarget = "journey-level-\(level)"
            }
        }
    }

    private func centerJourney(on level: Int, using proxy: ScrollViewProxy) {
        // Wait until the page transition has settled, then visibly travel to
        // the exact point represented by the current level.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.46) {
            withAnimation(.easeInOut(duration: 0.58)) {
                proxy.scrollTo("journey-level-\(level)", anchor: .center)
            }
        }
    }
}
