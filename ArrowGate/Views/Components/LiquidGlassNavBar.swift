import SwiftUI

/// The shared navigation surface for the three home destinations.
/// On iOS 26 it uses the system Liquid Glass renderer. Older supported
/// versions receive a material-backed treatment with the same layout.
struct LiquidGlassNavBar: View {
    @Binding var selection: HomeScreen

    var body: some View {
        ZStack(alignment: .top) {
            glassSurface
                .frame(height: 72)
                .padding(.top, 20)

            HStack(spacing: 0) {
                destinationButton(
                    title: "JOURNEY",
                    icon: "point.bottomleft.forward.to.point.topright.scurvepath",
                    selected: selection == .journey,
                    action: { navigate(to: .journey) }
                )
                .accessibilityIdentifier("journeyTab")

                Color.clear.frame(width: 92, height: 1)

                destinationButton(
                    title: "GALLERY",
                    icon: "face.smiling.inverse",
                    selected: selection == .gallery,
                    action: { navigate(to: .gallery) }
                )
                .accessibilityIdentifier("galleryTab")
            }
            .padding(.horizontal, 16)
            .padding(.top, 34)

            homeButton
        }
        .frame(height: 98)
        .accessibilityElement(children: .contain)
    }

    private var homeButton: some View {
        Button { navigate(to: .menu) } label: {
            VStack(spacing: 3) {
                ZStack {
                    homeSurface
                    Image(systemName: "house.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 64, height: 64)

                Text("HOME")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundColor(GameStyle.accent)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("Home")
        .accessibilityAddTraits(selection == .menu ? .isSelected : [])
        .accessibilityIdentifier("homeTab")
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

    @ViewBuilder private var homeSurface: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(GameStyle.accent).interactive(), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.52), lineWidth: 1))
                .shadow(color: GameStyle.accent.opacity(0.22), radius: 12, y: 5)
        } else {
            Circle()
                .fill(GameStyle.accent)
                .overlay(
                    Circle().fill(
                        LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                )
                .overlay(Circle().stroke(Color.white.opacity(0.58), lineWidth: 1))
                .shadow(color: GameStyle.accent.opacity(0.24), radius: 12, y: 5)
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
