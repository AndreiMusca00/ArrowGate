import SwiftUI

struct ContentLoadingView: View {
    let needsConnection: Bool
    let retry: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    private let messages = [
        "Fetching your levels",
        "Arranging every arrow",
        "Get ready to reveal the picture"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("PictarrowLaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 210, height: 210)
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                if needsConnection {
                    Text("Your levels are waiting")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(GameStyle.ink)

                    Text("Connect to the internet once to bring your next pictures to life.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(GameStyle.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)

                    Button(action: retry) {
                        Label("Try Again", systemImage: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(GameStyle.ink, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("contentRetry")
                    .padding(.top, 2)
                } else {
                    ArrowPaintLoader(animating: animating && !reduceMotion)
                        .frame(width: 112, height: 30)

                    TimelineView(.periodic(from: .now, by: 2.2)) { context in
                        let index = Int(context.date.timeIntervalSinceReferenceDate / 2.2) % messages.count
                        Text(messages[index])
                            .id(index)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(GameStyle.ink)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: index)
                    }

                    Text("The first setup may take a moment.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(GameStyle.muted)
                }
            }
            .frame(minHeight: 146, alignment: .top)

            Spacer()
            Spacer().frame(height: 48)
        }
        .padding(.horizontal, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GameStyle.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel(needsConnection ? "Connect to the internet to download levels" : "Fetching your levels")
        .accessibilityIdentifier("contentLoading")
        .onAppear { animating = true }
    }
}

private struct ArrowPaintLoader: View {
    let animating: Bool
    private let colors: [Color] = [
        Color(red: 0.87, green: 0.33, blue: 0.30),
        Color(red: 0.93, green: 0.62, blue: 0.15),
        Color(red: 0.13, green: 0.48, blue: 0.49),
        Color(red: 0.35, green: 0.24, blue: 0.52)
    ]

    var body: some View {
        HStack(spacing: 9) {
            ForEach(colors.indices, id: \.self) { index in
                Circle()
                    .fill(colors[index])
                    .frame(width: 9, height: 9)
                    .scaleEffect(animating ? 1.25 : 0.72)
                    .opacity(animating ? 1 : 0.42)
                    .offset(y: animating ? -3 : 3)
                    .animation(
                        animating
                            ? .easeInOut(duration: 0.72).repeatForever(autoreverses: true).delay(Double(index) * 0.13)
                            : nil,
                        value: animating
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
