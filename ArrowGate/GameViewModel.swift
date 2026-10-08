import Foundation
import Combine
import SpriteKit

enum GamePhase { case playing, paused, won, lost }
enum LossReason { case hearts, timeout }
final class GameViewModel: ObservableObject {
    let level: LevelDefinition
    let scene: GameScene
    let timeLimit: TimeInterval
    @Published private(set) var remaining: [ArrowDefinition]
    @Published private(set) var hearts = GameStyle.startingHearts
    @Published private(set) var mistakes = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var hintsUsed = 0
    @Published private(set) var hintBalance: Int
    @Published private(set) var hintOfferVisible = false
    @Published private(set) var exiting: Set<Int> = []
    var animating: Bool { !exiting.isEmpty }
    @Published private(set) var lossReason: LossReason = .hearts
    @Published private(set) var phase: GamePhase = .playing { didSet {
        scene.inputEnabled = phase == .playing
    } }
    private let hintLimit: Int?
    private let idleHintDelay: TimeInterval
    private var tracker = MistakeTracker()
    private let store: ProgressStore
    private let feedback: AudioHapticsManager
    private var timer: AnyCancellable?
    private var lastTick = Date()
    private var lastProgressAt = Date()
    private var generation = 0
    var canRequestHint: Bool { phase == .playing && !remaining.isEmpty && (hintLimit.map { hintsUsed < $0 } ?? true) }
    var hasTimeLimit: Bool { timeLimit > 0 }
    var secondsRemaining: TimeInterval { max(0, timeLimit - elapsed) }
    init(level: LevelDefinition, store: ProgressStore, hintLimit: Int? = nil,
         timeLimit: TimeInterval? = nil, idleHintDelay: TimeInterval = 5) {
        self.hintLimit = hintLimit; self.idleHintDelay = idleHintDelay
        self.level = level; self.store = store; hintBalance = store.hints
        self.timeLimit = timeLimit ?? level.timeLimit
        remaining = level.arrows; feedback = AudioHapticsManager(store: store)
        scene = GameScene(size: GameStyle.sceneSize); scene.configure(level: level)
        scene.onTap = { [weak self] id in self?.tap(id) }
        timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().sink { [weak self] date in
            guard let self else { return }
            if self.phase == .playing && !self.scene.isIntroducing && !self.remaining.isEmpty {
                self.elapsed += date.timeIntervalSince(self.lastTick)
                if self.hasTimeLimit && self.secondsRemaining == 0 { self.lossReason = .timeout; self.phase = .lost }
                if self.canRequestHint && !self.hintOfferVisible && date.timeIntervalSince(self.lastProgressAt) >= self.idleHintDelay {
                    self.hintOfferVisible = true
                }
            } else if self.phase == .playing && self.scene.isIntroducing {
                self.lastProgressAt = date
            }
            self.lastTick = date
        }
        tutorialHint()
    }
    func tap(_ id: Int) {
        guard phase == .playing, hearts > 0, let arrow = remaining.first(where: { $0.id == id }) else { return }
        feedback.selected()
        let result = PuzzleRules.evaluate(arrow, remaining: remaining, level: level)
        let token = generation
        if result == .allowed {
            // Commit immediately so the next tap can use the newly freed path.
            hintOfferVisible = false
            lastProgressAt = Date()
            exiting.insert(id)
            remaining.removeAll { $0.id == id }
            scene.remove(arrow) { [weak self] in
                guard let self, self.generation == token else { return }
                self.exiting.remove(id)
                guard self.phase != .lost else { return }
                if self.remaining.isEmpty && self.exiting.isEmpty {
                    let finishTime = self.elapsed
                    self.scene.revealPainting { [weak self] in
                        guard let self, self.generation == token, self.phase == .playing else { return }
                        self.phase = .won
                        self.store.complete(self.level.id, time: finishTime)
                    }
                }
            }
            refreshWarnings()
            feedback.feedback(success: true)
            tutorialHint()
        } else {
            if tracker.register(arrowID: id) { mistakes += 1; hearts -= 1 }
            refreshWarnings()
            let fatal = hearts == 0
            scene.reject(arrow, remaining: remaining, onImpact: { [weak self] in
                guard let self, self.generation == token else { return }
                self.feedback.feedback(success: false)
            }, completion: { [weak self] in
                guard let self, self.generation == token, self.phase == .playing else { return }
                if fatal && self.hearts == 0 { self.lossReason = .hearts; self.phase = .lost }
            })
        }
    }
    private func refreshWarnings() {
        let blocked = Set(remaining.filter {
            tracker.penalized.contains($0.id) && PuzzleRules.evaluate($0, remaining: remaining, level: level) != .allowed
        }.map(\.id))
        scene.markBlocked(blocked)
    }
    func hint() {
        guard canRequestHint, let arrow = PuzzleRules.hint(remaining: remaining, level: level) else { return }
        if store.hints == 0 { rewardedHintDidComplete() }
        guard store.consumeHint() else { return }
        hintBalance = store.hints
        hintsUsed += 1
        hintOfferVisible = false
        lastProgressAt = Date()
        scene.highlight(arrow.id, tutorial: level.id == 1)
    }
    /// Rewarded-video providers can call this after playback completes.
    /// Until an ad provider is connected, the video action grants locally.
    func rewardedHintDidComplete() {
        store.grantHint()
        hintBalance = store.hints
    }
    func dismissHintOffer() {
        hintOfferVisible = false
        lastProgressAt = Date()
    }
    private func tutorialHint() {
        if level.id == 1, let arrow = PuzzleRules.hint(remaining: remaining, level: level) { scene.highlight(arrow.id, tutorial: true) }
    }
    func pause() { if phase == .playing { hintOfferVisible = false; phase = .paused } }
    func resume() { guard phase == .paused else { return }; lastTick = Date(); lastProgressAt = Date(); phase = .playing }
    func restart() {
        generation += 1; tracker.reset()
        remaining = level.arrows; hearts = GameStyle.startingHearts; mistakes = 0; elapsed = 0
        hintsUsed = 0; hintBalance = store.hints; hintOfferVisible = false
        exiting = []; lossReason = .hearts; lastTick = Date(); lastProgressAt = Date(); phase = .playing
        scene.isPaused = false; scene.configure(level: level); tutorialHint()
    }
    var formattedTime: String { hasTimeLimit ? format(TimeInterval(ceil(secondsRemaining))) : "∞" }
    var formattedElapsed: String { format(elapsed) }
    private func format(_ seconds: TimeInterval) -> String { String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}
