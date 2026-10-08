import Foundation
import Combine

final class ProgressStore: ObservableObject {
    private let defaults: UserDefaults
    private let database: LocalDatabase?
    @Published var storageError: String?
    @Published private(set) var savedLevels: [SavedLevel] = []
    @Published private(set) var unlocked: Int
    @Published private(set) var completedLevels: Set<Int> = []
    @Published var sound: Bool { didSet { defaults.set(sound, forKey: "soundEnabled") } }
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "hapticsEnabled") } }

    init(defaults: UserDefaults = .standard, database: LocalDatabase? = nil) {
        self.defaults = defaults; self.database = database
        defaults.register(defaults: ["unlockedLevel": 1, "soundEnabled": true, "hapticsEnabled": true])
        unlocked = min(max(defaults.integer(forKey: "unlockedLevel"), 1), LevelRepository.count)
        sound = defaults.bool(forKey: "soundEnabled"); haptics = defaults.bool(forKey: "hapticsEnabled")
        if let database {
            do {
                try database.initializeProgress(defaults: defaults)
                try database.saveLevels(LevelRepository.levels)
                savedLevels = try database.levels()
                unlocked = min(max(Int(try database.metadata("unlocked") ?? "1") ?? 1, 1), LevelRepository.count)
                completedLevels = Set(1..<unlocked)
                if try database.metadata("campaignCompleted") == "1" { completedLevels.insert(LevelRepository.count) }
            } catch { storageError = error.localizedDescription }
        } else {
            completedLevels = Set(1..<unlocked)
            if defaults.bool(forKey: "campaignCompleted") { completedLevels.insert(LevelRepository.count) }
        }
    }
    func complete(_ level: Int, time: TimeInterval) {
        guard (1...LevelRepository.count).contains(level) else { return }
        if let database {
            do {
                try database.complete(level, time: time)
                unlocked = Int(try database.metadata("unlocked") ?? "1") ?? 1
            } catch { storageError = error.localizedDescription }
        } else {
            unlocked = max(unlocked, min(level + 1, LevelRepository.count))
            let key = "bestTime.\(level)"
            if defaults.object(forKey: key) == nil || time < defaults.double(forKey: key) { defaults.set(time, forKey: key) }
            if level == LevelRepository.count { defaults.set(true, forKey: "campaignCompleted") }
        }
        completedLevels.formUnion(1...level)
        defaults.set(unlocked, forKey: "unlockedLevel")
    }
    func reset() {
        if let database {
            do { try database.resetProgress() }
            catch { storageError = error.localizedDescription; return }
        }
        unlocked = 1; completedLevels = []; defaults.set(1, forKey: "unlockedLevel")
        for id in 1...LevelRepository.count { defaults.removeObject(forKey: "bestTime.\(id)") }
        defaults.removeObject(forKey: "campaignCompleted")
    }
}
