import SwiftUI

/// The three home destinations behave like adjacent pages:
/// Collection sits to the left, Home in the middle, and Settings to the right.
struct HomePagerView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: ProgressStore
    @State private var selectedCollectionChapter: ChapterDefinition?

    private var selection: Binding<HomeScreen> {
        Binding(
            get: { state.homeScreen },
            set: { state.show($0) }
        )
    }

    var body: some View {
        ZStack {
            TabView(selection: selection) {
                CollectionView(store: store, selectedChapter: $selectedCollectionChapter)
                    .tag(HomeScreen.collection)

                MenuView(store: store)
                    .tag(HomeScreen.menu)

                SettingsView(store: store)
                    .tag(HomeScreen.settings)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.38), value: state.homeScreen)
            .background(GameStyle.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LiquidGlassNavBar(selection: selection)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 4)
            }
            .blur(radius: selectedCollectionChapter == nil ? 0 : 5)
            .scaleEffect(selectedCollectionChapter == nil ? 1 : 0.992)
            .allowsHitTesting(selectedCollectionChapter == nil)
            .accessibilityHidden(selectedCollectionChapter != nil)
            .animation(.easeOut(duration: 0.24), value: selectedCollectionChapter?.id)

            if let chapter = selectedCollectionChapter, let assembly = chapter.assembly {
                CollectionArtworkOverlay(
                    chapter: chapter,
                    assembly: assembly,
                    store: store,
                    close: closeCollectionArtwork
                )
                .zIndex(10)
            }
        }
        .background(GameStyle.background.ignoresSafeArea())
    }

    private func closeCollectionArtwork() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
            selectedCollectionChapter = nil
        }
    }
}
