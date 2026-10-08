import SwiftUI

/// The three home destinations behave like adjacent pages:
/// Journey sits to the left, Home in the middle, and Gallery to the right.
struct HomePagerView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: ProgressStore

    private var selection: Binding<HomeScreen> {
        Binding(
            get: { state.homeScreen },
            set: { state.show($0) }
        )
    }

    var body: some View {
        TabView(selection: selection) {
            JourneyView(store: store)
                .tag(HomeScreen.journey)

            MenuView(store: store)
                .tag(HomeScreen.menu)

            EmojiGalleryView(store: store)
                .tag(HomeScreen.gallery)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(GameStyle.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LiquidGlassNavBar(store: store, selection: state.homeScreen)
                .padding(.horizontal, 18)
                .padding(.bottom, 4)
        }
    }
}
