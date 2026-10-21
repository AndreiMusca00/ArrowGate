import Foundation
import Combine
import SpriteKit

enum GamePhase { case playing, paused, won, lost }
enum LossReason { case hearts, timeout }
final class GameViewModel: ObservableObject {
    let level: LevelDefinition
    let eventID: String?
    let isReplay: Bool
    let scene: GameScene
    let timeLimit: TimeInterval
    @Published private(set) var remaining: [ArrowDefinition]
    @Published private(set) var hearts = GameStyle.startingHearts
    @Published private(set) var mistakes = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var hintsUsed = 0
    @Published private(set) var hintBalance: Int
    @Published private(set) var earnedReward: LevelCompletionReward?
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
    private var removedArrowIDs: [Int] = []
    private let store: ProgressStore
    private let feedback: AudioHapticsManager
    private var timer: AnyCancellable?
    private var pendingSessionSave: DispatchWorkItem?
    private var lastTick = Date()
    private var lastProgressAt = Date()
    private var generation = 0
    var canRequestHint: Bool { phase == .playing && !remaining.isEmpty && (hintLimit.map { hintsUsed < $0 } ?? true) }
    var hasTimeLimit: Bool { timeLimit > 0 }
    var secondsRemaining: TimeInterval { max(0, timeLimit - elapsed) }
    init(level: LevelDefinition, store: ProgressStore, isReplay: Bool = false, hintLimit: Int? = nil,
         timeLimit: TimeInterval? = nil, idleHintDelay: TimeInterval = 10,
         session: LevelSessionSnapshot? = nil, eventID: String? = nil) {
        let restored = !isReplay && session?.isValid(for: level) == true ? session : nil
        self.hintLimit = hintLimit; self.idleHintDelay = idleHintDelay
        self.level = level; self.eventID = eventID; self.isReplay = isReplay; self.store = store
        hintBalance = store.hints
        self.timeLimit = timeLimit ?? level.timeLimit
        removedArrowIDs = restored?.removedArrowIDs ?? []
        let removed = Set(removedArrowIDs)
        remaining = level.arrows.filter { !removed.contains($0.id) }
        hearts = restored?.hearts ?? GameStyle.startingHearts
        mistakes = restored?.mistakes ?? 0
        elapsed = restored?.elapsed ?? 0
        hintsUsed = restored?.hintsUsed ?? 0
        tracker = MistakeTracker(penalized: restored?.penalizedArrowIDs ?? [])
        feedback = AudioHapticsManager(store: store)
        scene = GameScene(size: GameStyle.sceneSize); scene.configure(level: level)
        if let restored { scene.restoreSession(removedArrowIDs: restored.removedArrowIDs) }
        scene.onTap = { [weak self] id in self?.tap(id) }
        timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().sink { [weak self] date in
            guard let self else { return }
            if self.phase == .playing && !self.scene.isIntroducing && !self.remaining.isEmpty {
                self.elapsed += date.timeIntervalSince(self.lastTick)
                if self.hasTimeLimit && self.secondsRemaining == 0 {
                    self.lossReason = .timeout
                    self.pendingSessionSave?.cancel()
                    self.store.clearSession(levelID: self.level.id)
                    self.phase = .lost
                }
                if self.canRequestHint && !self.hintOfferVisible && date.timeIntervalSince(self.lastProgressAt) >= self.idleHintDelay {
                    self.hintOfferVisible = true
                }
            } else if self.phase == .playing && self.scene.isIntroducing {
                self.lastProgressAt = date
            }
            self.lastTick = date
        }
        refreshWarnings()
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
            removedArrowIDs.append(id)
            if !remaining.isEmpty { scheduleSessionPersistence() }
            scene.remove(arrow) { [weak self] in
                guard let self, self.generation == token else { return }
                self.exiting.remove(id)
                guard self.phase != .lost else { return }
                if self.remaining.isEmpty && self.exiting.isEmpty {
                    let finishTime = self.elapsed
                    self.scene.revealPainting { [weak self] in
                        guard let self, self.generation == token, self.phase == .playing else { return }
                        self.pendingSessionSave?.cancel()
                        if let eventID = self.eventID {
                            self.store.completeEventLevel(eventID, levelID: self.level.id)
                            self.earnedReward = nil
                        } else {
                            self.earnedReward = self.store.complete(self.level.id, time: finishTime)
                        }
                        self.hintBalance = self.store.hints
                        self.phase = .won
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
            if fatal {
                pendingSessionSave?.cancel()
                store.clearSession(levelID: level.id)
            } else {
                scheduleSessionPersistence()
            }
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
        scheduleSessionPersistence()
    }
    /// Rewarded-video providers can call this after playback completes.
    /// Until an ad provider is connected, the video action grants locally.
    func rewardedHintDidComplete() {
        store.grantHint()
        hintBalance = store.hints
    }
    private func tutorialHint() {
        if level.id == 1, let arrow = PuzzleRules.hint(remaining: remaining, level: level) { scene.highlight(arrow.id, tutorial: true) }
    }
    func pause() {
        if phase == .playing {
            persistSession()
            hintOfferVisible = false
            phase = .paused
        }
    }
    func resume() { guard phase == .paused else { return }; lastTick = Date(); lastProgressAt = Date(); phase = .playing }
    func restart() {
        resetRound(hearts: GameStyle.startingHearts)
    }
    func retryAfterLoss() {
        guard phase == .lost else { return }
        resetRound(hearts: GameStyle.startingHearts)
    }
    private func resetRound(hearts initialHearts: Int) {
        generation += 1; tracker.reset()
        pendingSessionSave?.cancel()
        if !isReplay { store.clearSession(levelID: level.id) }
        removedArrowIDs = []
        remaining = level.arrows; hearts = initialHearts; mistakes = 0; elapsed = 0
        hintsUsed = 0; hintBalance = store.hints; hintOfferVisible = false
        earnedReward = nil
        exiting = []; lossReason = .hearts; lastTick = Date(); lastProgressAt = Date(); phase = .playing
        scene.isPaused = false; scene.configure(level: level); tutorialHint()
    }
    func persistSession() {
        pendingSessionSave?.cancel()
        guard !isReplay, !remaining.isEmpty, phase == .playing || phase == .paused else { return }
        store.saveSession(LevelSessionSnapshot(
            levelID: level.id,
            removedArrowIDs: removedArrowIDs,
            penalizedArrowIDs: tracker.penalized,
            hearts: hearts,
            mistakes: mistakes,
            elapsed: elapsed,
            hintsUsed: hintsUsed
        ))
    }
    private func scheduleSessionPersistence() {
        pendingSessionSave?.cancel()
        guard !isReplay, !remaining.isEmpty else { return }
        let work = DispatchWorkItem { [weak self] in self?.persistSession() }
        pendingSessionSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
    var levelDisplayTitle: String {
        if let eventID, let puzzle = LevelRepository.eventPuzzles(for: eventID).first(where: { $0.id == level.id }) {
            return "November \(puzzle.day)"
        }
        return "Level \(level.id)"
    }
    var formattedTime: String { hasTimeLimit ? format(TimeInterval(ceil(secondsRemaining))) : "∞" }
    private func format(_ seconds: TimeInterval) -> String { String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}
