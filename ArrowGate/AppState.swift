import Foundation
import Combine

enum HomeScreen { case collection, menu, settings }
enum ContentAvailability: Equatable { case loading, ready, needsConnection }

@MainActor
final class AppState: ObservableObject {
    @Published var game: GameViewModel?
    @Published private(set) var selectedEventID: String?
    @Published private(set) var homeScreen: HomeScreen = .menu
    @Published private(set) var selectedReplayLevel: Int?
    @Published private(set) var contentRevision = 0
    @Published private(set) var contentAvailability: ContentAvailability = .loading
    let progress: ProgressStore
    let isContentPreview: Bool
    private(set) var remoteContent: RemoteContentService?
    private var contentCancellables: Set<AnyCancellable> = []
    private var requestedStartupLevel: Int?

    var homeLevelNumber: Int { selectedReplayLevel ?? progress.unlocked }

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("-ui-testing")
        let previewing = ProcessInfo.processInfo.environment["PICTARROW_CONTENT_PREVIEW"] == "1"
        isContentPreview = previewing
        let defaults = testing
            ? UserDefaults(suiteName: "ArrowGateUIVerification")!
            : previewing ? UserDefaults(suiteName: "PictarrowLocalPreview")! : .standard
        let url = testing ? LocalDatabase.defaultURL(testing: true)
            : previewing ? LocalDatabase.previewURL : LocalDatabase.defaultURL()
        if testing && arguments.contains("-reset-test-progress") {
            defaults.removePersistentDomain(forName: "ArrowGateUIVerification")
            for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
        }
        #else
        isContentPreview = false
        let defaults = UserDefaults.standard
        let url = LocalDatabase.defaultURL()
        #endif
        do {
            let database = try LocalDatabase(url: url)
            #if DEBUG
            let legacyProgressURL = testing || previewing ? nil : LocalDatabase.previousURL
            #else
            let legacyProgressURL = LocalDatabase.previousURL
            #endif
            progress = ProgressStore(
                defaults: defaults,
                database: database,
                legacyProgressURL: legacyProgressURL
            )
        }
        catch { progress = ProgressStore(defaults: defaults); progress.storageError = error.localizedDescription }
        #if DEBUG
        if testing && arguments.contains("-reset-test-progress") { progress.sound = false; progress.haptics = false }
        if let index = arguments.firstIndex(of: "-level"), arguments.count > index + 1,
           let number = Int(arguments[index + 1]) { requestedStartupLevel = number }
        #endif

        configureRemoteContent()
    }

    private func configureRemoteContent() {
        #if DEBUG
        let previewing = ProcessInfo.processInfo.environment["PICTARROW_CONTENT_PREVIEW"] == "1"
        let selectedService = previewing
            ? RemoteContentService.localPreviewService()
            : RemoteContentService.firebaseService()
        #else
        let selectedService = RemoteContentService.firebaseService()
        #endif
        guard let service = selectedService else {
            contentAvailability = .needsConnection
            return
        }
        remoteContent = service
        service.$state
            .sink { [weak self] remoteState in
                guard let self else { return }
                switch remoteState {
                case .idle, .syncing:
                    if !LevelRepository.isReady { contentAvailability = .loading }
                case .ready:
                    if LevelRepository.isReady { contentAvailability = .ready }
                case .offlineUsingLocalContent:
                    contentAvailability = LevelRepository.isReady ? .ready : .needsConnection
                }
            }
            .store(in: &contentCancellables)
        service.$installedContent
            .compactMap { $0 }
            .sink { [weak self] content in
                guard let self else { return }
                do {
                    try LevelRepository.install(content.catalog)
                    ContentAssetRegistry.install(content.assetURLs)
                    progress.reloadCatalog()
                    contentRevision &+= 1
                    contentAvailability = .ready
                    if let requestedLevel = requestedStartupLevel {
                        requestedStartupLevel = nil
                        play(requestedLevel)
                    }
                } catch {
                    progress.storageError = error.localizedDescription
                    contentAvailability = .needsConnection
                }
            }
            .store(in: &contentCancellables)
        progress.$unlocked
            .combineLatest(progress.$completedLevels, progress.$completedEventLevels)
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] unlocked, completedLevels, completedEventLevels in
                self?.synchronizeRemoteContent(
                    unlocked: unlocked,
                    completedLevels: completedLevels,
                    completedEventLevels: completedEventLevels
                )
            }
            .store(in: &contentCancellables)
    }

    private func synchronizeRemoteContent(
        unlocked: Int,
        completedLevels: Set<Int>,
        completedEventLevels: [String: Set<Int>],
        forceRefresh: Bool = false
    ) {
        guard let remoteContent else { return }
        let completedChapters = Set(LevelRepository.chapters.compactMap { chapter -> Int? in
            let identifiers = Set(LevelRepository.levels(in: chapter).map(\.id))
            return !identifiers.isEmpty && identifiers.isSubset(of: completedLevels) ? chapter.id : nil
        })
        let completedEvents = Set(LevelRepository.events.compactMap { event -> String? in
            let required = Set(LevelRepository.eventPuzzles(for: event.id).map(\.id))
            return !required.isEmpty && required.isSubset(of: completedEventLevels[event.id, default: []])
                ? event.id : nil
        })
        remoteContent.synchronize(
            unlockedLevel: unlocked,
            completedChapterIDs: completedChapters,
            completedEventIDs: completedEvents,
            forceCatalogRefresh: forceRefresh
        )
    }

    func retryContentLoading() {
        guard remoteContent != nil else {
            contentAvailability = .needsConnection
            return
        }
        contentAvailability = .loading
        synchronizeRemoteContent(
            unlocked: progress.unlocked,
            completedLevels: progress.completedLevels,
            completedEventLevels: progress.completedEventLevels,
            forceRefresh: true
        )
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
