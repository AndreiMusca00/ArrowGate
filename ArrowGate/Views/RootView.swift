import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        ZStack {
            GameStyle.background.ignoresSafeArea()
            if let game = state.game {
                GameScreen(model: game).id(ObjectIdentifier(game))
            } else {
                HomePagerView(store: state.progress)
            }
        }
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
struct IconButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 19, weight: .semibold))
            .frame(width: 48, height: 48).background(GameStyle.panel, in: RoundedRectangle(cornerRadius: 16)) }
        .buttonStyle(.plain).foregroundColor(GameStyle.ink).accessibilityLabel(label)
    }
}
struct MenuView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject var store: ProgressStore
    @State private var settings = false
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("A LITTLE ORDER. A BIG ESCAPE.").font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundColor(GameStyle.muted)
                Spacer(); IconButton(icon: "gearshape", label: "Settings") { settings = true } }

            HomeEventsView()
                .padding(.top, 14)

            Spacer(minLength: 12)
            HStack(spacing: 12) {
                ForEach(Array(ArrowColor.allCases.prefix(4).enumerated()), id: \.offset) { index, color in
                    Image(systemName: ["arrow.right", "arrow.up", "arrow.down", "arrow.left"][index])
                        .font(.system(size: 25, weight: .regular)).foregroundColor(GameStyle.color(color))
                        .frame(width: 49, height: 54).background(GameStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -8 : 8))
                }
            }.padding(.bottom, 18).accessibilityHidden(true)
            Text("ARROW GATE").font(.system(size: 44, weight: .bold, design: .rounded)).tracking(-1.5)
                .multilineTextAlignment(.center)
            Text("Clear a path. Match the color.").font(.system(size: 15, design: .rounded))
                .foregroundColor(GameStyle.muted).padding(.top, 8)
            Spacer(minLength: 16)
            VStack(spacing: 14) {
                HStack { Circle().fill(GameStyle.accent).frame(width: 6, height: 6)
                    Text("LEVEL \(store.unlocked) UNLOCKED").font(.system(size: 12, weight: .bold)).tracking(1.5) }.foregroundColor(GameStyle.muted)
                ActionButton(title: "PLAY", icon: "play.fill", primary: true) { state.play() }
                    .accessibilityIdentifier("play")
            }
            Spacer(minLength: 20)
        }.foregroundColor(GameStyle.ink).padding(.horizontal, 28).padding(.vertical, 16)
            .sheet(isPresented: $settings) { SettingsView(store: store) }
    }
}
struct SettingsView: View {
    @ObservedObject var store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var resetConfirmation = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") { Toggle("Sound", isOn: $store.sound); Toggle("Haptics", isOn: $store.haptics) }
                Section("Progress") {
                    Text("Unlocked level: \(store.unlocked) / 20")
                    Button("Reset Progress", role: .destructive) { resetConfirmation = true }
                }
            }.scrollContentBackground(.hidden).background(GameStyle.background)
                .navigationTitle("Settings").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Reset progress?", isPresented: $resetConfirmation, titleVisibility: .visible) {
                    Button("Reset Progress", role: .destructive) { store.reset() }
                }
        }.preferredColorScheme(.light)
    }
}
