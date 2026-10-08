import Foundation
import Combine

final class ProgressStore: ObservableObject {
    private let defaults: UserDefaults
    private let database: LocalDatabase?
    @Published var storageError: String?
    @Published private(set) var savedLevels: [SavedLevel] = []
    @Published private(set) var savedChapters: [SavedChapter] = []
    @Published private(set) var unlocked: Int
    @Published private(set) var completedLevels: Set<Int> = []
    @Published private(set) var hints = 0
    @Published private(set) var reserveLives = 0
    @Published var sound: Bool { didSet { defaults.set(sound, forKey: "soundEnabled") } }
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "hapticsEnabled") } }

    init(defaults: UserDefaults = .standard, database: LocalDatabase? = nil) {
        self.defaults = defaults; self.database = database
        defaults.register(defaults: ["unlockedLevel": 1, "hintCount": 3, "reserveLifeCount": 1,
                                     "soundEnabled": true, "hapticsEnabled": true])
        unlocked = min(max(defaults.integer(forKey: "unlockedLevel"), 1), LevelRepository.count)
        sound = defaults.bool(forKey: "soundEnabled"); haptics = defaults.bool(forKey: "hapticsEnabled")
        if let database {
            do {
                try database.initializeProgress(defaults: defaults)
                try database.saveChapters(LevelRepository.chapters)
                try database.saveLevels(LevelRepository.levels)
                savedChapters = try database.chapters()
                savedLevels = try database.levels()
                unlocked = min(max(Int(try database.metadata("unlocked") ?? "1") ?? 1, 1), LevelRepository.count)
                hints = max(0, Int(try database.metadata("hints") ?? "3") ?? 3)
                reserveLives = max(0, Int(try database.metadata("reserveLives") ?? "1") ?? 1)
                completedLevels = Set(1..<unlocked)
                if try database.metadata("campaignCompleted") == "1" { completedLevels.insert(LevelRepository.count) }
            } catch { storageError = error.localizedDescription }
        } else {
            hints = max(0, defaults.integer(forKey: "hintCount"))
            reserveLives = max(0, defaults.integer(forKey: "reserveLifeCount"))
            completedLevels = Set(1..<unlocked)
            if defaults.bool(forKey: "campaignCompleted") {
                if unlocked < LevelRepository.count {
                    completedLevels.insert(unlocked)
                    unlocked += 1
                    defaults.set(unlocked, forKey: "unlockedLevel")
                    defaults.set(false, forKey: "campaignCompleted")
                } else {
                    completedLevels.insert(LevelRepository.count)
                }
            }
        }
    }
    @discardableResult func consumeHint() -> Bool {
        guard hints > 0 else { return false }
        let next = hints - 1
        if let database {
            do { try database.setHintCount(next) }
            catch { storageError = error.localizedDescription; return false }
        }
        hints = next
        defaults.set(next, forKey: "hintCount")
        return true
    }
    func grantHint(_ amount: Int = 1) {
        guard amount > 0 else { return }
        let next = hints + amount
        if let database {
            do { try database.setHintCount(next) }
            catch { storageError = error.localizedDescription; return }
        }
        hints = next
        defaults.set(next, forKey: "hintCount")
    }
    @discardableResult func consumeReserveLife() -> Bool {
        guard reserveLives > 0 else { return false }
        let next = reserveLives - 1
        if let database {
            do { try database.setReserveLifeCount(next) }
            catch { storageError = error.localizedDescription; return false }
        }
        reserveLives = next
        defaults.set(next, forKey: "reserveLifeCount")
        return true
    }
    func grantReserveLife(_ amount: Int = 1) {
        guard amount > 0 else { return }
        let next = reserveLives + amount
        if let database {
            do { try database.setReserveLifeCount(next) }
            catch { storageError = error.localizedDescription; return }
        }
        reserveLives = next
        defaults.set(next, forKey: "reserveLifeCount")
    }
    @discardableResult func complete(_ level: Int, time: TimeInterval) -> LevelCompletionReward? {
        guard (1...LevelRepository.count).contains(level) else { return nil }
        let reward = LevelRepository.level(level).completionReward
        var firstCompletion = !completedLevels.contains(level)
        var completionSucceeded = true
        if let database {
            do {
                firstCompletion = try database.complete(level, time: time, reward: reward)
                unlocked = Int(try database.metadata("unlocked") ?? "1") ?? 1
                hints = max(0, Int(try database.metadata("hints") ?? "3") ?? 3)
                reserveLives = max(0, Int(try database.metadata("reserveLives") ?? "1") ?? 1)
            } catch { storageError = error.localizedDescription; completionSucceeded = false }
        } else {
            unlocked = max(unlocked, min(level + 1, LevelRepository.count))
            let key = "bestTime.\(level)"
            if defaults.object(forKey: key) == nil || time < defaults.double(forKey: key) { defaults.set(time, forKey: key) }
            if level == LevelRepository.count { defaults.set(true, forKey: "campaignCompleted") }
            if firstCompletion, let reward {
                switch reward.kind {
                case .hint: grantHint(reward.amount)
                case .life: grantReserveLife(reward.amount)
                }
            }
            defaults.set(true, forKey: "completed.\(level)")
        }
        guard completionSucceeded else { return nil }
        completedLevels.formUnion(1...level)
        defaults.set(unlocked, forKey: "unlockedLevel")
        defaults.set(hints, forKey: "hintCount")
        defaults.set(reserveLives, forKey: "reserveLifeCount")
        return firstCompletion ? reward : nil
    }
    func reset() {
        if let database {
            do { try database.resetProgress() }
            catch { storageError = error.localizedDescription; return }
        }
        unlocked = 1; completedLevels = []; hints = 3; reserveLives = 1
        defaults.set(1, forKey: "unlockedLevel"); defaults.set(3, forKey: "hintCount")
        defaults.set(1, forKey: "reserveLifeCount")
        for id in 1...LevelRepository.count {
            defaults.removeObject(forKey: "bestTime.\(id)")
            defaults.removeObject(forKey: "completed.\(id)")
        }
        defaults.removeObject(forKey: "campaignCompleted")
    }
}
