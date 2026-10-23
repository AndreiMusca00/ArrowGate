import Foundation

#if SWIFT_PACKAGE
import PictarrowContentFixtures
#endif

/// Thread-safe runtime catalog. App builds start empty and activate only a
/// validated downloaded catalog. Swift Package tests keep the checked-in
/// campaign fixtures so puzzle validation remains deterministic and offline.
enum LevelRepository {
    private static let lock = NSRecursiveLock()
    private static let initialCatalog: GameCatalog? = {
        #if SWIFT_PACKAGE
        let bundle = ContentFixtureBundle.bundle
        let decoder = JSONDecoder()
        guard let indexData = bundledData(named: "catalog.json", in: bundle),
              let index = try? decoder.decode(CatalogIndex.self, from: indexData),
              !index.chapterFiles.isEmpty,
              Set(index.chapterFiles).count == index.chapterFiles.count else {
            preconditionFailure("Missing or invalid bundled catalog.json index")
        }

        let chapterCatalogs = index.chapterFiles.compactMap { fileName -> ChapterCatalog? in
            guard let data = bundledData(named: fileName, in: bundle) else { return nil }
            return try? decoder.decode(ChapterCatalog.self, from: data)
        }
        let eventFiles = index.eventFiles ?? []
        let eventCatalogs = eventFiles.compactMap { fileName -> GameEventCatalog? in
            guard let data = bundledData(named: fileName, in: bundle) else { return nil }
            return try? decoder.decode(GameEventCatalog.self, from: data)
        }
        guard chapterCatalogs.count == index.chapterFiles.count,
              eventCatalogs.count == eventFiles.count,
              let catalog = try? assemble(
                version: index.version,
                configuration: index.configuration,
                chapters: chapterCatalogs,
                events: eventCatalogs
              ) else {
            preconditionFailure("Missing or invalid bundled chapter catalog")
        }
        return catalog
        #else
        return nil
        #endif
    }()
    private static var activeCatalog: GameCatalog? = initialCatalog

    private static func bundledData(named fileName: String, in bundle: Bundle) -> Data? {
        let fileURL = URL(fileURLWithPath: fileName)
        let resourceName = fileURL.deletingPathExtension().lastPathComponent
        let resourceExtension = fileURL.pathExtension
        let candidates = [
            bundle.url(forResource: resourceName, withExtension: resourceExtension, subdirectory: "Levels"),
            bundle.url(forResource: resourceName, withExtension: resourceExtension),
            bundle.resourceURL?.appendingPathComponent("Levels").appendingPathComponent(fileName)
        ]
        guard let url = candidates.compactMap({ $0 }).first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else { return nil }
        return try? Data(contentsOf: url)
    }

    static func install(_ catalog: GameCatalog) throws {
        try validate(catalog)
        lock.lock()
        activeCatalog = catalog
        lock.unlock()
    }

    static func restoreBundledCatalog() {
        lock.lock()
        activeCatalog = initialCatalog
        lock.unlock()
    }

    static func assemble(
        version: Int,
        configuration: CatalogConfiguration,
        chapters chapterCatalogs: [ChapterCatalog],
        events eventCatalogs: [GameEventCatalog]
    ) throws -> GameCatalog {
        let catalog = GameCatalog(
            version: version,
            configuration: configuration,
            chapters: chapterCatalogs.map(\.chapter).sorted { $0.id < $1.id },
            levels: chapterCatalogs.flatMap(\.levels).sorted { $0.id < $1.id },
            events: eventCatalogs.map(\.event).sorted { $0.priority < $1.priority },
            eventPuzzles: Dictionary(eventCatalogs.map { ($0.event.id, $0.levels ?? []) }, uniquingKeysWith: { first, _ in first })
        )
        try validate(catalog)
        return catalog
    }

    private static func validate(_ catalog: GameCatalog) throws {
        let eventCatalogsAreValid = catalog.events.allSatisfy { event in
            guard let puzzles = catalog.eventPuzzles[event.id], !puzzles.isEmpty else { return true }
            return puzzles.count == event.progress.goal
                && puzzles.map(\.day) == Array(1...puzzles.count)
                && Set(puzzles.map(\.date)).count == puzzles.count
                && puzzles.allSatisfy {
                    $0.date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
                        && LevelValidator.solution(for: $0.level) != nil
                }
        }
        guard catalog.version > 0,
              catalog.configuration.levelsPerChapter > 0,
              !catalog.chapters.isEmpty,
              catalog.chapters.map(\.id) == Array(1...catalog.chapters.count),
              catalog.levels.map(\.id) == Array(1...catalog.levels.count),
              catalog.levels.allSatisfy({ level in catalog.chapters.contains { $0.id == level.chapterID } }),
              catalog.chapters.allSatisfy({ chapter in
                  chapter.levelCount == catalog.configuration.levelsPerChapter
                      && catalog.levels.filter({ $0.chapterID == chapter.id }).count == chapter.levelCount
                      && chapter.style.hasValidValues
                      && chapter.assembly?.hasValidValues != false
              }),
              Set(catalog.events.map(\.id)).count == catalog.events.count,
              eventCatalogsAreValid,
              Set(catalog.levels.map(\.id) + catalog.eventPuzzles.values.flatMap { $0.map(\.id) }).count
                  == catalog.levels.count + catalog.eventPuzzles.values.reduce(0, { $0 + $1.count }),
              catalog.events.allSatisfy(\.hasValidValues),
              catalog.levels.allSatisfy({ LevelValidator.solution(for: $0) != nil }) else {
            throw RemoteContentError.invalidCatalog
        }
    }

    private static func snapshot() -> GameCatalog? {
        lock.lock()
        defer { lock.unlock() }
        return activeCatalog
    }

    static var isReady: Bool { snapshot() != nil }
    static var version: Int { snapshot()?.version ?? 0 }
    static var levelsPerChapter: Int { snapshot()?.configuration.levelsPerChapter ?? 0 }
    static var chapters: [ChapterDefinition] { snapshot()?.chapters ?? [] }
    static var levels: [LevelDefinition] { snapshot()?.levels ?? [] }
    static var events: [GameEventDefinition] { snapshot()?.events ?? [] }
    static var count: Int { levels.count }
    static func eventPuzzles(for id: String) -> [EventPuzzleDefinition] { snapshot()?.eventPuzzles[id] ?? [] }
    static func event(_ id: String) -> GameEventDefinition? { events.first { $0.id == id } }
    static func level(_ number: Int) -> LevelDefinition {
        precondition(count > 0, "Level catalog is not ready")
        return levels[min(max(number, 1), count) - 1]
    }
    static func chapter(_ id: Int) -> ChapterDefinition {
        precondition(!chapters.isEmpty, "Level catalog is not ready")
        return chapters.first { $0.id == id } ?? chapters[0]
    }
    static func chapter(containing level: Int) -> ChapterDefinition {
        precondition(!chapters.isEmpty, "Level catalog is not ready")
        guard let chapterID = levels.first(where: { $0.id == level })?.chapterID else { return chapters[0] }
        return chapter(chapterID)
    }
    static func levels(in chapter: ChapterDefinition) -> [LevelDefinition] {
        levels.filter { $0.chapterID == chapter.id }
    }
    static func firstLevel(in chapter: ChapterDefinition) -> LevelDefinition? {
        levels(in: chapter).first
    }
}

private extension GameEventDefinition {
    var hasValidValues: Bool {
        id.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil
            && !title.isEmpty && !subtitle.isEmpty
            && priority >= 0
            && progress.goal > 0 && !progress.unitName.isEmpty
            && reward.pieceCount > 0 && !reward.title.isEmpty && !reward.systemSymbol.isEmpty
            && [style.primaryColor, style.secondaryColor, style.backgroundColor].allSatisfy { color in
                color.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil
            }
            && previewDate != nil && startDate != nil
            && previewDate! <= startDate!
            && (endDate == nil || endDate! > startDate!)
            && (schedule.testingStartsAt == nil || (testingStartDate != nil && testingStartDate! >= previewDate!
                && (endDate == nil || testingStartDate! < endDate!)))
    }
}

private extension ChapterAssemblyDefinition {
    var hasValidValues: Bool {
        pieceCount > 0
            && pieceCount == placements.count
            && !assetPrefix.isEmpty
            && aspectRatio > 0
            && placements.allSatisfy {
                (0...1).contains($0.x) && (0...1).contains($0.y) && $0.scale > 0
            }
    }
}

private extension ChapterStyleDefinition {
    var hasValidValues: Bool {
        [primaryColor, secondaryColor, backgroundColor].allSatisfy { color in
            color.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil
        }
            && !decorations.isEmpty
            && galleryCardHeight > 0
            && galleryCornerRadius > 0
            && (0...1).contains(detailBackgroundOpacity)
            && mapCornerRadius > 0
            && (0...1).contains(mapBackgroundOpacity)
            && (0...1).contains(mapBorderOpacity)
    }
}
