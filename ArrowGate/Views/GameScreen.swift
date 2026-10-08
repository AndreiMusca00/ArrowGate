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
                    Label(model.formattedTime, systemImage: "clock")
                        .font(.system(size: 17, weight: .medium, design: .rounded)).monospacedDigit()
                        .foregroundColor(model.hasTimeLimit && model.secondsRemaining <= 15 ? GameStyle.color(.red) : GameStyle.muted)
                        .accessibilityIdentifier("countdown")
                    HStack(spacing: 5) {
                        ForEach(0..<GameStyle.startingHearts, id: \.self) { index in
                            Image(systemName: index < model.hearts ? "heart.fill" : "heart")
                                .foregroundColor(index < model.hearts ? GameStyle.color(.red) : GameStyle.muted.opacity(0.35))
                        }
                    }.font(.system(size: 12))
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
                    .padding(.top, 78)
                    .padding(.trailing, 12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.32), value: model.hintOfferVisible)
        .overlay {
            Group { if model.phase != .playing { overlay } }
                .allowsHitTesting(model.phase != .playing)
        }
        .onChange(of: appPhase) { phase in if phase != .active { model.pause() } }
    }
    private var overlay: some View {
        ZStack {
            GameStyle.background.opacity(0.90).ignoresSafeArea()
            VStack(spacing: 18) {
                if model.phase == .won,
                   model.level.completionArtwork != nil || model.level.rewardEmoji != nil {
                    LevelRewardView(level: model.level, size: 116)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: model.phase == .won ? "checkmark.seal.fill" : model.phase == .lost ? "heart.slash.fill" : "pause.circle.fill")
                        .font(.system(size: 58)).foregroundColor(model.phase == .lost ? GameStyle.color(.red) : GameStyle.accent)
                }
                if model.phase == .paused, let difficulty = model.level.difficulty {
                    Text("Level \(String(model.level.id)) · \(difficulty.title)").foregroundColor(GameStyle.muted)
                }
                Text(model.phase == .won ? (model.level.id == LevelRepository.count ? "Gallery complete!" : "Picture complete!") : model.phase == .lost ? (model.lossReason == .timeout ? "Time is up" : "Try a new path") : "Take a breath")
                    .font(.system(size: 28, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                if model.phase == .won {
                    Text("\(model.formattedElapsed)  ·  \(model.mistakes) mistakes").foregroundColor(GameStyle.muted)
                    if model.level.id < LevelRepository.count {
                        ActionButton(title: "Next level", icon: "arrow.right", primary: true) {
                            state.play(model.level.id + 1)
                        }
                        .accessibilityIdentifier("nextLevel")
                    } else {
                        if model.level.id == LevelRepository.count { Text("20 / 20 puzzles complete").foregroundColor(GameStyle.muted) }
                        ActionButton(title: "Open gallery", icon: "square.grid.2x2", primary: true) { state.showGallery() }
                    }
                    ActionButton(title: "Play again", icon: "arrow.counterclockwise") { model.restart() }
                } else if model.phase == .paused {
                    ActionButton(title: "Continue", icon: "play.fill", primary: true) { model.resume() }
                    ActionButton(
                        title: model.hintBalance > 0 ? "Hint · \(model.hintBalance)" : "Watch for hint",
                        icon: model.hintBalance > 0 ? "lightbulb" : "play.rectangle.fill"
                    ) { model.resume(); model.hint() }
                    .accessibilityIdentifier("hint")
                    ActionButton(title: "Restart", icon: "arrow.counterclockwise") { model.restart() }.accessibilityIdentifier("pauseRestart")
                } else {
                    Text(model.lossReason == .timeout ? "A fresh start. A clearer path." : "Three hearts. A fresh start.").foregroundColor(GameStyle.muted)
                    ActionButton(title: "Try again", icon: "arrow.counterclockwise", primary: true) { model.restart() }
                }
                if !(model.phase == .won && model.level.id >= LevelRepository.count) {
                    Button("Main menu") { state.menu() }.font(.system(size: 16, weight: .semibold)).foregroundColor(GameStyle.muted).padding(10)
                }
            }.foregroundColor(GameStyle.ink).padding(26).background(GameStyle.panel, in: RoundedRectangle(cornerRadius: 28)).padding(24)
        }
    }
}

private struct HintOfferView: View {
    @ObservedObject var model: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(GameStyle.color(.yellow).opacity(0.14))
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(GameStyle.color(.yellow))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Need a hint?")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("hintOffer")
                    Text(model.hintBalance > 0 ? "\(model.hintBalance) available" : "Reveal one with a video")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(GameStyle.muted)
                }

                Spacer(minLength: 4)
                Button(action: model.dismissHintOffer) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundColor(GameStyle.muted)
                .accessibilityLabel("Dismiss hint")
            }

            Button(action: model.hint) {
                HStack(spacing: 7) {
                    Image(systemName: model.hintBalance > 0 ? "lightbulb.fill" : "play.rectangle.fill")
                    Text(model.hintBalance > 0 ? "USE HINT · \(model.hintBalance)" : "WATCH FOR HINT")
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(GameStyle.accent, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.hintBalance > 0 ? "Use hint, \(model.hintBalance) available" : "Watch video for hint")
            .accessibilityIdentifier("idleHint")
        }
        .foregroundColor(GameStyle.ink)
        .padding(12)
        .frame(width: 214)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.8), lineWidth: 1))
        .shadow(color: GameStyle.ink.opacity(0.12), radius: 16, y: 7)
    }
}

struct LevelRewardView: View {
    let level: LevelDefinition
    let size: CGFloat
    var body: some View {
        Group {
            if let artwork = level.completionArtwork {
                Image(artwork).resizable().scaledToFit()
            } else {
                Text(level.rewardEmoji ?? "✨")
                    .font(.system(size: size * 0.78))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
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
