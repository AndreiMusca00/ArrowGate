import SwiftUI

/// The shared navigation surface for the three home destinations.
/// On iOS 26 it uses the system Liquid Glass renderer. Older supported
/// versions receive a material-backed treatment with the same layout.
struct LiquidGlassNavBar: View {
    @Binding var selection: HomeScreen

    var body: some View {
        ZStack {
            glassSurface

            HStack(spacing: 0) {
                destinationButton(
                    title: "COLLECTION",
                    icon: "square.grid.2x2.fill",
                    selected: selection == .collection,
                    action: { navigate(to: .collection) }
                )
                .accessibilityIdentifier("collectionTab")

                destinationButton(
                    title: "HOME",
                    icon: "house.fill",
                    selected: selection == .menu,
                    action: { navigate(to: .menu) }
                )
                .accessibilityIdentifier("homeTab")

                destinationButton(
                    title: "SETTINGS",
                    icon: "gearshape.fill",
                    selected: selection == .settings,
                    action: { navigate(to: .settings) }
                )
                .accessibilityIdentifier("settingsTab")
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 70)
        .accessibilityElement(children: .contain)
    }

    private func destinationButton(title: String, icon: String, selected: Bool,
                                   action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(height: 22)
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.45)
            }
            .foregroundColor(selected ? GameStyle.accent : GameStyle.muted.opacity(0.72))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func navigate(to screen: HomeScreen) {
        guard selection != screen else { return }
        withAnimation(.easeInOut(duration: 0.38)) {
            selection = screen
        }
    }

    @ViewBuilder private var glassSurface: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.interactive(), in: Capsule())
                .overlay(glassHighlight)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(glassHighlight)
                .shadow(color: GameStyle.ink.opacity(0.08), radius: 18, y: 8)
        }
    }

    private var glassHighlight: some View {
        Capsule()
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.9), Color.white.opacity(0.28), Color.white.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}
