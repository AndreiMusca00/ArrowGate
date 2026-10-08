import Foundation
import Combine

enum HomeScreen { case menu, journey, gallery }

@MainActor
final class AppState: ObservableObject {
    @Published var game: GameViewModel?
    @Published private(set) var homeScreen: HomeScreen = .menu
    let progress: ProgressStore
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
        var limit: TimeInterval? = nil
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-test-time-limit"),
           ProcessInfo.processInfo.arguments.count > index + 1 {
            limit = Double(ProcessInfo.processInfo.arguments[index + 1])
        }
        #endif
        let id = number ?? progress.unlocked
        let level = progress.savedLevels.first { $0.id == id }?.definition ?? LevelRepository.level(id)
        game = GameViewModel(level: level, store: progress, timeLimit: limit)
    }
    func menu() { game = nil; homeScreen = .menu }
    func showJourney() { game = nil; homeScreen = .journey }
    func showGallery() { game = nil; homeScreen = .gallery }
    func show(_ screen: HomeScreen) { game = nil; homeScreen = screen }
}
