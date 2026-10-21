import Foundation
import Combine

/// The small, resumable part of an unfinished campaign attempt. The level
/// definition itself continues to come from the catalog, so catalog data is not
/// duplicated in local storage.
struct LevelSessionSnapshot: Codable, Equatable {
    let version: Int
    let levelID: Int
    let removedArrowIDs: [Int]
    let penalizedArrowIDs: Set<Int>
    let hearts: Int
    let mistakes: Int
    let elapsed: TimeInterval
    let hintsUsed: Int

    init(levelID: Int, removedArrowIDs: [Int], penalizedArrowIDs: Set<Int>,
         hearts: Int, mistakes: Int, elapsed: TimeInterval, hintsUsed: Int) {
        version = 1
        self.levelID = levelID
        self.removedArrowIDs = removedArrowIDs
        self.penalizedArrowIDs = penalizedArrowIDs
        self.hearts = hearts
        self.mistakes = mistakes
        self.elapsed = elapsed
        self.hintsUsed = hintsUsed
    }

    func isValid(for level: LevelDefinition) -> Bool {
        let arrowIDs = Set(level.arrows.map(\.id))
        let removed = Set(removedArrowIDs)
        return version == 1
            && levelID == level.id
            && removed.count == removedArrowIDs.count
            && removed.isSubset(of: arrowIDs)
            && removed.count < arrowIDs.count
            && penalizedArrowIDs.isSubset(of: arrowIDs)
            && (1...3).contains(hearts)
            && mistakes >= 0
            && elapsed.isFinite && elapsed >= 0
            && hintsUsed >= 0
    }
}

final class ProgressStore: ObservableObject {
    private static let activeSessionDefaultsKey = "activeLevelSession"
    private let defaults: UserDefaults
    private let database: LocalDatabase?
    @Published var storageError: String?
    @Published private(set) var savedLevels: [SavedLevel] = []
    @Published private(set) var savedChapters: [SavedChapter] = []
    @Published private(set) var unlocked: Int
    @Published private(set) var completedLevels: Set<Int> = []
    @Published private(set) var hints = 0
    @Published private(set) var activeSession: LevelSessionSnapshot? = nil
    @Published private(set) var eventProgress: [String: Int] = [:]
    @Published private(set) var completedEventLevels: [String: Set<Int>] = [:]
    @Published private(set) var eventTrophies: [String: Set<String>] = [:]
    @Published var sound: Bool { didSet { defaults.set(sound, forKey: "soundEnabled") } }
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "hapticsEnabled") } }

    init(defaults: UserDefaults = .standard, database: LocalDatabase? = nil) {
        self.defaults = defaults; self.database = database
        defaults.register(defaults: ["unlockedLevel": 1, "hintCount": 3,
                                     "soundEnabled": true, "hapticsEnabled": true])
        defaults.removeObject(forKey: "reserveLifeCount")
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
                completedLevels = Set(1..<unlocked)
                if try database.metadata("campaignCompleted") == "1" { completedLevels.insert(LevelRepository.count) }
                activeSession = try database.activeSession()
                for event in LevelRepository.events {
                    let progressKey = Self.progressKey(for: event)
                    eventProgress[progressKey] = min(event.progress.goal, try database.eventProgress(progressKey))
                    eventTrophies[event.id] = try database.eventTrophies(event.id)
                    completedEventLevels[event.id] = try database.completedEventLevels(event.id)
                }
            } catch { storageError = error.localizedDescription }
        } else {
            hints = max(0, defaults.integer(forKey: "hintCount"))
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
            if let data = defaults.data(forKey: Self.activeSessionDefaultsKey) {
                activeSession = try? JSONDecoder().decode(LevelSessionSnapshot.self, from: data)
            }
            for event in LevelRepository.events {
                if let data = defaults.data(forKey: "eventCompleted.\(event.id)") {
                    completedEventLevels[event.id] = try? JSONDecoder().decode(Set<Int>.self, from: data)
                }
                let progressKey = Self.progressKey(for: event)
                eventProgress[progressKey] = min(event.progress.goal, max(0, defaults.integer(forKey: "eventProgress.\(progressKey)")))
                if let data = defaults.data(forKey: "eventTrophies.\(event.id)"),
                   let trophies = try? JSONDecoder().decode(Set<String>.self, from: data) {
                    eventTrophies[event.id] = trophies
                }
            }
        }
    }

    func progress(for event: GameEventDefinition, at date: Date = Date()) -> Int {
        min(event.progress.goal, max(0, eventProgress[Self.progressKey(for: event, at: date)] ?? 0))
    }

    func isEventLevelUnlocked(_ eventID: String, levelID: Int) -> Bool {
        let puzzles = LevelRepository.eventPuzzles(for: eventID)
        guard let index = puzzles.firstIndex(where: { $0.id == levelID }) else { return false }
        let completed = completedEventLevels[eventID, default: []]
        return completed.contains(levelID) || puzzles.prefix(index).allSatisfy { completed.contains($0.id) }
    }

    @discardableResult
    func completeEventLevel(_ eventID: String, levelID: Int, on date: Date = Date()) -> Bool {
        guard let event = LevelRepository.event(eventID), event.kind == .limitedCollection,
              event.lifecycle(at: date) == .active,
              isEventLevelUnlocked(eventID, levelID: levelID),
              LevelRepository.eventPuzzles(for: eventID).contains(where: { $0.id == levelID }) else { return false }
        var completed = completedEventLevels[eventID, default: []]
        guard completed.insert(levelID).inserted else { return false }
        if let database {
            do { try database.saveCompletedEventLevels(completed, eventID: eventID) }
            catch { storageError = error.localizedDescription; return false }
        }
        completedEventLevels[eventID] = completed
        eventProgress[eventID] = completed.count
        defaults.set(completed.count, forKey: "eventProgress.\(eventID)")
        defaults.set(try? JSONEncoder().encode(completed), forKey: "eventCompleted.\(eventID)")
        clearSession(levelID: levelID)
        return true
    }

    func hasTrophy(for event: GameEventDefinition, monthKey: String) -> Bool {
        eventTrophies[event.id, default: []].contains(monthKey)
    }

    /// Entry point for the future daily/limited-event game flow. Catalog data
    /// defines the goal while the player's count and trophies remain local.
    func recordEventCompletion(_ event: GameEventDefinition, on date: Date = Date()) {
        guard event.lifecycle(at: date) == .active else { return }
        let progressKey = Self.progressKey(for: event, at: date)
        let next = min(event.progress.goal, progress(for: event, at: date) + 1)
        var trophies = eventTrophies[event.id, default: []]
        if event.reward.kind == .monthlyTrophy, next == event.progress.goal {
            trophies.insert(Self.monthKey(for: date))
        }
        if let database {
            do {
                try database.setEventProgress(next, eventID: progressKey)
                try database.setEventTrophies(trophies, eventID: event.id)
            } catch { storageError = error.localizedDescription; return }
        }
        eventProgress[progressKey] = next
        eventTrophies[event.id] = trophies
        defaults.set(next, forKey: "eventProgress.\(progressKey)")
        if let data = try? JSONEncoder().encode(trophies) {
            defaults.set(data, forKey: "eventTrophies.\(event.id)")
        }
    }

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let values = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", values.year ?? 0, values.month ?? 0)
    }

    private static func progressKey(for event: GameEventDefinition, at date: Date = Date()) -> String {
        event.kind == .dailyChallenge ? "\(event.id).\(monthKey(for: date))" : event.id
    }

    func session(for level: LevelDefinition) -> LevelSessionSnapshot? {
        guard let activeSession else { return nil }
        guard activeSession.isValid(for: level) else {
            clearSession()
            return nil
        }
        return activeSession
    }

    func saveSession(_ snapshot: LevelSessionSnapshot) {
        guard snapshot.elapsed.isFinite, snapshot.elapsed >= 0 else { return }
        if let database {
            do { try database.saveActiveSession(snapshot) }
            catch { storageError = error.localizedDescription; return }
        } else {
            do { defaults.set(try JSONEncoder().encode(snapshot), forKey: Self.activeSessionDefaultsKey) }
            catch { storageError = error.localizedDescription; return }
        }
        activeSession = snapshot
    }

    func clearSession(levelID: Int? = nil) {
        if let levelID, let activeSession, activeSession.levelID != levelID { return }
        if let database {
            do { try database.clearActiveSession() }
            catch { storageError = error.localizedDescription; return }
        }
        defaults.removeObject(forKey: Self.activeSessionDefaultsKey)
        activeSession = nil
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
            } catch { storageError = error.localizedDescription; completionSucceeded = false }
        } else {
            unlocked = max(unlocked, min(level + 1, LevelRepository.count))
            let key = "bestTime.\(level)"
            if defaults.object(forKey: key) == nil || time < defaults.double(forKey: key) { defaults.set(time, forKey: key) }
            let countKey = "completionCount.\(level)"
            let totalKey = "totalCompletionTime.\(level)"
            defaults.set(time, forKey: "lastCompletionTime.\(level)")
            defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
            defaults.set(defaults.double(forKey: totalKey) + time, forKey: totalKey)
            if firstCompletion { defaults.set(time, forKey: "firstCompletionTime.\(level)") }
            if level == LevelRepository.count { defaults.set(true, forKey: "campaignCompleted") }
            if firstCompletion, let reward { grantHint(reward.amount) }
            defaults.set(true, forKey: "completed.\(level)")
        }
        guard completionSucceeded else { return nil }
        clearSession(levelID: level)
        completedLevels.formUnion(1...level)
        defaults.set(unlocked, forKey: "unlockedLevel")
        defaults.set(hints, forKey: "hintCount")
        return firstCompletion ? reward : nil
    }
    func reset() {
        if let database {
            do { try database.resetProgress() }
            catch { storageError = error.localizedDescription; return }
        }
        unlocked = 1; completedLevels = []; hints = 3
        activeSession = nil
        eventProgress = [:]; eventTrophies = [:]; completedEventLevels = [:]
        defaults.set(1, forKey: "unlockedLevel"); defaults.set(3, forKey: "hintCount")
        defaults.removeObject(forKey: "reserveLifeCount")
        for id in 1...LevelRepository.count {
            defaults.removeObject(forKey: "bestTime.\(id)")
            defaults.removeObject(forKey: "firstCompletionTime.\(id)")
            defaults.removeObject(forKey: "lastCompletionTime.\(id)")
            defaults.removeObject(forKey: "totalCompletionTime.\(id)")
            defaults.removeObject(forKey: "completionCount.\(id)")
            defaults.removeObject(forKey: "completed.\(id)")
        }
        defaults.removeObject(forKey: "campaignCompleted")
        defaults.removeObject(forKey: Self.activeSessionDefaultsKey)
        for event in LevelRepository.events {
            defaults.removeObject(forKey: "eventTrophies.\(event.id)")
            defaults.removeObject(forKey: "eventCompleted.\(event.id)")
        }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("eventProgress.") {
            defaults.removeObject(forKey: key)
        }
    }
}
