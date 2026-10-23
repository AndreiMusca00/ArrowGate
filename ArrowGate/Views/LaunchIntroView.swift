import SwiftUI

/// Continue the static launch screen, then gently reveal the home screen.
struct LaunchIntroView: View {
    let finished: () -> Void
    @State private var fading = false

    var body: some View {
        ZStack {
            Color(red: 0.99, green: 0.98, blue: 0.95)
            Image("PictarrowLaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(fading ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pictarrow is starting")
        .accessibilityIdentifier("launchIntro")
        .task {
            do {
                try await Task.sleep(nanoseconds: 450_000_000)
                withAnimation(.easeOut(duration: 0.25)) { fading = true }
                try await Task.sleep(nanoseconds: 250_000_000)
                finished()
            } catch { /* The launch view was dismissed. */ }
        }
    }
}
