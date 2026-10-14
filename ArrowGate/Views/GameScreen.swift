import SwiftUI
import SpriteKit

struct GameScreen: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.scenePhase) private var appPhase
    @ObservedObject var model: GameViewModel
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 0) {
                    MinimalIconButton(icon: "chevron.left", label: "Back") { state.menu() }.accessibilityIdentifier("back")
                    Spacer()
                    MinimalIconButton(icon: "arrow.counterclockwise", label: "Restart") { model.restart() }.accessibilityIdentifier("restart")
                    MinimalIconButton(icon: "pause.fill", label: "Pause") { model.pause() }.accessibilityIdentifier("pause")
                }
                VStack(spacing: 6) {
                    if model.hasTimeLimit {
                        Label(model.formattedTime, systemImage: "clock")
                            .font(.system(size: 17, weight: .medium, design: .rounded)).monospacedDigit()
                            .foregroundColor(model.secondsRemaining <= 15 ? GameStyle.color(.red) : GameStyle.muted)
                            .accessibilityIdentifier("countdown")
                    }
                    HStack(spacing: 5) {
                        ForEach(0..<GameStyle.startingHearts, id: \.self) { index in
                            Image(systemName: index < model.hearts ? "heart.fill" : "heart")
                                .foregroundColor(index < model.hearts ? GameStyle.color(.red) : GameStyle.muted.opacity(0.35))
                        }
                    }
                    .font(.system(size: 13))
                    .accessibilityElement(children: .ignore).accessibilityLabel("Lives")
                    .accessibilityValue(String(model.hearts)).accessibilityIdentifier("lives")
                }.allowsHitTesting(false)
            }.frame(height: 66).padding(.horizontal, 12)
            PuzzleBoardView(scene: model.scene, paused: model.phase == .paused)
                .clipped().accessibilityIdentifier("board")
        }
        .accessibilityElement(children: .contain)
        .overlay(alignment: .topTrailing) {
            if model.phase == .playing && model.hintOfferVisible {
                HintOfferView(model: model)
                    .padding(.top, 82)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.32), value: model.hintOfferVisible)
        .overlay {
            Group {
                if model.phase == .paused || model.phase == .lost { overlay }
            }
            .allowsHitTesting(model.phase == .paused || model.phase == .lost)
        }
        .onChange(of: appPhase) { phase in if phase != .active { model.pause() } }
        .onChange(of: model.phase) { phase in
            if phase == .won {
                state.attemptEnded(model)
                withAnimation(.easeInOut(duration: 0.42)) {
                    state.menu()
                }
            } else if phase == .lost {
                state.attemptEnded(model)
            }
        }
    }
    private var overlay: some View {
        ZStack {
            GameStyle.background.opacity(0.90).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: model.phase == .lost ? "heart.slash.fill" : "pause.circle.fill")
                    .font(.system(size: 58)).foregroundColor(model.phase == .lost ? GameStyle.color(.red) : GameStyle.accent)
                if model.phase == .paused, let difficulty = model.level.difficulty {
                    Text("Level \(String(model.level.id)) · \(difficulty.title)").foregroundColor(GameStyle.muted)
                }
                Text(model.phase == .lost ? (model.lossReason == .timeout ? "Time is up" : "Try a new path") : "Take a breath")
                    .font(.system(size: 28, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                if model.phase == .paused {
                    ActionButton(title: "Continue", icon: "play.fill", primary: true) { model.resume() }
                    ActionButton(
                        title: model.hintBalance > 0 ? "Hint · \(model.hintBalance)" : "Watch for hint",
                        icon: model.hintBalance > 0 ? "lightbulb" : "play.rectangle.fill"
                    ) { model.resume(); model.hint() }
                    .accessibilityIdentifier("hint")
                    ActionButton(title: "Restart", icon: "arrow.counterclockwise") { model.restart() }.accessibilityIdentifier("pauseRestart")
                } else {
                    Text("Try again with three lives.").foregroundColor(GameStyle.muted)
                    ActionButton(title: "Retry", icon: "arrow.counterclockwise", primary: true) {
                        model.retryAfterLoss()
                    }
                    .accessibilityIdentifier("retryLevel")
                }
                Button("Main menu") { state.menu() }.font(.system(size: 16, weight: .semibold)).foregroundColor(GameStyle.muted).padding(10)
            }.foregroundColor(GameStyle.ink).padding(26).background(GameStyle.panel, in: RoundedRectangle(cornerRadius: 28)).padding(24)
        }
    }
}

private struct HintOfferView: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        Button(action: model.hint) {
            HStack(spacing: 7) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(GameStyle.color(.yellow))
                if model.hintBalance > 0 {
                    Text(String(model.hintBalance))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(GameStyle.ink)
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GameStyle.accent)
                }
            }
            .frame(minWidth: model.hintBalance > 0 ? 58 : 66, minHeight: 42)
            .padding(.leading, 4)
            .contentShape(EdgeHintShape())
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: EdgeHintShape())
        .overlay(EdgeHintShape().stroke(Color.white.opacity(0.82), lineWidth: 1))
        .shadow(color: GameStyle.ink.opacity(0.13), radius: 10, x: -3, y: 4)
        .accessibilityLabel(model.hintBalance > 0 ? "Use hint, \(model.hintBalance) available" : "Watch video for hint")
        .accessibilityIdentifier("idleHint")
    }
}

/// Rounded only on the side entering the screen, so the control feels attached
/// to the right edge instead of floating like a card.
private struct EdgeHintShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(18, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + radius),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.maxY),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct MinimalIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 21, weight: .medium))
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundColor(GameStyle.ink)
            .accessibilityLabel(label)
    }
}
