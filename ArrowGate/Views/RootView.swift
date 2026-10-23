import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @State private var showingIntro = !ProcessInfo.processInfo.arguments.contains("-skip-launch-intro")
    var body: some View {
        ZStack {
            GameStyle.background.ignoresSafeArea()
            if state.contentAvailability != .ready {
                ContentLoadingView(
                    needsConnection: state.contentAvailability == .needsConnection,
                    retry: state.retryContentLoading
                )
                .transition(.opacity)
            } else if let game = state.game {
                GameScreen(model: game)
                    .id(ObjectIdentifier(game))
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .scale(scale: 1.025))
                    ))
            } else if let eventID = state.selectedEventID, let event = LevelRepository.event(eventID) {
                EventLevelsView(event: event, store: state.progress)
            } else {
                HomePagerView(store: state.progress)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.32), value: state.contentAvailability)
        .animation(.easeInOut(duration: 0.42), value: state.game == nil)
        .overlay {
            if showingIntro {
                LaunchIntroView { showingIntro = false }
            }
        }
        .allowsHitTesting(!showingIntro)
    }
}
struct ActionButton: View {
    let title: String
    var icon: String? = nil
    var primary = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let icon { Image(systemName: icon) }
                Text(title).fontWeight(.bold)
            }.font(.system(size: 17, design: .rounded)).frame(maxWidth: .infinity).frame(height: 56)
                .foregroundColor(primary ? Color.white : GameStyle.ink)
                .background(primary ? GameStyle.accent : GameStyle.panel, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}
struct MenuView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: ProgressStore
    @State private var showingTestLevels = false
    @State private var pendingTestLevelID: Int?

    private var playLevel: LevelDefinition {
        let id = state.homeLevelNumber
        return store.savedLevels.first { $0.id == id }?.definition ?? LevelRepository.level(id)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("A LITTLE ORDER. A BIG ESCAPE.")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(GameStyle.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            if state.isContentPreview {
                HStack(spacing: 8) {
                    Text("LOCAL LEVEL PREVIEW")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color.orange.opacity(0.9))
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Color.orange.opacity(0.1), in: Capsule())

                    Spacer(minLength: 8)

                    Button {
                        showingTestLevels = true
                    } label: {
                        Label("TEST LEVELS", systemImage: "square.grid.3x3.fill")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .frame(height: 28)
                            .background(Color.orange, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("previewLevelPicker")
                }
                .padding(.top, 8)
            }

            HomeEventsView(store: store)
                .padding(.top, 14)

            Spacer(minLength: 12)
            Text("PICTARROW").font(.system(size: 44, weight: .bold, design: .rounded)).tracking(-1.5)
                .multilineTextAlignment(.center)
            Spacer(minLength: 16)
            HomePlayButton(level: playLevel) { state.play() }
            Spacer(minLength: 20)
        }
        .foregroundColor(GameStyle.ink)
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .sheet(isPresented: $showingTestLevels, onDismiss: openPendingTestLevel) {
            LocalLevelPicker(levels: LevelRepository.levels) { levelID in
                pendingTestLevelID = levelID
                showingTestLevels = false
            }
        }
    }

    private func openPendingTestLevel() {
        guard let levelID = pendingTestLevelID else { return }
        pendingTestLevelID = nil
        state.play(levelID)
    }
}
struct SettingsView: View {
    @ObservedObject var store: ProgressStore
    @State private var resetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("SETTINGS")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .accessibilityIdentifier("settingsPage")
                Text("Make Pictarrow feel like yours")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(GameStyle.muted)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 82)

            Form {
                Section("Feedback") { Toggle("Sound", isOn: $store.sound); Toggle("Haptics", isOn: $store.haptics) }
                Section("Progress") {
                    Text("Unlocked level: \(store.unlocked) / \(LevelRepository.count)")
                    LabeledContent("Hints", value: String(store.hints))
                    Button("Reset Progress", role: .destructive) { resetConfirmation = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GameStyle.background)
        }
        .background(GameStyle.background.ignoresSafeArea())
        .confirmationDialog("Reset progress?", isPresented: $resetConfirmation, titleVisibility: .visible) {
            Button("Reset Progress", role: .destructive) { store.reset() }
        }
        .preferredColorScheme(.light)
    }
}
