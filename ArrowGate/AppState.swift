import Foundation
import Combine

enum HomeScreen { case collection, menu, settings }

@MainActor
final class AppState: ObservableObject {
    @Published var game: GameViewModel?
    @Published private(set) var selectedEventID: String?
    @Published private(set) var homeScreen: HomeScreen = .menu
    @Published private(set) var selectedReplayLevel: Int?
    let progress: ProgressStore

    var homeLevelNumber: Int { selectedReplayLevel ?? progress.unlocked }

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("-ui-testing")
        let defaults = testing ? UserDefaults(suiteName: "ArrowGateUIVerification")! : .standard
        let url = LocalDatabase.defaultURL(testing: testing)
        if testing && arguments.contains("-reset-test-progress") {
            defaults.removePersistentDomain(forName: "ArrowGateUIVerification")
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        #else
        let defaults = UserDefaults.standard
        let url = LocalDatabase.defaultURL()
        #endif
        do {
            let database = try LocalDatabase(url: url)
            #if DEBUG
            if !testing { try database.importProgress(from: LocalDatabase.previousURL) }
            #else
            try database.importProgress(from: LocalDatabase.previousURL)
            #endif
            progress = ProgressStore(defaults: defaults, database: database)
        }
        catch { progress = ProgressStore(defaults: defaults); progress.storageError = error.localizedDescription }
        #if DEBUG
        if testing && arguments.contains("-reset-test-progress") { progress.sound = false; progress.haptics = false }
        if let index = arguments.firstIndex(of: "-level"), arguments.count > index + 1,
           let number = Int(arguments[index + 1]) { play(number) }
        #endif
    }

    func play(_ number: Int? = nil) {
        selectedEventID = nil
        var limit: TimeInterval? = nil
        var hintDelay: TimeInterval = 10
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-test-time-limit"),
           ProcessInfo.processInfo.arguments.count > index + 1 {
            limit = Double(ProcessInfo.processInfo.arguments[index + 1])
        }
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-test-hint-delay"),
           ProcessInfo.processInfo.arguments.count > index + 1 {
            hintDelay = Double(ProcessInfo.processInfo.arguments[index + 1]) ?? 10
        }
        #endif
        let id = number ?? homeLevelNumber
        let level = progress.savedLevels.first { $0.id == id }?.definition ?? LevelRepository.level(id)
        let replay = progress.completedLevels.contains(id)
        let session = replay ? nil : progress.session(for: level)
        game = GameViewModel(
            level: level,
            store: progress,
            isReplay: replay,
            timeLimit: limit,
            idleHintDelay: hintDelay,
            session: session
        )
    }

    func openEvent(_ event: GameEventDefinition) {
        guard event.lifecycle() == .active, !LevelRepository.eventPuzzles(for: event.id).isEmpty else { return }
        game?.persistSession()
        game = nil
        selectedEventID = event.id
    }
    func closeEvent() { selectedEventID = nil }
    func playEvent(_ eventID: String, day: Int) {
        guard let event = LevelRepository.event(eventID), event.lifecycle() == .active,
              let puzzle = LevelRepository.eventPuzzles(for: eventID).first(where: { $0.day == day }),
              progress.isEventLevelUnlocked(eventID, levelID: puzzle.id) else { return }
        selectedEventID = eventID
        let replay = progress.completedEventLevels[eventID, default: []].contains(puzzle.id)
        game = GameViewModel(level: puzzle.level, store: progress, isReplay: replay,
                             session: replay ? nil : progress.session(for: puzzle.level), eventID: eventID)
    }

    func selectCompletedLevel(_ number: Int) {
        guard progress.completedLevels.contains(number) else { return }
        selectedReplayLevel = number
        game = nil
        homeScreen = .menu
    }

    func attemptEnded(_ model: GameViewModel) {
        guard game === model, model.isReplay else { return }
        selectedReplayLevel = nil
    }

    func menu() {
        game?.persistSession()
        if game?.isReplay == true { selectedReplayLevel = nil }
        game = nil
        if selectedEventID == nil { homeScreen = .menu }
    }
    func showCollection() { selectedEventID = nil; game?.persistSession(); game = nil; homeScreen = .collection }
    func show(_ screen: HomeScreen) { selectedEventID = nil; game?.persistSession(); game = nil; homeScreen = screen }
}
